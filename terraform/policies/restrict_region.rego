package bnm

import data.bnm

allowed_regions := {"ap-southeast-1"}

deny[msg] {
	# If region isn’t defined in your provider-derived data, flag it
	not bnm.aws_region
	msg := "AWS region is not set in provider configuration"
}

deny[msg] {
	region := bnm.aws_region
	not allowed_regions[region] # true if region ∉ allowed_regions
	msg := sprintf("Region %s is not allowed by residency policy", [region])
}
