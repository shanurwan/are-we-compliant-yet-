package bnm

import data.bnm

# 1) Inline rules inside aws_security_group

# IPv4
deny[msg] {
	sg := bnm.resources[_]
	sg.type == "aws_security_group"
	rule := sg.values.ingress[_]
	bnm.is_public_cidr(rule.cidr_blocks[_])
	not allowed_public_ingress(sg, rule)
	msg := sprintf("SG %q allows public IPv4 ingress on %v-%v", [sg.values.name, rule.from_port, rule.to_port])
}

# IPv6
deny[msg] {
	sg := bnm.resources[_]
	sg.type == "aws_security_group"
	rule := sg.values.ingress[_]
	bnm.is_public_cidr(rule.ipv6_cidr_blocks[_])
	not allowed_public_ingress(sg, rule)
	msg := sprintf("SG %q allows public IPv6 ingress on %v-%v", [sg.values.name, rule.from_port, rule.to_port])
}

# 2) Explicit aws_security_group_rule resources

# IPv4
deny[msg] {
	r := bnm.resources[_]
	r.type == "aws_security_group_rule"
	r.values.type == "ingress"
	bnm.is_public_cidr(r.values.cidr_blocks[_])
	not allowed_public_rule(r)
	msg := sprintf("SG rule %q allows public ingress on %v-%v", [r.address, r.values.from_port, r.values.to_port])
}

# IPv6
deny[msg] {
	r := bnm.resources[_]
	r.type == "aws_security_group_rule"
	r.values.type == "ingress"
	bnm.is_public_cidr(r.values.ipv6_cidr_blocks[_])
	not allowed_public_rule(r)
	msg := sprintf("SG rule %q allows public IPv6 ingress on %v-%v", [r.address, r.values.from_port, r.values.to_port])
}

# Allow-list: only bastion SSH (22) on the bastion SG name pattern
allowed_public_ingress(sg, rule) {
	contains(lower(sg.values.name), "-bastion-sg")
	rule.from_port == 22
	rule.to_port == 22
}

allowed_public_rule(r) {
	contains(lower(r.address), "bastion")
	r.values.from_port == 22
	r.values.to_port == 22
}
