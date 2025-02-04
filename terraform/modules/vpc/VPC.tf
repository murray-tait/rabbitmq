
variable "vpc_cidr" {
  default     = "10.2.0.0/16"
  type        = string
  description = "CIDR block for the VPC in the form x.x.x.x/y"
  validation {
    condition     = can(regex("((\\d{1,3}).){3}\\d{1,3}/\\d{1,2}", var.vpc_cidr))
    error_message = "CIDR block incorrectly formatted."
  }
}

variable "public_subnets" {
  default = {
    "a" = "10.2.1.0/24",
    "b" = "10.2.2.0/24",
    "c" = "10.2.3.0/24"
  }
  type        = map(string)
  description = "CIDR blocks for the Public Subnets"
}

variable "private_subnets" {
  default = {
    "a" = "10.2.4.0/24",
    "b" = "10.2.5.0/24",
    "c" = "10.2.6.0/24"
  }
  type        = map(string)
  description = "CIDR blocks for the Public Subnets"
}

variable "nat" {
  default     = false
  type        = bool
  description = "True to create nat gateways. False for no nat gateways."
  validation {
    condition     = var.nat == true || var.nat == false
    error_message = "Must be either true or false."
  }
}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "tf_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  instance_tenancy     = "default"
  tags = {
    Name = "${terraform.workspace}-vpc"
  }
}

resource "aws_eip" "this" {
  count = var.nat ? 1 : 0
}

resource "aws_route" "route_nat" {
  count = var.nat ? 1 : 0
  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = aws_route_table.private_route_table.id
  nat_gateway_id         = aws_nat_gateway.nat_gw[0].id
}

resource "aws_subnet" "public_subnet" {
  availability_zone = join("", [data.aws_region.current.name, each.key])
  for_each          = var.public_subnets
  vpc_id            = aws_vpc.tf_vpc.id
  cidr_block        = each.value
  map_public_ip_on_launch = true
  tags = {
    Name = "${terraform.workspace}-public_subnet-${each.key}"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  count = var.nat ? 1 : 0
  allocation_id = aws_eip.this[0].allocation_id
  subnet_id = aws_subnet.public_subnet["a"].id
}

resource "aws_subnet" "private_subnet" {
  availability_zone = join("", [data.aws_region.current.name, each.key])
  for_each          = var.private_subnets
  vpc_id            = aws_vpc.tf_vpc.id
  cidr_block        = each.value
  tags = {
    Name = "${terraform.workspace}-private_subnet-${each.key}"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id   = aws_vpc.tf_vpc.id
  tags = {
    Name = "${terraform.workspace}-private_route_table"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.tf_vpc.id
  tags = {
    Name = "${terraform.workspace}-public_route_table"
  }
}

resource "aws_route_table_association" "rtas_public" {
  for_each       = aws_subnet.public_subnet
  route_table_id = aws_route_table.public_route_table.id
  subnet_id      = each.value.id
}

resource "aws_route_table_association" "rtas_private" {
  for_each       = aws_subnet.private_subnet
  route_table_id = aws_route_table.private_route_table.id
  subnet_id      = each.value.id
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.tf_vpc.id
}

resource "aws_route" "route_igw" {
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
  route_table_id         = aws_route_table.public_route_table.id
}

output "vpc_id" {
  value = aws_vpc.tf_vpc.id
}

data "aws_caller_identity" "current" {}

output "region" {
  value = data.aws_region.current
}

output "region_name" {
  value = data.aws_region.current.name
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}


output "private_subnets" {
  value = [
    for psn in aws_subnet.private_subnet : psn.id
  ]
}

output "public_subnets" {
  value = [
    for psn in aws_subnet.public_subnet : psn.id
  ]
}