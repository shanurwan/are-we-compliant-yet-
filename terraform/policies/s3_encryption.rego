package bnm

import data.bnm

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
	r := enc.values.rule[_]
	algo := r.apply_server_side_encryption_by_default.sse_algorithm
	["AES256", "aws:kms"][_] == algo
}
