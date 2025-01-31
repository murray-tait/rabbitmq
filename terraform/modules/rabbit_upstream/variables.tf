variable "name_base" {
  type = string
  description = "Name the resources in this module should be based on."
}

variable "subnet_ids" {
  type = list(string)
  description = "List of subnets to deploy the RabbitMQ broker in."
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

variable "vhost_name" {
  type = string
  description = "The name of the virtual host to create on the upstream broker."
}

variable "queue_name" {
  type = string
  description = "The name of the queue to create on the upstream broker."
}

variable "exchange_name" {
  type = string
  description = "The name of the exchange to create on the upstream broker."
}

variable "federation_user_name" {
  type = string
  description = "The name of the Rabbit user used for federating with downstream"
}