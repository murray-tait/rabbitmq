
variable "region" {
  type    = string
  default = "eu-west-2"
}

module "vpc" {
  source   = "./modules/vpc"
  vpc_cidr = var.vpc_cidr
  public_subnets = var.public_subnets
  private_subnets = var.private_subnets
  nat = var.nat
}

module "rabbit_broker_downstream" {
  source = "./modules/rabbit_broker"
  name_base = "RabbitBrokerDownstream"
  subnet_ids = module.vpc.public_subnets
}

module "rabbit_broker_upstream" {
  source = "./modules/rabbit_broker"
  name_base = "RabbitBrokerUpstream"
  subnet_ids = module.vpc.public_subnets
}

data "aws_secretsmanager_secret_version" "downstream_rabbit_mq_admin" {
  secret_id = module.rabbit_broker_downstream.rabbit_mq_secret_arn
}

data "aws_secretsmanager_secret_version" "upstream_rabbit_mq_admin" {
  secret_id = module.rabbit_broker_upstream.rabbit_mq_secret_arn
}

locals {
  downstream_username = jsondecode("${data.aws_secretsmanager_secret_version.downstream_rabbit_mq_admin.secret_string}")["username"]
  downstream_password = jsondecode("${data.aws_secretsmanager_secret_version.downstream_rabbit_mq_admin.secret_string}")["password"]
  upstream_username = jsondecode("${data.aws_secretsmanager_secret_version.upstream_rabbit_mq_admin.secret_string}")["username"]
  upstream_password = jsondecode("${data.aws_secretsmanager_secret_version.upstream_rabbit_mq_admin.secret_string}")["password"]
}

provider "rabbitmq" {
  alias = "downstream"
  endpoint = module.rabbit_broker_downstream.rabbit_mq_broker_https_endpoint
  username = local.downstream_username
  password = local.downstream_password
}

provider "rabbitmq" {
  alias = "upstream"
  endpoint = module.rabbit_broker_upstream.rabbit_mq_broker_https_endpoint
  username = local.upstream_username
  password = local.upstream_password
}

resource "rabbitmq_vhost" "upstream" {
  provider = rabbitmq.upstream
  name = "UpstreamVirtualHost"
}

resource "rabbitmq_vhost" "downstream" {
  provider = rabbitmq.downstream
  name = "DownstreamVirtualHost"
}

locals {
  upstream_endpoint_amqps_trimmed = trimprefix(module.rabbit_broker_upstream.rabbit_mq_broker_amqps_endpoint, "amqps://")
  upstream_endpoint_amqps_auth = "amqps://${local.upstream_username}:${local.upstream_password}@${local.upstream_endpoint_amqps_trimmed}/${rabbitmq_vhost.upstream.name}"
}

resource "rabbitmq_federation_upstream" "this" {
  provider = rabbitmq.downstream
  name = "FederationToUpstream"
  vhost = rabbitmq_vhost.downstream.name
  definition {
    uri = local.upstream_endpoint_amqps_auth
  }
}

resource "rabbitmq_queue" "upstream" {
  provider = rabbitmq.upstream
  name = "UpstreamQueue"
  settings {
    durable = true
    auto_delete = false
  }
  vhost = rabbitmq_vhost.upstream.name
}

resource "rabbitmq_queue" "downstream" {
  provider = rabbitmq.downstream
  name = "DownstreamQueue"
  settings {
    durable = true
    auto_delete = false
  }
  vhost = rabbitmq_vhost.downstream.name
}

resource "rabbitmq_policy" "connect_to_upstream_queue" {
  provider = rabbitmq.downstream
  name = "PullFromUpstreamQueue"
  vhost = rabbitmq_vhost.downstream.name
  policy {
    apply_to = "queues"
    definition = {"federation-upstream-set": "all"}
    pattern = rabbitmq_queue.upstream.name
    priority = 10
  }
}
