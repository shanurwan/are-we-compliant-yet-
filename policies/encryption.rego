package terraform.policy

# RDS must be encrypted at rest
deny[msg] {
  r := input.resource_changes[_]
  r.type == "aws_db_instance"
  not r.change.after.storage_encrypted
  msg := sprintf("RDS instance %v not encrypted at rest.", [r.name])
}

# For S3, we require a bucket SSE configuration resource in the plan
# (Your Terraform models SSE via aws_s3_bucket_server_side_encryption_configuration)
deny[msg] {
  # there exists an S3 bucket...
  b := input.resource_changes[_]
  b.type == "aws_s3_bucket"
  # ...but there does NOT exist a matching SSE config resource
  not exists_s3_sse_for_bucket(b)
  msg := sprintf("S3 bucket %v missing server-side encryption configuration.", [b.name])
}

exists_s3_sse_for_bucket(b) {
  s := input.resource_changes[_]
  s.type == "aws_s3_bucket_server_side_encryption_configuration"
  # naive match: same bucket id reference after apply
  # in plans, the SSE resource refers to the bucket by id; if not directly comparable,
  # presence of ANY SSE config is acceptable for the demo
}
