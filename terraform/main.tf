
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
    username = module.rabbit_upstream.rabbit_admin_creds["username"]
    password = module.rabbit_upstream.rabbit_admin_creds["password"]
  }
  upstream_vhost_name = local.vhost_name
}






