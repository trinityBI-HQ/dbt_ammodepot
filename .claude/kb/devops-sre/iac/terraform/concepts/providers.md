# Providers

> **Purpose**: Plugins that enable Terraform to interact with cloud APIs
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Providers are plugins that Terraform uses to create and manage resources. Each provider offers resource types and data sources for a specific platform. Configure providers in root modules only.

## Multi-Cloud Provider Configuration

### GCP + AWS Setup

```hcl
# versions.tf
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
```

## GCP Provider

```hcl
provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

provider "google-beta" {
  project = var.gcp_project_id
  region  = var.gcp_region
}
```

### GCP Authentication

| Method | Use Case | Configuration |
|--------|----------|---------------|
| Application Default Credentials | Local dev | `gcloud auth application-default login` |
| Service Account Key | CI/CD | `GOOGLE_CREDENTIALS` env var |
| Workload Identity | GKE, Cloud Run | Automatic via metadata |
| Impersonation | Cross-project | `impersonate_service_account` |

```hcl
# Impersonation (recommended for CI/CD)
provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
  impersonate_service_account = "terraform@${var.gcp_project_id}.iam.gserviceaccount.com"
}
```

## AWS Provider

```hcl
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "terraform"
      Project     = var.project_name
    }
  }
}
```

### AWS Authentication

| Method | Use Case | Configuration |
|--------|----------|---------------|
| Shared credentials | Local dev | `~/.aws/credentials` profile |
| Environment variables | CI/CD | `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY` |
| IAM Role (assume) | Cross-account | `assume_role` block |
| OIDC federation | GitHub Actions | `aws-actions/configure-aws-credentials` |

```hcl
# Cross-account assume role
provider "aws" {
  region = var.aws_region
  assume_role {
    role_arn     = "arn:aws:iam::${var.target_account_id}:role/TerraformRole"
    session_name = "terraform-deploy"
  }
}
```

### AWS Provider Aliases (Multi-Region)

```hcl
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

provider "aws" {
  alias  = "eu_west_1"
  region = "eu-west-1"
}

resource "aws_s3_bucket" "replica" {
  provider = aws.eu_west_1
  bucket   = "my-replica-bucket"
}
```

## Version Pinning

| Strategy | Example | Use Case |
|----------|---------|----------|
| Pessimistic | `~> 5.0` | Allow minor/patch updates |
| Exact | `= 5.82.0` | Maximum stability |
| Range | `>= 5.0, < 6.0` | Major version lock |

## Common Mistakes

| Wrong | Correct |
|-------|---------|
| Hardcoded credentials | Use env vars, OIDC, or IAM roles |
| Provider config in child modules | Configure only in root module |
| Unpinned provider versions | Pin with `~>` or `=` |

## OpenTofu `enabled` Meta-Argument (1.11)

OpenTofu 1.11 introduced the `enabled` meta-argument on provider blocks, allowing conditional provider configuration. This is **not available in Terraform** -- it is OpenTofu-specific:

```hcl
# OpenTofu only
provider "datadog" {
  enabled = var.enable_monitoring  # conditionally enable provider
}
```

## Related

- [State](./state.md) | [Remote State](../patterns/remote-state.md) | [Multi-Cloud Structure](../patterns/multi-cloud-structure.md)
