package bnm

import data.bnm

default deny = []

allowed_regions := {"ap-southeast-1"}

deny[msg] {
  not bnm.aws_region  # missing region is a misconfig
  msg := "AWS region is not set in provider configuration"
}

deny[msg] {
  region := bnm.aws_region
  not allowed_regions[region]
  msg := sprintf("Region %s is not allowed by residency policy", [region])
}
