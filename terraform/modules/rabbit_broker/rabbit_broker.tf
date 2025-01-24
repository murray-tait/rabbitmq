terraform {
  required_providers {
    rabbitmq = {
      source = "rfd59/rabbitmq"
      version = "2.3.0"
    }
  }
}

resource "random_password" "rabbit_mq_admin" {
  length = 16
  special = false
  min_lower = 1
  min_numeric = 1
  min_upper = 1
}

resource "aws_secretsmanager_secret" "secret" {
  name = "${var.name_base}"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "rabbit_mq_admin" {
  secret_id     = aws_secretsmanager_secret.secret.arn
  secret_string = jsonencode({
    username    = "RabbitAdmin"
    password    = "${random_password.rabbit_mq_admin.result}"
  })
}

data "aws_secretsmanager_secret_version" "rabbit_mq_admin" {
  secret_id = aws_secretsmanager_secret.secret.id
  version_id = aws_secretsmanager_secret_version.rabbit_mq_admin.version_id
}

locals {
  username = (jsondecode("${data.aws_secretsmanager_secret_version.rabbit_mq_admin.secret_string}"))["username"]
  password = (jsondecode("${data.aws_secretsmanager_secret_version.rabbit_mq_admin.secret_string}"))["password"]
}

resource "aws_mq_broker" "rabbit" {
  broker_name = var.name_base
  engine_type = "RabbitMQ"
  engine_version = "3.13"
  host_instance_type = "mq.t3.micro"
  auto_minor_version_upgrade = true
  publicly_accessible = true
  apply_immediately = true
  subnet_ids = [var.subnet_ids[0]]
  user {
    username = local.username
    password = local.password
  }
  deployment_mode = "SINGLE_INSTANCE"
  logs {
    general = true
  }
}





