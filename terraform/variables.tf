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
  validation {
    condition     = length(trimspace(var.name)) > 0
    error_message = "name must be non-empty."
  }
}

variable "cidr" {
  type    = string
  default = "10.10.0.0/16"
  validation {
    condition     = can(cidrnetmask(var.cidr))
    error_message = "cidr must be a valid IPv4 CIDR (e.g., 10.0.0.0/16)."
  }
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.10.0.0/24", "10.10.1.0/24"]
  validation {
    condition     = length(var.public_subnet_cidrs) > 0 && alltrue([for c in var.public_subnet_cidrs : can(cidrnetmask(c))])
    error_message = "public_subnet_cidrs must contain at least one valid IPv4 CIDR."
  }
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.10.10.0/24", "10.10.11.0/24"]
  validation {
    condition     = length(var.private_subnet_cidrs) > 0 && alltrue([for c in var.private_subnet_cidrs : can(cidrnetmask(c))])
    error_message = "private_subnet_cidrs must contain at least one valid IPv4 CIDR."
  }
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
      contains(keys(var.mandatory_tags), "Environment"),
    ]) && alltrue([for v in values(var.mandatory_tags) : length(trim(v)) > 0])
    error_message = "Mandatory tags must include non-empty Project, Owner, and Environment."
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
  validation {
    condition     = can(cidrnetmask(var.allowed_ssh_cidr))
    error_message = "allowed_ssh_cidr must be a valid CIDR (e.g., 203.0.113.5/32)."
  }
}

# tflint-ignore: terraform_unused_declarations
variable "db_username" {
  type    = string
  default = "app"
}

# tflint-ignore: terraform_unused_declarations
variable "db_password" {
  type      = string
  default   = "ChangeMe123!"
  sensitive = true
}

# tflint-ignore: terraform_unused_declarations
variable "db_name" {
  type    = string
  default = "appdb"
}

variable "kms_key_id" {
  type     = string
  default  = null
  nullable = true
  # Allow a KMS key ARN or alias/
  validation {
    condition     = var.kms_key_id == null || startswith(var.kms_key_id, "arn:") || startswith(var.kms_key_id, "alias/")
    error_message = "kms_key_id must be a KMS key ARN or start with alias/."
  }
}


