package terraform.policy

# Simple least-privilege guard: forbid wildcard Actions in managed IAM policies
# (Checkov already does deep IAM analysis; we keep this OPA rule straightforward.)
deny[msg] {
  r := input.resource_changes[_]
  r.type == "aws_iam_policy"
  policy := r.change.after.policy

  # policy may be a JSON string; parse it if so
  some_action_is_wildcard(policy)
  msg := sprintf("IAM policy %v allows wildcard actions (*).", [r.name])
}

some_action_is_wildcard(policy) {
  # try parse when it's a string
  obj := json.unmarshal(policy)
  stmt := obj.Statement[_]
  action := stmt.Action
  action == "*"
}

some_action_is_wildcard(policy) {
  # or it may already be an object
  stmt := policy.Statement[_]
  action := stmt.Action
  action == "*"
}
