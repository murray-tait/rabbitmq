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

data "aws_secretsmanager_secret_version" "rabbit_admin" {
  secret_id = aws_secretsmanager_secret.rabbit_admin.arn
  version_id = aws_secretsmanager_secret_version.rabbit_admin.version_id
}

resource "aws_secretsmanager_secret" "rabbit_upstream_federation_user" {
  name = "${var.name_base}/RabbitUpstreamFederationUser"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "rabbit_upstream_federation_user" {
  secret_id     = aws_secretsmanager_secret.rabbit_upstream_federation_user.arn
  secret_string = jsonencode({
    username    = var.upstream_rabbit_creds["username"]
    password    = var.upstream_rabbit_creds["password"]
  })
}

resource "random_password" "federation_user" {
  length = 32
  special = false
  min_lower = 1
  min_numeric = 1
  min_upper = 1
}

resource "aws_secretsmanager_secret" "federation_user" {
  name = "${var.name_base}/FederationUser"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "federation_user" {
  secret_id     = aws_secretsmanager_secret.federation_user.arn
  secret_string = jsonencode({
    username    = "federation_user"
    password    = "${random_password.federation_user.result}"
  })
}

locals {
  rabbit_admin_username = (jsondecode("${data.aws_secretsmanager_secret_version.rabbit_admin.secret_string}"))["username"]
  rabbit_admin_password = (jsondecode("${data.aws_secretsmanager_secret_version.rabbit_admin.secret_string}"))["password"]
  upstream_endpoint_amqps_trimmed = trimprefix(var.upstream_broker_amqps_endpoint, "amqps://")
  upstream_endpoint_amqps_auth_admin = "amqps://${var.upstream_rabbit_creds["username"]}:${var.upstream_rabbit_creds["password"]}@${local.upstream_endpoint_amqps_trimmed}/${var.upstream_vhost_name}"
  upstream_endpoint_amqps_auth_federation_user = "amqps://${var.upstream_federation_creds["username"]}:${var.upstream_federation_creds["password"]}@${local.upstream_endpoint_amqps_trimmed}/${var.upstream_vhost_name}"
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

provider "rabbitmq" {
  endpoint = aws_mq_broker.rabbit.instances.0.console_url
  username = local.rabbit_admin_username
  password = local.rabbit_admin_password
}

resource "rabbitmq_vhost" "this" {
  name = var.vhost_name
  depends_on = [ aws_mq_broker.rabbit ]
}

resource "rabbitmq_queue" "this" {
  name = var.queue_name
  settings {
    durable = true
    auto_delete = false
  }
  vhost = rabbitmq_vhost.this.name
}

resource "rabbitmq_exchange" "this" {
  name = var.exchange_name
  vhost = rabbitmq_vhost.this.name
  settings {
    type = "fanout"
    durable = true
  }
}

resource "rabbitmq_binding" "this" {
  source           = rabbitmq_exchange.this.name
  vhost            = rabbitmq_vhost.this.name
  destination      = rabbitmq_queue.this.name
  destination_type = "queue"
}

data "aws_secretsmanager_secret_version" "federation_user" {
  secret_id = aws_secretsmanager_secret.federation_user.id
  version_id = aws_secretsmanager_secret_version.federation_user.version_id
}

resource "rabbitmq_user" "federation_user" {
  name = (jsondecode("${data.aws_secretsmanager_secret_version.federation_user.secret_string}"))["username"]
  password = (jsondecode("${data.aws_secretsmanager_secret_version.federation_user.secret_string}"))["password"]
  tags = ["management"]
}

resource "rabbitmq_permissions" "federation_user" {
  user = rabbitmq_user.federation_user.name
  vhost = rabbitmq_vhost.this.name
  permissions {
    configure = ".*"
    write     = ".*"
    read      = ".*"
  }
}

resource "rabbitmq_federation_upstream" "this" {
  name = var.federation_upstream_name
  vhost = rabbitmq_vhost.this.name
  definition {
    uri = local.upstream_endpoint_amqps_auth_federation_user
    queue = var.upstream_queue_name
  }
}

resource "rabbitmq_policy" "this" {
  name = var.policy_name
  vhost = rabbitmq_vhost.this.name
  policy {
    apply_to = "all"
    definition = {
      federation-upstream-set = "all"
    }
    pattern = ".*test.*"
    priority = 1
  }
}
