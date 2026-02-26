# AWS KMS Quick Reference

## Key Types

| Type | Structure | Use Case | Direct Encrypt Limit |
|------|-----------|----------|---------------------|
| Symmetric (AES-256-GCM) | Single key | Encrypt/decrypt, envelope encryption | 4 KB |
| Asymmetric RSA | Public + private | Encrypt/decrypt or sign/verify | Varies by key size |
| Asymmetric ECC | Public + private | Sign/verify only | N/A |
| Asymmetric ML-DSA | Public + private | Post-quantum sign/verify (FIPS 204) | N/A |
| HMAC | Shared secret | Generate/verify MAC tags | N/A |

## Key Ownership

| Category | Created By | Managed By | Cost | Rotation | Example |
|----------|-----------|------------|------|----------|---------|
| AWS-owned | AWS | AWS | Free | Automatic | S3 SSE-S3 default key |
| AWS-managed | AWS | AWS | Free (per use) | Auto yearly | `aws/s3`, `aws/ebs`, `aws/rds` |
| Customer-managed | You | You | $1/mo + usage | Configurable | Your custom keys |

## Common CLI Commands

| Command | Description |
|---------|-------------|
| `aws kms create-key --description "My key"` | Create symmetric key |
| `aws kms create-alias --alias-name alias/my-key --target-key-id KEY_ID` | Create alias |
| `aws kms enable-key-rotation --key-id KEY_ID` | Enable auto rotation |
| `aws kms encrypt --key-id KEY_ID --plaintext fileb://data.txt` | Encrypt (< 4 KB) |
| `aws kms decrypt --ciphertext-blob fileb://encrypted.bin` | Decrypt |
| `aws kms generate-data-key --key-id KEY_ID --key-spec AES_256` | Generate data key |
| `aws kms list-keys` | List all keys |
| `aws kms describe-key --key-id KEY_ID` | Key metadata |
| `aws kms list-aliases` | List all aliases |
| `aws kms schedule-key-deletion --key-id KEY_ID --pending-window-in-days 7` | Schedule deletion |
| `aws kms get-key-policy --key-id KEY_ID --policy-name default` | View key policy |

## Key Policy Template

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EnableRootAccountAccess",
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::ACCOUNT_ID:root" },
      "Action": "kms:*",
      "Resource": "*"
    },
    {
      "Sid": "AllowKeyAdministration",
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::ACCOUNT_ID:role/Admin" },
      "Action": ["kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*",
                  "kms:Put*", "kms:Update*", "kms:Revoke*", "kms:Disable*",
                  "kms:Get*", "kms:Delete*", "kms:ScheduleKeyDeletion",
                  "kms:CancelKeyDeletion", "kms:TagResource", "kms:UntagResource"],
      "Resource": "*"
    },
    {
      "Sid": "AllowKeyUsage",
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::ACCOUNT_ID:role/AppRole" },
      "Action": ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*",
                  "kms:GenerateDataKey*", "kms:DescribeKey"],
      "Resource": "*"
    }
  ]
}
```

## Envelope Encryption Flow

```
1. Call kms:GenerateDataKey → get plaintext + encrypted data key
2. Encrypt data locally with plaintext data key
3. Store encrypted data key alongside encrypted data
4. Discard plaintext data key from memory
5. To decrypt: call kms:Decrypt on encrypted data key → get plaintext key
6. Decrypt data locally with plaintext key
```

## ARN Format

```
arn:aws:kms:REGION:ACCOUNT_ID:key/KEY_ID
arn:aws:kms:REGION:ACCOUNT_ID:alias/ALIAS_NAME
```

## Pricing (Approximate)

| Item | Cost |
|------|------|
| Customer-managed key | $1/month |
| API requests | $0.03 per 10,000 |
| Asymmetric RSA requests | $0.15 per 10,000 |
| Auto key rotation | Free (included) |
| AWS-managed keys | Free (per-use charges only) |
