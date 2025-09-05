package bnm

import data.bnm

default deny = []

# Flag any aws_s3_bucket that lacks a matching SSE config resource
deny[msg] {
  b := bnm.resources[_]
  b.type == "aws_s3_bucket"
  name := b.values.bucket
  not some_enc_for_bucket(name)
  msg := sprintf("S3 bucket %q missing server-side encryption configuration", [name])
}

some_enc_for_bucket(name) {
  enc := bnm.resources[_]
  enc.type == "aws_s3_bucket_server_side_encryption_configuration"
  enc.values.bucket == name
  # basic sanity on algorithm
  some r
  r := enc.values.rule[0]
  algo := r.apply_server_side_encryption_by_default.sse_algorithm
  algo == "AES256" or algo == "aws:kms"
}
