variable "name_base" {
  type = string
  description = "Name the resources in this module should be based on."
}

variable "subnet_ids" {
  type = list(string)
  description = "List of subnets to deploy the RabbitMQ broker in."
}

variable "vhost_name" {
  type = string
  description = "Name of the virtual host to create that the queue is created in."
}

variable "queue_name" {
  type = string
  description = "Name of the queue to create."
}

variable "is_public" {
  type = bool
  description = "Whether the broker should be public or not."
  default = false
}

variable "is_ha" {
  type = bool
  description = "Whether the broker should be clustered for high availability or not."
}
