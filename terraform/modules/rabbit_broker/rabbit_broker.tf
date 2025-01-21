terraform {
  required_providers {
    rabbitmq = {
      source = "rfd59/rabbitmq"
      version = "2.3.0"
    }
  }
}

variable "name_base" {
  type = string
  description = "Name the resources in this module should be based on."
}

variable "subnet_ids" {
  type = list(string)
  description = "List of subnets to deploy the RabbitMQ cluster in."
}

variable "queues" {
  description = "A map of objects representing the queues to be created and their setting. The key will be the name of the queue"
  type = map(object({
    durable = bool
    auto_delete = bool
    upstream_policy = optional(object({
      priority = number
      definition = map(string)
    }))
  }))
}

variable "upstream" {
  description = "Optional: Provide an object to connect to an upstream host."
  type = object({
    secret_arn = string
    endpoint_uri = string
  })
  nullable = true
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

provider "rabbitmq" {
  endpoint = aws_mq_broker.rabbit.instances.0.console_url
  username = local.username
  password = local.password
}

resource "rabbitmq_vhost" "vhost" {
  name = "MyVirtualHost"
}

resource "rabbitmq_queue" "queues" {
  for_each = var.queues
  name = each.key
  settings {
    durable = each.value.durable
    auto_delete = each.value.auto_delete
  }
  vhost = "MyVirtualHost"
}

/* resource "rabbitmq_policy" "upstream_queue_policy" {
  for_each = rabbitmq_queue.queues
  name = "${each.key}-UpstreamPolicy"
  vhost = "/"
  policy {
    apply_to = "queues"
    definition = var.queues[each.key].upstream_policy.definition
    pattern = each.key
    priority = var.queues[each.key].upstream_policy.priority
  }
} */

data "aws_secretsmanager_secret_version" "upstream" {
  count = var.upstream != null ? 1 : 0
  secret_id = var.upstream.secret_arn
}

locals {
  upstream_username = data.aws_secretsmanager_secret_version.upstream != [] ? jsondecode("${data.aws_secretsmanager_secret_version.upstream[0].secret_string}")["username"] : null
  upstream_password = data.aws_secretsmanager_secret_version.upstream != [] ? jsondecode("${data.aws_secretsmanager_secret_version.upstream[0].secret_string}")["password"] : null
  upstream_endpoint_uri_trimmed = var.upstream != null ? trimprefix(var.upstream.endpoint_uri, "amqps://") : null
  upstream_endpoint_url_auth = local.upstream_endpoint_uri_trimmed != null ? "amqps://${local.upstream_username}:${local.upstream_password}@${local.upstream_endpoint_uri_trimmed}/MyVirtualHost" : null
}

resource "rabbitmq_federation_upstream" "this" {
  count = var.upstream == null ? 0 : 1
  name = "Upstream"
  vhost = "MyVirtualHost"
  definition {
    uri = local.upstream_endpoint_url_auth
  }
}

output "rabbit_mq_broker_arn" {
  value = aws_mq_broker.rabbit.arn
  description = "ARN of the Rabbit MQ Broker"
}

output "rabbit_mq_broker_amqps_endpoint" {
  value = aws_mq_broker.rabbit.instances.0.endpoints.0
  description = "Endpoint of the Rabbit MQ Broker"
}

output "rabbit_mq_broker_https_endpoint" {
  value = aws_mq_broker.rabbit.instances.0.console_url
  description = "Endpoint of the Rabbit MQ Broker"
}

output "rabbit_mq_secret_arn" {
  value = aws_secretsmanager_secret.secret.arn
  description = "ARN of the Rabbit MQ Secret"
}
