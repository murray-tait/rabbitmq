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

