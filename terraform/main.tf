
variable "region" {
  type    = string
  default = "eu-west-2"
}

variable "nat" {
  type = bool
  default = false
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
  upstream = null
  queues = {
    ExampleQueue = {
      auto_delete = false
      durable = false
    }
  }
}

module "rabbit_broker_2" {
  source = "./modules/rabbit_broker"
  name_base = "RabbitBroker2"
  subnet_ids = module.vpc.public_subnets
  upstream = {
    endpoint_uri = module.rabbit_broker_1.rabbit_mq_broker_amqps_endpoint
    secret_arn = module.rabbit_broker_1.rabbit_mq_secret_arn
  }
  queues = {
    ExampleQueue = {
      auto_delete = false
      durable = false
    }
  }
}

# module "rabbit_lambda" {
#   source = "./modules/rabbit_lambda"
#   name_base = "RabbitLambda1"
#   rabbit_mq_broker_arn = module.rabbit_broker_2.rabbit_mq_broker_arn
#   rabbit_mq_secret_arn = module.rabbit_broker_2.rabbit_mq_secret_arn
#   rabbit_mq_queue_name = "ExampleQueue"
# }
