variable "name" {
  type = string
  validation {
    condition     = length(trimspace(var.name)) > 0
    error_message = "name must be non-empty."
  }
}

variable "kms_key_id" {
  type    = string
  default = null
  # Keep it simple: allow KMS key ARN or alias/
  validation {
    condition     = var.kms_key_id == null || startswith(var.kms_key_id, "arn:") || startswith(var.kms_key_id, "alias/")
    error_message = "kms_key_id must be a KMS key ARN or start with alias/."
  }
}

resource "random_id" "suffix" {
  byte_length = 2 # 4 hex chars
}

# -------- Name normalization without regexreplace --------
locals {
  # Keep only [a-z0-9-], lowercase
  base_name      = join("", regexall("[a-z0-9-]", lower(var.name)))
  base_nonempty  = local.base_name != "" ? local.base_name : "bucket"      # fallback
  base_start     = startswith(local.base_nonempty, "-") ? "a${local.base_nonempty}" : local.base_nonempty
  base_clean     = endswith(local.base_start, "-") ? "${local.base_start}a" : local.base_start

  # Suffix and length guard (suffix = "-app-XXXX" -> 9 chars)
  suffix         = "-app-${random_id.suffix.hex}"
  max_prefix_len = 63 - length(local.suffix)
  prefix_trunc   = substr(local.base_clean, 0, local.max_prefix_len)
  prefix_final   = endswith(local.prefix_trunc, "-") ? substr(local.prefix_trunc, 0, length(local.prefix_trunc) - 1) : local.prefix_trunc
  prefix_nonempty= local.prefix_final != "" ? local.prefix_final : "bucket"

  bucket_name    = "${local.prefix_nonempty}${local.suffix}"
}

resource "aws_s3_bucket" "this" {
  bucket        = local.bucket_name
  force_destroy = true
  tags          = { Name = "${var.name}-app" }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_id == null ? "AES256" : "aws:kms"
      kms_master_key_id = var.kms_key_id
    }
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# TLS-only bucket policy
resource "aws_s3_bucket_policy" "tls_only" {
  bucket = aws_s3_bucket.this.id
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Sid       = "DenyInsecureTransport",
        Effect    = "Deny",
        Principal = "*",
        Action    = "s3:*",
        Resource  = [
          aws_s3_bucket.this.arn,
          "${aws_s3_bucket.this.arn}/*"
        ],
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      }
    ]
  })
}

output "bucket"     { value = aws_s3_bucket.this.id }
output "bucket_arn" { value = aws_s3_bucket.this.arn }
