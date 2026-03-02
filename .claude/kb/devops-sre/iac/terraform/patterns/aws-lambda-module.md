# AWS Lambda Function Module

> **Purpose**: Reusable Lambda function with IAM role, CloudWatch logs, and event source triggers
> **MCP Validated**: 2026-02-19
> **Provider**: hashicorp/aws ~> 5.0

## Module Structure

```text
modules/aws-lambda/
├── main.tf
├── variables.tf
├── outputs.tf
└── versions.tf
```

## variables.tf

```hcl
variable "function_name" {
  description = "Lambda function name"
  type        = string
}

variable "description" {
  description = "Function description"
  type        = string
  default     = ""
}

variable "runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "python3.12"
}

variable "handler" {
  description = "Function handler"
  type        = string
  default     = "handler.lambda_handler"
}

variable "source_path" {
  description = "Path to deployment package (zip)"
  type        = string
}

variable "memory_size" {
  description = "Memory in MB"
  type        = number
  default     = 256
}

variable "timeout" {
  description = "Timeout in seconds"
  type        = number
  default     = 30
}

variable "environment_variables" {
  description = "Environment variables"
  type        = map(string)
  default     = {}
}

variable "s3_trigger" {
  description = "S3 bucket to trigger from (null to disable)"
  type = object({
    bucket_arn    = string
    bucket_id     = string
    events        = optional(list(string), ["s3:ObjectCreated:*"])
    filter_prefix = optional(string, "")
    filter_suffix = optional(string, "")
  })
  default = null
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
```

## main.tf

```hcl
# --- IAM Role ---
resource "aws_iam_role" "this" {
  name = "${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# --- Lambda Function ---
resource "aws_lambda_function" "this" {
  function_name = var.function_name
  description   = var.description
  role          = aws_iam_role.this.arn
  handler       = var.handler
  runtime       = var.runtime
  memory_size   = var.memory_size
  timeout       = var.timeout
  filename      = var.source_path

  source_code_hash = filebase64sha256(var.source_path)

  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? [1] : []
    content {
      variables = var.environment_variables
    }
  }

  tags = var.tags
}

# --- CloudWatch Log Group ---
resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 14
  tags              = var.tags
}

# --- S3 Trigger (Optional) ---
resource "aws_lambda_permission" "s3" {
  count         = var.s3_trigger != null ? 1 : 0
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.s3_trigger.bucket_arn
}

resource "aws_s3_bucket_notification" "trigger" {
  count  = var.s3_trigger != null ? 1 : 0
  bucket = var.s3_trigger.bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.this.arn
    events              = var.s3_trigger.events
    filter_prefix       = var.s3_trigger.filter_prefix
    filter_suffix       = var.s3_trigger.filter_suffix
  }

  depends_on = [aws_lambda_permission.s3]
}
```

## outputs.tf

```hcl
output "function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.this.function_name
}

output "function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.this.arn
}

output "invoke_arn" {
  description = "Lambda invoke ARN (for API Gateway)"
  value       = aws_lambda_function.this.invoke_arn
}

output "role_arn" {
  description = "IAM role ARN"
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "IAM role name (for attaching additional policies)"
  value       = aws_iam_role.this.name
}
```

## Related

- [AWS IAM Module](./aws-iam-module.md) | [AWS S3 Module](./aws-s3-module.md) | [Cloud Run Module](./cloud-run-module.md)
