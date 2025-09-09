# List of Enforcement

## 1. Data Enccryption
- S3 : Require Server Side Encryption (`AES256`) for every bucket. Block create/update if SSE missing.
- RDS : Require `storage_encrypted = true`. Block public access (stretch: require KMS CMK & rotation).

Reason = [RMiT requires FIs to evaluate and apply cryptographic controls and manage keys appropriately.](https://docs.aws.amazon.com/config/latest/developerguide/operational-best-practices-for-bnm-rmit.html)


## 2. 