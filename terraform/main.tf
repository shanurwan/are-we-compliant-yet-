terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0"
    }
  }
}

provider "aws" {
  region = var.region

  # Mandatory tags applied to every resource by default.
  default_tags {
    tags = var.mandatory_tags
  }
}

module "vpc" {
  source               = "./modules/vpc"
  name                 = var.name
  cidr                 = var.cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "s3" {
  source     = "./modules/s3"
  name       = var.name
  kms_key_id = var.kms_key_id
}

module "iam" {
  source           = "./modules/iam"
  name             = var.name
  s3_bucket_arn    = module.s3.bucket_arn
  enable_s3_access = true
}


module "ec2" {
  source = "./modules/ec2"
  name   = var.name
  vpc_id = module.vpc.vpc_id

  # Only set when bastion is enabled; safely handle empty lists
  public_subnet_id   = var.enable_bastion && length(module.vpc.public_subnet_ids) > 0 ? module.vpc.public_subnet_ids[0] : null
  private_subnet_ids = module.vpc.private_subnet_ids
  enable_bastion     = var.enable_bastion

  # Don’t pass an SSH CIDR if no bastion
  allowed_ssh_cidr      = var.enable_bastion ? var.allowed_ssh_cidr : null
  instance_profile_name = module.iam.instance_profile_name
}


