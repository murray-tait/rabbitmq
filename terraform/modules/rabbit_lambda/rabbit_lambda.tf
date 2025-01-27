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
}

variable "rabbit_mq_virtual_host" {
  type = string
  description = "Name of the RabbitMQ virtual host"
}

module "lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "7.20.0"
  architectures = ["x86_64"]
  logging_log_group = "/aws/lambda/${var.name_base}"
  event_source_mapping = {
    mq = {
      batch_size       = 1
      event_source_arn = var.rabbit_mq_broker_arn
      bisect_batch_on_function_error = false
      enabled          = true
      queues           = ["MyQueue"]
      source_access_configuration = [
        {
          type = "VIRTUAL_HOST"
          uri  = "MyVhost"
        },
        {
          type = "BASIC_AUTH"
          uri  = var.rabbit_mq_secret_arn
        }
      ]
    }
  }
  environment_variables = {
    "RABBITMQ_QUEUE_NAME" = var.rabbit_mq_queue_name
    "RABBITMQ_VIRTUAL_HOST" = var.rabbit_mq_virtual_host
  }
  function_name = "${var.name_base}"
  timeout = 3
  allowed_triggers = {
    mq = {
      action = "lambda:InvokeFunction"
      principal = "mq.amazonaws.com"
    }
  }
  handler = "index.handler"
  source_path = "${path.module}/function"
  runtime = "nodejs18.x"
  publish = true
  attach_policy_statements = true
  policy_statements = {
    mq = {
      effect    = "Allow",
      actions   = ["mq:DescribeBroker"],
      resources = [var.rabbit_mq_broker_arn]
    }
    secretsmanager = {
      effect    = "Allow",
      actions   = ["secretsmanager:GetSecretValue"],
      resources = [var.rabbit_mq_secret_arn]
    }
  }
}