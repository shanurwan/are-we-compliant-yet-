output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "VPC ID"
}

output "public_subnet_ids" {
  value       = module.vpc.public_subnet_ids
  description = "IDs of public subnets"
}

output "private_subnet_ids" {
  value       = module.vpc.private_subnet_ids
  description = "IDs of private subnets"
}

output "bastion_public_ip" {
  value       = module.ec2.bastion_public_ip
  sensitive   = true
  description = "Public IP of the bastion host"
}

output "app_sg_id" {
  value       = module.ec2.app_sg_id
  description = "Security group ID for the app"
}



output "s3_bucket" {
  value       = module.s3.bucket
  description = "S3 bucket name"
}
