terraform {
  required_providers {
    aws = {
      version = ">= 5.40.0"
    }
    random = {
      version = "= 3.6.0"
    }
    archive = {
      version = "= 2.4.2"
    }
    rabbitmq = {
      source = "rfd59/rabbitmq"
      version = "2.3.0"
    }    
  }
  required_version = ">=1.7.4"
}
