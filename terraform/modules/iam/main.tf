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

variable "s3_bucket_arn" {
  type    = string
  default = null
  # Expect a bucket ARN like arn:aws:s3:::my-bucket (no /* here)
  validation {
    condition     = var.s3_bucket_arn == null || can(regex("^arn:aws(-[a-z]+)?:s3:::[-a-z0-9.]{3,63}$", var.s3_bucket_arn))
    error_message = "s3_bucket_arn must be an S3 bucket ARN like arn:aws:s3:::my-bucket."
  }
}

variable "enable_s3_access" {
  type    = bool
  default = true
}

# --- Trust policy for EC2 role
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "${var.name}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  # Enforce cross-field rule at runtime (valid in Terraform 1.2+)
  lifecycle {
    precondition {
      condition     = !var.enable_s3_access || var.s3_bucket_arn != null
      error_message = "enable_s3_access is true, but s3_bucket_arn is not set."
    }
  }
}

# Allow SSM Session Manager (preferred over direct SSH)
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Build the S3 policy only when both enabled and ARN provided
data "aws_iam_policy_document" "s3_limited" {
  count = var.enable_s3_access && var.s3_bucket_arn != null ? 1 : 0

  statement {
    sid       = "ListBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [var.s3_bucket_arn]
  }

  statement {
    sid       = "ObjectRW"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${var.s3_bucket_arn}/*"]
  }
}

resource "aws_iam_policy" "s3_limited" {
  count  = var.enable_s3_access && var.s3_bucket_arn != null ? 1 : 0
  name   = "${var.name}-s3-limited"
  policy = data.aws_iam_policy_document.s3_limited[0].json
}

resource "aws_iam_role_policy_attachment" "s3_attach" {
  count      = var.enable_s3_access && var.s3_bucket_arn != null ? 1 : 0
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.s3_limited[0].arn
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.name}-instance-profile"
  role = aws_iam_role.ec2.name
}

output "instance_profile_name" { value = aws_iam_instance_profile.ec2.name }
output "role_arn"              { value = aws_iam_role.ec2.arn }
