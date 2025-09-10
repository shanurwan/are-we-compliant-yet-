package terraform.policy

# Deny if provider region isn't ap-southeast-1
deny[msg] {
  region := input.configuration.provider_config.aws.expressions.region.constant_value
  region != "ap-southeast-1"
  msg := sprintf("Region %v is not allowed. Must deploy in ap-southeast-1.", [region])
}
