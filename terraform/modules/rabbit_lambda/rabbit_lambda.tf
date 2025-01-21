variable "name_base" {
  type = string
  description = "Name that resource names will be based on"
}

variable "rabbit_mq_broker_arn" {
  type = string
  description = "ARN of the RabbitMQ broker"
}

variable "rabbit_mq_queue_name" {
  type = string
  description = "Name of the RabbitMQ broker"
}

variable "rabbit_mq_secret_arn" {
  type = string
  description = "ARN of the RabbitMQ secret"
}

module "lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "7.20.0"
  architectures = ["x86_64"]
  logging_log_group = "${terraform.workspace}"
  event_source_mapping = {
    mq = {
      batch_size       = 1
      event_source_arn = var.rabbit_mq_broker_arn
      enabled          = true
      queues           = ["ExampleQueue"]
      source_access_configuration = [
        {
        type = "VIRTUAL_HOST"
        uri  = "MyVirtualHost"
        },
        {
        type = "BASIC_AUTH"
        uri  = var.rabbit_mq_secret_arn
        }
      ]
    }
  }
  environment_variables = {
    "RABBITMQ_ARN" = var.rabbit_mq_broker_arn
    "RABBITMQ_QUEUE_NAME" = var.rabbit_mq_queue_name
    "RABBITMQ_SECRET_ARN" = var.rabbit_mq_secret_arn
  }
  function_name = "${var.name_base}-lambda"
  timeout = 30
  allowed_triggers = {
    mq = {
      action = "lambda:InvokeFunction"
      principal = "mq.amazonaws.com"
    }
  }
  handler = "pika_client.lambda_handler"
  source_path = "${path.module}/function"
  runtime = "python3.13"
  publish = true
  attach_policy_statements = true
  policy_statements = {
    mq = {
      effect    = "Allow",
      actions   = ["mq:DescribeBroker"],
      resources = [var.rabbit_mq_broker_arn]
    },
    secretsmanager = {
      effect    = "Allow",
      actions   = ["secretsmanager:GetSecretValue"],
      resources = [var.rabbit_mq_secret_arn]
    }
  }
}