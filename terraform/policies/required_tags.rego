package bnm

import data.bnm

# Only check managed resources that actually have a tags field
deny[msg] {
  r := bnm.resources[_]
  not is_data(r.address)

  # if resource has no tags/tags_all at all, skip it
  tags := object.get(r.values, "tags", object.get(r.values, "tags_all", null))
  tags != null

  missing := {t |
    t := bnm.required_tags[_]
    not has_nonempty(tags, t)
  }
  count(missing) > 0

  msg := sprintf("%s missing mandatory tags: %v", [r.address, missing])
}

has_nonempty(obj, k) {
  v := obj[k]
  v != ""
}

# Treat anything with "data." in the address as a data source
is_data(addr) {
  startswith(addr, "data.")
} {
  contains(addr, ".data.")
}
