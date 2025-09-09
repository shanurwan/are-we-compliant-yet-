# BNM-Compliant IaC Demo Project

## Project Overview

This project demonstrates how to use Infrastructure-as-Code (IaC) with Terraform and Ansible to provision secure cloud infrastructure that aligns with Bank Negara Malaysia (BNM) RMiT compliance requirements.

## Key highlights:

- Automated infrastructure deployment (Terraform).

- Secure configuration and OS hardening (Ansible).

- Policy-as-Code enforcement (OPA / Sentinel).

- Continuous compliance reporting (Checkov / Terraform Compliance).

- End-to-end CI/CD pipeline (GitHub Actions).


## Compliance Controls Implemented

This demo simulates BNM RMiT requirements, mapped to IaC:

1. Data Encryption:

- S3 with AES-256 encryption.

- RDS with storage encryption.

2. Access Control:

- IAM roles with least privilege.

3. Audit & Logging:

- CloudWatch logs + versioning.

4. Data Residency:

- Enforced region restriction.

5. System Hardening:

- Ansible playbooks apply CIS benchmarks.

## Tech Stack

- Terraform → Infra provisioning (AWS).

- Ansible → Config management + OS hardening.

- OPA / Sentinel → Policy-as-Code checks.

- Checkov / Terraform Compliance → Security scanning + compliance reports.

- GitHub Actions → CI/CD pipeline.

## How to Run the Demo

1. Clone Repo

```
git clone https://github.com/yourusername/bnm-iac-compliance-demo.git
cd bnm-iac-compliance-demo
```

2. Initialize Terraform

```
cd terraform
terraform init
terraform plan
```

3. Run Compliance Checks

```
checkov -d .
opa eval --input plan.json --data policies "data.terraform.aws.region"
```

4. Apply Configuration

```
terraform apply
ansible-playbook ansible/playbooks/harden.yml -i inventory
```

5. View Reports

```
compliance/reports/compliance_report.html

``` 


6. Demo Scenario

Case 1: Non-Compliant Deployment

- Region set to us-east-1 → blocked by OPA policy.

Case 2: Fix & Redeploy

- Change to ap-southeast-1 → passes policy → infra deployed.

Case 3: Compliance Report

- Show generated HTML/PDF audit report for auditors.


## Real-World Relevance

- Simulates BNM RMiT compliance automation used in Malaysian banks & fintechs.

- Reduces human error and audit overhead.



## Next Steps (Future Enhancements)

1. Add multi-cloud support (Azure, GCP).

2. Integrate Vault for secrets management.

3. Deploy Kubernetes with CIS hardening.

4. Build a Grafana dashboard for real-time compliance metrics.