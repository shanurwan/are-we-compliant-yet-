package bnm

import data.bnm

default deny = []

deny[msg] {
  r := bnm.resources[_]
  # only check resources that actually support 'tags' (skip if missing)
  has_field(r.values, "tags")
  missing := {t | t := bnm.required_tags[_]; not has_field(r.values.tags, t)}
  count(missing) > 0
  msg := sprintf("%s missing mandatory tags: %v", [r.address, missing])
}

has_field(obj, key) {
  obj[key]
}
