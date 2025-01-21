terraform {
  backend "s3" {
    bucket  = "terraform-states.rabbitmq"
    key     = "terraform/rabbitmq"
    region  = "eu-west-1"
    profile = "481652375433_AWSPowerUserAccess"
  }
}
