terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "name" { type = string }
variable "vpc_id" { type = string }

# tflint-ignore: terraform_unused_declarations
variable "private_subnet_ids" { type = list(string) }

variable "enable_bastion" {
  type    = bool
  default = true
}

variable "public_subnet_id" {
  type     = string
  default  = null
  nullable = true
  
  validation {
    condition     = var.public_subnet_id == null || length(trim(var.public_subnet_id)) > 0
    error_message = "public_subnet_id can be null or a non-empty string."
  }
}

variable "allowed_ssh_cidr" {
  type    = string
  default = "0.0.0.0/0"
  
  validation {
    condition     = can(cidrnetmask(var.allowed_ssh_cidr))
    error_message = "allowed_ssh_cidr must be a valid CIDR (e.g., 203.0.113.5/32)."
  }
}

variable "instance_profile_name" {
  type    = string
  default = null
}

locals {
  ami_owner = "099720109477" # Canonical (Ubuntu)
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = [local.ami_owner]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_security_group" "bastion_sg" {
  count  = var.enable_bastion ? 1 : 0
  name   = "${var.name}-bastion-sg"
  vpc_id = var.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-bastion-sg" }
}

resource "aws_instance" "bastion" {
  count                       = var.enable_bastion ? 1 : 0
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = aws_security_group.bastion_sg[*].id
  associate_public_ip_address = true
  iam_instance_profile        = var.instance_profile_name

  tags = { Name = "${var.name}-bastion" }

  
  lifecycle {
    precondition {
      condition     = !var.enable_bastion || var.public_subnet_id != null
      error_message = "public_subnet_id must be set when enable_bastion = true."
    }
    precondition {
      condition     = !var.enable_bastion || can(cidrnetmask(var.allowed_ssh_cidr))
      error_message = "allowed_ssh_cidr must be a valid CIDR when enable_bastion = true."
    }
  }
}


resource "aws_security_group" "app_sg" {
  name   = "${var.name}-app-sg"
  vpc_id = var.vpc_id

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-app-sg" }
}

resource "aws_security_group_rule" "app_ssh_from_bastion" {
  count                    = var.enable_bastion ? 1 : 0
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app_sg.id
  source_security_group_id = try(aws_security_group.bastion_sg[0].id, null)
}

output "bastion_public_ip" {
  value = try(aws_instance.bastion[0].public_ip, null)
}

output "bastion_sg_id" {
  value = try(aws_security_group.bastion_sg[0].id, null)
}

output "app_sg_id" {
  value = aws_security_group.app_sg.id
}
