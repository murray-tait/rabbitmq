
variable "region" {
  type    = string
  default = "eu-west-2"
}

module "vpc" {
  source   = "./modules/vpc"
  vpc_cidr = var.vpc_cidr
  public_subnets = var.public_subnets
  private_subnets = var.private_subnets
}

module "rabbit_upstream" {
  source = "./modules/rabbit_upstream"
  name_base = "RabbitUpstream"
  subnet_ids = [module.vpc.public_subnets[0]]
  is_ha = false
  is_public = true
  vhost_name = "UpstreamVhost"
  queue_name = "UpstreamQueue"
  exchange_name = "UpstreamExchange"
}

module "rabbit_downstream" {
  source = "./modules/rabbit_downstream"
  name_base = "RabbitDownstream"
  subnet_ids = [module.vpc.public_subnets[0]]
  is_ha = false
  is_public = true
  vhost_name = "DownstreamVhost"
  queue_name = "DownstreamQueue"
  exchange_name = "DownstreamExchange"
  upstream_broker_amqps_endpoint = module.rabbit_upstream.broker_amqps_endpoint
  upstream_rabbit_creds = {
    username = module.rabbit_upstream.rabbit_admin_creds["username"]
    password = module.rabbit_upstream.rabbit_admin_creds["password"]
  }
  upstream_queue_creds = {
    username = module.rabbit_upstream.queue_user_creds["username"]
    password = module.rabbit_upstream.queue_user_creds["password"]
  }
  upstream_exchange_creds = {
    username = module.rabbit_upstream.exchange_user_creds["username"]
    password = module.rabbit_upstream.exchange_user_creds["password"]
  }
  upstream_vhost_name = "UpstreamVhost"
  upstream_queue_name = "UpstreamQueue"
  upstream_exchange_name = "UpstreamExchange"
}

# module "rabbit_lambda" {
#   source = "./modules/rabbit_lambda"
#   name_base = "maris-proxy"
#   rabbit_mq_broker_arn = "arn:aws:mq:eu-west-1:127214154594:broker:RabbitDownstream-Rabbit:b-067adb0f-64ed-4dd7-8e6f-6362206cd918"
#   rabbit_mq_secret_arn = "arn:aws:secretsmanager:eu-west-1:127214154594:secret:RabbitDownstream/RabbitAdmin-gwFsbd"
#   rabbit_mq_queue_name = local.queue_name
#   rabbit_mq_virtual_host = local.vhost_name
# }
