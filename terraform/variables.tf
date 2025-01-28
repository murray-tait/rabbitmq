variable "domain" {
  type    = string
  default = "murraytait.org"
}

variable "sub_system" {
  type    = string
  default = "rabbitmq"
}

variable "aws_route53_zone_id" {
  type    = string
  default = null
}

variable "environment" {
  type    = string
  default = null
}

variable "vpc_cidr" {
  type = string
  default = "10.3.0.0/16"
}

variable "public_subnets" {
  type = map(string)
  default = {
    "a" = "10.3.1.0/24",
    "b" = "10.3.2.0/24",
    "c" = "10.3.3.0/24"
  }
}

variable "private_subnets" {
  type = map(string)
  default = {
    "a" = "10.3.4.0/24",
    "b" = "10.3.5.0/24",
    "c" = "10.3.7.0/24"
  }
}

