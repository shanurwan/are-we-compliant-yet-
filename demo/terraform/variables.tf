variable "region" {
  description = "AWS region for deployment (BNM 2023)."
  type        = string
  default     = "ap-southeast-1"
}


variable "project_name" {
  description = "Project name prefix for resources"
  type        = string
  default     = "bnm-iac-demo"
}


variable "db_username" {
  type    = string
  default = "bnmadmin"
}


variable "db_password" {
  type      = string
  sensitive = true
}


variable "allowed_regions" {
  description = "Regions allowed by policy"
  type        = list(string)
  default     = ["ap-southeast-1"]
}