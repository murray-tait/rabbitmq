
variable "name_base" {
  type = string
  description = "Name the resources in this module should be based on."
}

variable "vpc_id" {
  type = string
  description = "ID of the VPC to deploy the ECS Task in."
}

variable "subnet_ids" {
  type = list(string)
  description = "List of subnets to deploy the ECS Task in."
}

variable "rabbit_secret_arn" {
  type = string
  description = "ARN of the secret containing RabbitMQ connection details."
}

data "aws_secretsmanager_secret_version" "rabbit_connection" {
  secret_id = var.rabbit_secret_arn
}

module "sqs" {
  source  = "terraform-aws-modules/sqs/aws"
  version = "4.2.1"
  name = var.name_base
  create_dlq = true
  redrive_policy = {
    maxReceiveCount = 10
  }
  tags = {
    Environment = "dev"
  }
}

module "ecr" {
  source = "terraform-aws-modules/ecr/aws"
  version = "2.3.1"
  repository_name = lower(var.name_base)
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 30 images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["v"],
          countType     = "imageCountMoreThan",
          countNumber   = 30
        },
        action = {
          type = "expire"
        }
      }
    ]
  })

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_ecs_cluster" "this" {
  name = var.name_base
}

resource "aws_security_group" "this" {
  name        = var.name_base
  description = "ECS security group"
  vpc_id      = var.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_iam_policy_document" "ecs_task_execution_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_tasks_execution_role" {
  name_prefix = "${var.name_base}-ecs-task-execution-role"
  assume_role_policy = "${data.aws_iam_policy_document.ecs_task_execution_assume_role.json}"
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
}

resource "aws_ecs_task_definition" "this" {
  family = var.name_base
  cpu = 256
  memory = 512
  requires_compatibilities = ["FARGATE"]
  network_mode = "awsvpc"
  execution_role_arn = aws_iam_role.ecs_tasks_execution_role.arn
  container_definitions = jsonencode([
    {
      name = var.name_base
      image = "${module.ecr.repository_url}:latest"
      essential = true
    }
  ])
}

resource "aws_ecs_service" "this" {
  name            = var.name_base
  cluster         = aws_ecs_cluster.this.arn
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {

    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.this.id]
    assign_public_ip = false
  }
  depends_on = [aws_ecs_task_definition.this]
}



# module "ecs" {
#   source = "terraform-aws-modules/ecs/aws"
#   version = "5.12.0"
#   cluster_name = var.name_base
#   cluster_configuration = {
#     execute_command_configuration = {
#       logging = "OVERRIDE"
#       log_configuration = {
#         cloud_watch_log_group_name = "/aws/ecs/${var.name_base}"
#       }
#     }
#   }
#   fargate_capacity_providers = {
#     FARGATE = {
#       default_capacity_provider_strategy = {
#         weight = 100
#       }
#     }
#   }
#   services = {
#     rabbit_consumer = {
#       cpu    = 256
#       memory = 1024
#       log_configuration = {
#         cloud_watch_log_group_name = "/aws/ecs/${var.name_base}"
#       }
#       container_definitions = {
#         rabbit_consumer = {

#           cpu       = 512
#           memory    = 1024
#           essential = true
#           image     = "${module.ecr.repository_url}:latest"
#           readonly_root_filesystem = true
#           enable_cloudwatch_logging = true
#           memory_reservation = 100
#           environment = {
#             RABBIT_SECRET_ARN = var.rabbit_secret_arn
#             SQS_QUEUE_URL = module.sqs.queue_url
#           }
#         }
#       }
#       subnet_ids = var.subnet_ids
#       security_group_rules = {
#         egress_all = {
#           type        = "egress"
#           from_port   = 0
#           to_port     = 0
#           protocol    = "-1"
#           cidr_blocks = ["0.0.0.0/0"]
#         }
#       }
#     }
#   }
#   tags = {
#     Environment = "Development"
#     Project     = "Example"
#   }
# }


