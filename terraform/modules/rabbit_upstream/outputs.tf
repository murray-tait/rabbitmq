output "vhost_name" {
  value = rabbitmq_vhost.this.name
  description = "Name of the virtual host" 
}

output "queue_name" {
  value = rabbitmq_queue.this.name
  description = "Name of the queue"
}

output "exchange_name" {
  value = rabbitmq_exchange.this.name
  description = "Name of the exchange"
}

output "broker_arn" {
  value = aws_mq_broker.rabbit.arn
  description = "ARN of the Rabbit MQ Broker"
}

output "broker_amqps_endpoint" {
  value = aws_mq_broker.rabbit.instances.0.endpoints.0
  description = "Endpoint of the Rabbit MQ Broker"
}

output "broker_https_endpoint" {
  value = aws_mq_broker.rabbit.instances.0.console_url
  description = "Endpoint of the Rabbit MQ Broker"
}

output "rabbit_admin_secret_arn" {
  value = aws_secretsmanager_secret.rabbit_admin.arn
  description = "ARN of the Rabbit MQ Secret"
}

output "federation_user_creds" {
  value = {
    username = jsondecode("${data.aws_secretsmanager_secret_version.federation_user.secret_string}")["username"]
    password = jsondecode("${data.aws_secretsmanager_secret_version.federation_user.secret_string}")["password"]
  }
  description = "The Credentials for the federation user created"
  sensitive = true
}

output "rabbit_admin_creds" {
  value = {
    username = jsondecode("${data.aws_secretsmanager_secret_version.rabbit_admin.secret_string}")["username"]
    password = jsondecode("${data.aws_secretsmanager_secret_version.rabbit_admin.secret_string}")["password"]
  }
  description = "The Credentials for the Admin User created"
  sensitive = true
}

