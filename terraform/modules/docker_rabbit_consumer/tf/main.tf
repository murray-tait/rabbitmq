
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

module "ecs_task_execution_role" {
  role_name_prefix = "${var.name_base}-ecs-task-execution-role"
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "5.52.2"
  trusted_role_services = ["ecs-tasks.amazonaws.com"]
  create_role = true
  custom_role_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
}

module "ecs_task_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  trusted_role_services = ["ecs-tasks.amazonaws.com"]
  version = "5.52.2"
  role_name_prefix = "${var.name_base}-ecs-task-role"
  create_role = true
  inline_policy_statements = [
    {
      sid = "SecretsManagerAccess",
      effect = "Allow",
      actions = ["secretsmanager:Describe*", "secretsmanager:List*", "secretsmanager:Get*"]
      resources = ["${var.rabbit_secret_arn}"]
    },
    {
      sid = "SqsAccess",
      effect = "Allow",
      actions = ["sqs:SendMessage","sqs:Get*", "sqs:List*"]
      resources = ["${module.sqs.queue_arn}"]
    }
  ]
}

resource "aws_ecs_task_definition" "this" {
  family = var.name_base
  cpu = 256
  memory = 512
  requires_compatibilities = ["FARGATE"]
  network_mode = "awsvpc"
  execution_role_arn = module.ecs_task_execution_role.iam_role_arn
  task_role_arn = module.ecs_task_role.iam_role_arn
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





