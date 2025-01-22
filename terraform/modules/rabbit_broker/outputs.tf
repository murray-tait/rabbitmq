output "rabbit_mq_broker_arn" {
  value = aws_mq_broker.rabbit.arn
  description = "ARN of the Rabbit MQ Broker"
}

output "rabbit_mq_broker_amqps_endpoint" {
  value = aws_mq_broker.rabbit.instances.0.endpoints.0
  description = "Endpoint of the Rabbit MQ Broker"
}

output "rabbit_mq_broker_https_endpoint" {
  value = aws_mq_broker.rabbit.instances.0.console_url
  description = "Endpoint of the Rabbit MQ Broker"
}

output "rabbit_mq_secret_arn" {
  value = aws_secretsmanager_secret.secret.arn
  description = "ARN of the Rabbit MQ Secret"
}
