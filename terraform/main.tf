
locals {
  queue_name = "MyQueue"
  vhost_name = "MyVhost"
}

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

module "rabbit_upstream" {
  source = "./modules/rabbit_upstream"
  name_base = "RabbitUpstream"
  subnet_ids = [module.vpc.public_subnets[0]]
  vhost_name = local.vhost_name
  queue_name = local.queue_name
  is_ha = false
  is_public = true
}

module "rabbit_downstream" {
  source = "./modules/rabbit_downstream"
  name_base = "RabbitDownstream"
  subnet_ids = [module.vpc.public_subnets[0]]
  vhost_name = local.vhost_name
  queue_name = local.queue_name
  is_ha = false
  is_public = true
  upstream_broker_amqps_endpoint = module.rabbit_upstream.broker_amqps_endpoint
  upstream_rabbit_creds = {
    username = module.rabbit_upstream.rabbit_queue_user_creds["username"]
    password = module.rabbit_upstream.rabbit_queue_user_creds["password"]
  }
  upstream_vhost_name = local.vhost_name
}

module "rabbit_lambda" {
  source = "./modules/rabbit_lambda"
  name_base = "maris-proxy"
  rabbit_mq_broker_arn = "arn:aws:mq:eu-west-1:127214154594:broker:RabbitDownstream-Rabbit:b-067adb0f-64ed-4dd7-8e6f-6362206cd918"
  rabbit_mq_secret_arn = "arn:aws:secretsmanager:eu-west-1:127214154594:secret:RabbitDownstream/RabbitAdmin-gwFsbd"
  rabbit_mq_queue_name = "MyQueue"
  rabbit_mq_virtual_host = "MyVhost"
}
