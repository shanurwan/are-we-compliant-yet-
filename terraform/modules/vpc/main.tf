variable "name" {
  type = string
}

variable "cidr" {
  type = string
  validation {
    condition     = can(cidrnetmask(var.cidr))
    error_message = "cidr must be a valid IPv4 CIDR (e.g., 10.0.0.0/16)."
  }
}

variable "public_subnet_cidrs" {
  type = list(string)
  validation {
    # Just ensure it's non-empty; avoids tricky funcs/comprehensions
    condition     = length(var.public_subnet_cidrs) > 0
    error_message = "public_subnet_cidrs must contain at least one CIDR."
  }
}

variable "private_subnet_cidrs" {
  type = list(string)
  validation {
    condition     = length(var.private_subnet_cidrs) > 0
    error_message = "private_subnet_cidrs must contain at least one CIDR."
  }
}



# Choose a deterministic public subnet (first by sorted CIDR) for the NAT gateway
locals {
  nat_subnet_key = sort(var.public_subnet_cidrs)[0]
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "${var.name}-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-igw" }
}

# Key by CIDR (map), not a set, to keep a predictable key we can reference
resource "aws_subnet" "public" {
  for_each                = { for cidr in var.public_subnet_cidrs : cidr => cidr }
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  map_public_ip_on_launch = true
  tags = { Name = "${var.name}-public-${each.value}" }
}

resource "aws_subnet" "private" {
  for_each   = { for cidr in var.private_subnet_cidrs : cidr => cidr }
  vpc_id     = aws_vpc.this.id
  cidr_block = each.value
  tags = { Name = "${var.name}-private-${each.value}" }
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.name}-nat-eip" }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.allocation_id
  subnet_id     = aws_subnet.public[local.nat_subnet_key].id
  tags          = { Name = "${var.name}-nat" }

  # Optional: ensure the IGW exists before NAT for quicker reachability
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "${var.name}-private-rt" }
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

output "vpc_id" {
  value = aws_vpc.this.id
}

# Build lists in a stable order by iterating sorted keys
output "public_subnet_ids" {
  value = [for k in sort(keys(aws_subnet.public)) : aws_subnet.public[k].id]
}

output "private_subnet_ids" {
  value = [for k in sort(keys(aws_subnet.private)) : aws_subnet.private[k].id]
}
