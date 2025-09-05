package bnm

# Collect all planned resources (root + one nested level).
resources[r] {
	r := input.planned_values.root_module.resources[_]
}

resources[r] {
	cm := input.planned_values.root_module.child_modules[_]
	r := cm.resources[_]
}

is_public_cidr(c) {
	c == "0.0.0.0/0"
}

is_public_cidr(c) {
	c == "::/0"
}

required_tags := {"Project", "Owner", "Environment"}

# Get AWS provider region from configuration (what Terraform will use)
aws_region := region {
	region := input.configuration.provider_config.aws.expressions.region.constant_value
}
