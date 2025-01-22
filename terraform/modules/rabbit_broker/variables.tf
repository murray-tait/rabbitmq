variable "name_base" {
  type = string
  description = "Name the resources in this module should be based on."
}

variable "subnet_ids" {
  type = list(string)
  description = "List of subnets to deploy the RabbitMQ cluster in."
}
