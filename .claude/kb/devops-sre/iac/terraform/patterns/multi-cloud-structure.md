# Multi-Cloud Project Structure

> **Purpose**: Organize Terraform projects that span GCP and AWS
> **MCP Validated**: 2026-02-19

## Directory Layout

```text
infrastructure/
├── modules/                    # Reusable modules by provider
│   ├── gcp/
│   │   ├── cloud-run-service/
│   │   ├── gcs-bucket/
│   │   ├── pubsub-topic/
│   │   └── bigquery-dataset/
│   └── aws/
│       ├── s3-bucket/
│       ├── lambda-function/
│       └── iam-role/
├── environments/               # Per-environment configs
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   ├── staging/
│   └── prod/
├── shared/                     # Shared resources (state buckets, OIDC)
│   ├── main.tf
│   └── backend.tf
└── tests/                      # Module tests
    ├── s3_bucket.tftest.hcl
    └── lambda.tftest.hcl
```

## Alternative: Stacks by Cloud Provider

For teams that manage each cloud separately:

```text
infrastructure/
├── gcp/
│   ├── modules/
│   ├── dev/
│   ├── staging/
│   └── prod/
├── aws/
│   ├── modules/
│   ├── dev/
│   ├── staging/
│   └── prod/
└── shared/                     # Cross-cloud (DNS, monitoring)
```

## Root Module Example (Multi-Cloud)

```hcl
# environments/prod/main.tf
terraform {
  required_version = ">= 1.7.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = var.project_name
  }
}

# GCP resources
module "gcp_storage" {
  source = "../../modules/gcp/gcs-bucket"
  # ...
}

# AWS resources
module "aws_data_lake" {
  source = "../../modules/aws/s3-bucket"
  # ...
}
```

## Backend Strategy

### Separate State per Cloud

```hcl
# gcp/prod/backend.tf
terraform {
  backend "gcs" {
    bucket = "tf-state-myproject"
    prefix = "gcp/prod"
  }
}

# aws/prod/backend.tf
terraform {
  backend "s3" {
    bucket         = "tf-state-myproject"
    key            = "aws/prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tf-locks"
    encrypt        = true
  }
}
```

### Cross-Cloud State References

```hcl
# In AWS config, reference GCP outputs
data "terraform_remote_state" "gcp" {
  backend = "gcs"
  config = {
    bucket = "tf-state-myproject"
    prefix = "gcp/prod"
  }
}

resource "aws_ssm_parameter" "gcp_endpoint" {
  name  = "/config/gcp-api-endpoint"
  type  = "String"
  value = data.terraform_remote_state.gcp.outputs.api_url
}
```

## With Terragrunt

For DRY multi-environment management:

```text
infrastructure/
├── terragrunt.hcl              # Root config
├── modules/                    # Same as above
├── dev/
│   ├── env.hcl
│   ├── gcp/
│   │   └── storage/
│   │       └── terragrunt.hcl
│   └── aws/
│       └── data-lake/
│           └── terragrunt.hcl
├── staging/
└── prod/
```

```hcl
# dev/aws/data-lake/terragrunt.hcl
terraform {
  source = "../../../modules/aws/s3-bucket"
}

include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path = find_in_parent_folders("env.hcl")
}

inputs = {
  bucket_name = "myproject-dev-data-lake"
  environment = "dev"
}
```

## Decision Matrix

| Scenario | Approach |
|----------|----------|
| Same team manages both clouds | Unified directory, modules by provider |
| Separate teams per cloud | Separate stacks by provider |
| Many environments | Use Terragrunt for DRY |
| Cross-cloud dependencies | Use `terraform_remote_state` data source |
| Simple setup, few resources | Single root with both providers |

## State Isolation Best Practices

| Practice | Why |
|----------|-----|
| Separate state per environment | Blast radius containment |
| Separate state per cloud provider | Independent deploy cycles |
| Use cloud-native backend per stack | GCS for GCP, S3 for AWS |
| Enable state encryption | Protect sensitive outputs |
| Enable versioning on state bucket | Recover from state corruption |

## Related

- [Remote State](./remote-state.md) | [Providers](../concepts/providers.md) | [Terragrunt KB](../../terragrunt/)
