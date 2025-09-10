#Keep consistent name

locals {
  name = "${var.project_name}-${replace(var.region, "+", "")}"
  
}

#RMiT baseline audit trail


resource "aws_kms_key" "logs" {
  description         = "KMS key for CloudWatch Logs encryption" # add KMS for logs to pass checkov
  enable_key_rotation = true
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/bnm/${local.name}"
  retention_in_days = 400           # retention >= 365  to pass checkov
  kms_key_id        = aws_kms_key.logs.arn
  
}

#S3
resource "random_id" "suffix" {  #global unique name for S3
byte_length = 2
}

resource "aws_s3_bucket" "data" {
bucket = "${local.name}-data-${random_id.suffix.hex}"  
}


resource "aws_s3_bucket_versioning" "data" {
bucket = aws_s3_bucket.data.id
versioning_configuration { status = "Enabled" }  #versioning = auditability
}


resource "aws_s3_bucket_server_side_encryption_configuration" "data" {    #RMit : encryption 
bucket = aws_s3_bucket.data.id
rule {
apply_server_side_encryption_by_default {
sse_algorithm = "AES256"
}
bucket_key_enabled = true
}
}


# IAM (least privilege)

resource "aws_iam_role" "app_role" {
name = "${local.name}-role"
assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}


data "aws_iam_policy_document" "ec2_assume_role" {
statement {
actions = ["sts:AssumeRole"]
principals {
type = "Service"
identifiers = ["ec2.amazonaws.com"]  #Limit to ec2.amazonaws.com
}
}
}


resource "aws_iam_policy" "s3_readonly" {
name = "${local.name}-s3-ro"
description = "Least privilege RO access to demo bucket"
policy = data.aws_iam_policy_document.s3_ro.json
}


data "aws_iam_policy_document" "s3_ro" {
statement {
actions = ["s3:GetObject", "s3:ListBucket"]
resources = [aws_s3_bucket.data.arn, "${aws_s3_bucket.data.arn}/*"]
}
}


resource "aws_iam_role_policy_attachment" "attach_ro" {
role = aws_iam_role.app_role.name
policy_arn = aws_iam_policy.s3_readonly.arn
}



# demo networking, for simplicity reuse default VPC. For production best practice create custom and enforce "no default"

data "aws_vpc" "default" {
default = true
}


data "aws_subnets" "default" {
filter {
name = "vpc-id"
values = [data.aws_vpc.default.id]
}
}


# DB subnet group (tells rds which subnet to use)
# Best practice: ensure they’re private subnets (no direct internet route).

resource "aws_db_subnet_group" "db" {
  name       = "${local.name}-db-subnets"
  subnet_ids = data.aws_subnets.default.ids
}


# RDS  : Data Encryption (at rest), Access Control (not public)

resource "aws_db_instance" "db" {
  identifier           = "${local.name}-db"
  allocated_storage    = 20
  engine               = "postgres"
  engine_version       = "16.3"
  instance_class       = "db.t3.micro"
  username             = var.db_username
  password             = var.db_password
  db_subnet_group_name = aws_db_subnet_group.db.name

  auto_minor_version_upgrade = true


  storage_encrypted    = true
  publicly_accessible  = false
  skip_final_snapshot  = true
  deletion_protection  = true

  #update to pass checkov

    # Logging / audit
  enabled_cloudwatch_logs_exports = ["postgresql"]

  # Enhanced monitoring
  monitoring_interval = 60                      # seconds
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  # IAM auth
  iam_database_authentication_enabled = true

  # Protection & HA (these flip several checks)
  multi_az            = true

  # Performance Insights + KMS
  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.pi.arn
}

data "aws_iam_policy_document" "rds_monitoring_trust" {
  statement {
    actions = ["sts:AssumeRole"] 
    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]        
    }
  }
}

resource "aws_iam_role" "rds_monitoring" {
  name               = "${local.name}-rds-monitoring"
  assume_role_policy = data.aws_iam_policy_document.rds_monitoring_trust.json
}

resource "aws_iam_role_policy_attachment" "rds_monitoring_attach" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}


resource "aws_kms_key" "pi" {
  description         = "KMS for RDS Performance Insights" # KMS key for Performance Insights
  enable_key_rotation = true
}


#policy input helper
#terraform plan -out=tfplan && terraform show -json tfplan > policy-inputs/plan.json

resource "null_resource" "gen_plan" {
  triggers = { region = var.region }
}


