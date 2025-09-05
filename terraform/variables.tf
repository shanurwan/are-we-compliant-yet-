variable "region" {
  description = "AWS region (residency guardrail)"
  type        = string
  default     = "ap-southeast-1"

  validation {
    condition     = var.region == "ap-southeast-1"
    error_message = "Only ap-southeast-1 is allowed by residency policy."
  }
}

variable "name" {
  type    = string
  default = "bnm-mvp"
}

variable "cidr" {
  type    = string
  default = "10.10.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.10.0.0/24", "10.10.1.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.10.10.0/24", "10.10.11.0/24"]
}

variable "mandatory_tags" {
  description = "Mandatory tags applied to all resources"
  type        = map(string)
  default = {
    Project     = "bnm-iac-demo"
    Owner       = "platform"
    Environment = "dev"
  }

  validation {
    condition = alltrue([
      contains(keys(var.mandatory_tags), "Project"),
      contains(keys(var.mandatory_tags), "Owner"),
      contains(keys(var.mandatory_tags), "Environment")
    ])
    error_message = "Mandatory tags must include Project, Owner, and Environment."
  }
}

variable "enable_bastion" {
  type    = bool
  default = true
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH to the bastion"
  type        = string
  default     = "0.0.0.0/0"
}

variable "db_username" {
  type    = string
  default = "app"
}

variable "db_password" {
  type      = string
  default   = "ChangeMe123!"
  sensitive = true
}

variable "db_name" {
  type    = string
  default = "appdb"
}

variable "kms_key_id" {
  type    = string
  default = null
}

