provider "aws" {
  profile = local.profile
  region  = local.region

  s3_use_path_style = true

  default_tags { tags = local.tags }
}

provider "aws" {
  profile = local.profile

  alias  = "global"
  region = "us-east-1"
  default_tags { tags = local.tags }
}

provider "rabbitmq" {
  endpoint = aws_mq_broker.rabbit.instances.0.console_url
  username = local.username
  password = local.password
}

