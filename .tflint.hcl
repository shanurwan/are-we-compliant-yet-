plugin "aws" {
  enabled = true
  version = "0.30.0" # or bump later (see note below)
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

config {
  call_module_type = "local"  
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}
