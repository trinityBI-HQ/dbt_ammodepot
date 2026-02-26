# Static Website Hosting

> **Purpose**: Host static websites on S3 with CloudFront CDN
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

S3 static website hosting serves HTML/CSS/JS directly from a bucket. For production, always front with CloudFront for HTTPS, caching, and global edge delivery. Keep the bucket private — CloudFront accesses it via Origin Access Control (OAC).

## Architecture

```
User → CloudFront (HTTPS, edge cache) → Private S3 Bucket
```

## Terraform Implementation

### S3 Bucket (Private)

```hcl
resource "aws_s3_bucket" "website" {
  bucket = "my-website-${var.environment}"
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket                  = aws_s3_bucket.website.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document { suffix = "index.html" }
  error_document { key    = "error.html" }
}
```

### CloudFront Distribution with OAC

```hcl
resource "aws_cloudfront_origin_access_control" "website" {
  name                              = "website-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "website" {
  origin {
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id                = "S3-website"
    origin_access_control_id = aws_cloudfront_origin_access_control.website.id
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-website"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    acm_certificate_arn      = var.certificate_arn  # Must be in us-east-1
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}
```

### Bucket Policy (Allow CloudFront Only)

```hcl
resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudFrontServicePrincipal"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.website.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.website.arn
        }
      }
    }]
  })
}
```

## Deploy Files with AWS CLI

```bash
# Sync website files to S3
aws s3 sync ./dist s3://my-website-prod --delete

# Invalidate CloudFront cache after deploy
aws cloudfront create-invalidation \
  --distribution-id E1234ABCDEF \
  --paths "/*"
```

## Deploy Files with boto3

```python
import boto3
import mimetypes

s3 = boto3.client("s3")

def upload_website(local_dir: str, bucket: str) -> None:
    for path in Path(local_dir).rglob("*"):
        if path.is_file():
            content_type, _ = mimetypes.guess_type(str(path))
            s3.upload_file(
                str(path),
                bucket,
                str(path.relative_to(local_dir)),
                ExtraArgs={"ContentType": content_type or "binary/octet-stream"},
            )
```

## SPA Routing (React/Vue/Angular)

For single-page apps, configure CloudFront to handle 403/404 errors:

```hcl
custom_error_response {
  error_code         = 403
  response_code      = 200
  response_page_path = "/index.html"
}

custom_error_response {
  error_code         = 404
  response_code      = 200
  response_page_path = "/index.html"
}
```

## Security Checklist

| Setting | Status |
|---------|--------|
| Block Public Access enabled | Required |
| CloudFront OAC (not OAI) | Use OAC (modern) |
| HTTPS enforced via viewer_protocol_policy | `redirect-to-https` |
| ACM certificate in us-east-1 | Required for CloudFront |
| S3 bucket policy scoped to CloudFront ARN | Least privilege |

## Cost Optimization

| Tactic | Savings |
|--------|---------|
| Set long cache TTLs for static assets | Reduces S3 GET requests |
| Use CloudFront price class 100 (NA + EU only) | Lower CDN cost |
| Enable Gzip/Brotli compression in CloudFront | Smaller transfers |
| Use `aws s3 sync --delete` | Remove stale files |

## Common Mistakes

- Making the S3 bucket public (use CloudFront OAC instead)
- Using OAI instead of OAC (OAI is legacy)
- Forgetting cache invalidation after deploys
- Not setting correct Content-Type on uploaded files
- ACM certificate not in us-east-1 (CloudFront requirement)

## Related

- [../concepts/security-access](../concepts/security-access.md)
- [../concepts/buckets-objects](../concepts/buckets-objects.md)
- [Terraform KB](../../../../devops-sre/iac/terraform/)
