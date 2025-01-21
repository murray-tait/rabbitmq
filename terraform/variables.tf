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