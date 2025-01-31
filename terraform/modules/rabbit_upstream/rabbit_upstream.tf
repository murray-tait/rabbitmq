terraform {
  required_providers {
    rabbitmq = {
      source = "rfd59/rabbitmq"
      version = "2.3.0"
    }
  }
}

resource "random_password" "rabbit_admin" {
  length = 32
  special = false
  min_lower = 1
  min_numeric = 1
  min_upper = 1
}

resource "aws_secretsmanager_secret" "rabbit_admin" {
  name = "${var.name_base}/RabbitAdmin"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "rabbit_admin" {
  secret_id     = aws_secretsmanager_secret.rabbit_admin.arn
  secret_string = jsonencode({
    username    = "RabbitAdmin"
    password    = "${random_password.rabbit_admin.result}"
  })
}

resource "random_password" "queue_user" {
  length = 32
  special = false
  min_lower = 1
  min_numeric = 1
  min_upper = 1
}

resource "aws_secretsmanager_secret" "queue_user" {
  name = "${var.name_base}/RabbitQueueUser"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "queue_user" {
  secret_id     = aws_secretsmanager_secret.queue_user.arn
  secret_string = jsonencode({
    username    = "RabbitQueueUser"
    password    = "${random_password.queue_user.result}"
  })
}

resource "random_password" "exchange_user" {
  length = 32
  special = false
  min_lower = 1
  min_numeric = 1
  min_upper = 1
}

resource "aws_secretsmanager_secret" "exchange_user" {
  name = "${var.name_base}/RabbitExchangeUser"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "exchange_user" {
  secret_id     = aws_secretsmanager_secret.exchange_user.arn
  secret_string = jsonencode({
    username    = "RabbitExchangeUser"
    password    = "${random_password.exchange_user.result}"
  })
}

data "aws_secretsmanager_secret_version" "rabbit_admin" {
  secret_id = aws_secretsmanager_secret.rabbit_admin.arn
}

resource "aws_mq_broker" "rabbit" {
  broker_name = "${var.name_base}-Rabbit"
  engine_type = "RabbitMQ"
  engine_version = "3.13"
  host_instance_type = "mq.t3.micro"
  auto_minor_version_upgrade = true
  publicly_accessible = var.is_public
  apply_immediately = true
  subnet_ids = var.subnet_ids
  user {
    username = local.rabbit_admin_username
    password = local.rabbit_admin_password
  }
  deployment_mode = var.is_ha ? "CLUSTER_MULTI_AZ" : "SINGLE_INSTANCE"
  logs {
    general = true
  }
}

locals {
  rabbit_admin_username = (jsondecode("${data.aws_secretsmanager_secret_version.rabbit_admin.secret_string}"))["username"]
  rabbit_admin_password = (jsondecode("${data.aws_secretsmanager_secret_version.rabbit_admin.secret_string}"))["password"]
}

provider "rabbitmq" {
  endpoint = "${aws_mq_broker.rabbit.instances.0.console_url}"
  username = local.rabbit_admin_username
  password = local.rabbit_admin_password
}

# resource "rabbitmq_vhost" "this" {
#   name = var.vhost_name
#   depends_on = [ aws_mq_broker.rabbit ]
# }

# resource "rabbitmq_queue" "this" {
#   name = var.queue_name
#   settings {
#     durable = true
#     auto_delete = false
#   }
#   vhost = rabbitmq_vhost.this.name
# }

# resource "rabbitmq_exchange" "this" {
#   name = var.exchange_name
#   vhost = var.vhost_name
#   settings {
#     type = "direct"
#     durable = true
#   }
# }

data "aws_secretsmanager_secret_version" "queue_user" {
  secret_id = aws_secretsmanager_secret.queue_user.id
  version_id = aws_secretsmanager_secret_version.queue_user.version_id
}

data "aws_secretsmanager_secret_version" "exchange_user" {
  secret_id = aws_secretsmanager_secret.exchange_user.id
  version_id = aws_secretsmanager_secret_version.exchange_user.version_id
}

resource "rabbitmq_user" "queue_user" {
  name = (jsondecode("${data.aws_secretsmanager_secret_version.queue_user.secret_string}"))["username"]
  password = (jsondecode("${data.aws_secretsmanager_secret_version.queue_user.secret_string}"))["password"]
}

resource "rabbitmq_user" "exchange_user" {
  name = (jsondecode("${data.aws_secretsmanager_secret_version.exchange_user.secret_string}"))["username"]
  password = (jsondecode("${data.aws_secretsmanager_secret_version.exchange_user.secret_string}"))["password"]
}

resource "rabbitmq_permissions" "queue_user" {
  user = rabbitmq_user.queue_user.name
  vhost = rabbitmq_vhost.this.name
  permissions {
    configure = ""
    write     = ""
    read      = ".*"
  }
}

resource "rabbitmq_permissions" "exchange_user" {
  user = rabbitmq_user.exchange_user.name
  vhost = rabbitmq_vhost.this.name
  permissions {
    configure = ""
    write     = ""
    read      = ".*"
  }
}








