package terraform.policy

# CloudWatch Log Groups must be KMS-encrypted.
# Pass if kms_key_id is set, or is "unknown" in the plan, or present in config expressions.
deny[msg] {
  r := input.resource_changes[_]
  r.type == "aws_cloudwatch_log_group"
  not has_kms(r)
  msg := sprintf("CloudWatch Log Group %v missing kms_key_id.", [r.name])
}

has_kms(r) {
  # 1 Concrete value in the plan
  r.change.after.kms_key_id
}

has_kms(r) {
  # 2 Value is computed/unknown at plan time (will be known at apply)
  r.change.after_unknown.kms_key_id
}

has_kms(r) {
  # 3 Fallback to configuration: kms_key_id expression exists on the same resource
  #    (covers cases where 'after' is null but config clearly sets a reference)
  rm := input.configuration.root_module.resources[_]
  rm.type == "aws_cloudwatch_log_group"
  rm.address == r.address
  rm.expressions.kms_key_id
}
