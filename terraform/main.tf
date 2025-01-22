
variable "region" {
  type    = string
  default = "eu-west-2"
}

locals {
  vhost_name = "MyVirtualHost"
}

module "vpc" {
  source   = "./modules/vpc"
  vpc_cidr = var.vpc_cidr
  public_subnets = var.public_subnets
  private_subnets = var.private_subnets
  nat = var.nat
}

module "rabbit_broker_1" {
  source = "./modules/rabbit_broker"
  name_base = "RabbitBroker1"
  subnet_ids = module.vpc.public_subnets
  # upstream = null
  # queues = {
  #   ExampleQueue = {
  #     auto_delete = false
  #     durable = false
  #   }
  # }
}

module "rabbit_broker_2" {
  source = "./modules/rabbit_broker"
  name_base = "RabbitBroker2"
  subnet_ids = module.vpc.public_subnets
  # upstream = {
  #   endpoint_uri = module.rabbit_broker_1.rabbit_mq_broker_amqps_endpoint
  #   secret_arn = module.rabbit_broker_1.rabbit_mq_secret_arn
  # }
  # queues = {
  #   ExampleQueue = {
  #     auto_delete = false
  #     durable = false
  #   }
  # }
}

data "aws_secretsmanager_secret_version" "upstream_rabbit_mq_admin" {
  secret_id = module.rabbit_broker_1.rabbit_mq_secret_arn
}

data "aws_secretsmanager_secret_version" "downstream_rabbit_mq_admin" {
  secret_id = module.rabbit_broker_2.rabbit_mq_secret_arn
}

locals {
  downstream_username = jsondecode("${data.aws_secretsmanager_secret_version.downstream_rabbit_mq_admin.secret_string}")["username"]
  downstream_password = jsondecode("${data.aws_secretsmanager_secret_version.downstream_rabbit_mq_admin.secret_string}")["password"]
  upstream_username = jsondecode("${data.aws_secretsmanager_secret_version.upstream_rabbit_mq_admin.secret_string}")["username"]
  upstream_password = jsondecode("${data.aws_secretsmanager_secret_version.upstream_rabbit_mq_admin.secret_string}")["password"]
  upstream_endpoint_uri_trimmed = trimprefix(module.rabbit_broker_1.rabbit_mq_broker_amqps_endpoint, "amqps://")
  upstream_endpoint_url_auth = "amqps://${local.upstream_username}:${local.upstream_password}@${local.upstream_endpoint_uri_trimmed}/MyVirtualHost"
}

provider "rabbitmq" {
  alias = "downstream"
  endpoint = module.rabbit_broker_2.rabbit_mq_broker_https_endpoint
  username = local.downstream_username
  password = local.downstream_password
}

provider "rabbitmq" {
  alias = "upstream"
  endpoint = module.rabbit_broker_1.rabbit_mq_broker_https_endpoint
  username = local.upstream_username
  password = local.upstream_password
}

resource "rabbitmq_vhost" "upstream" {
  provider = rabbitmq.upstream
  name = local.vhost_name
}

resource "rabbitmq_vhost" "downstream" {
  provider = rabbitmq.downstream
  name = local.vhost_name
}

resource "rabbitmq_federation_upstream" "this" {
  provider = rabbitmq.downstream
  name = "Upstream"
  vhost = local.vhost_name
  definition {
    uri = local.upstream_endpoint_url_auth
  }
}

resource "rabbitmq_queue" "upstream" {
  provider = rabbitmq.upstream
  name = "UpstreamQueue"
  settings {
    durable = true
    auto_delete = false
  }
  vhost = local.vhost_name
}

resource "rabbitmq_queue" "downstream" {
  provider = rabbitmq.downstream
  name = "DownstreamQueue"
  settings {
    durable = true
    auto_delete = false
  }
  vhost = local.vhost_name
}

resource "rabbitmq_policy" "connect_to_upstream_queue" {
  provider = rabbitmq.downstream
  name = rabbitmq_queue.upstream.name
  vhost = rabbitmq_vhost.downstream.name
  policy {
    apply_to = "queues"
    definition = {"federation-upstream-set": "all"}
    pattern = rabbitmq_queue.upstream.name
    priority = 10
  }
}


# module "rabbit_lambda" {
#   source = "./modules/rabbit_lambda"
#   name_base = "RabbitLambda1"
#   rabbit_mq_broker_arn = module.rabbit_broker_2.rabbit_mq_broker_arn
#   rabbit_mq_secret_arn = module.rabbit_broker_2.rabbit_mq_secret_arn
#   rabbit_mq_queue_name = "ExampleQueue"
# }
