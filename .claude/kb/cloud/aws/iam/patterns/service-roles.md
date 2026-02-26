# Service Roles Pattern

> **Purpose**: Creating least-privilege roles for AWS services (Lambda, ECS, EC2, Glue)
> **MCP Validated**: 2026-02-19

## When to Use

- Any AWS service that acts on your behalf (Lambda, ECS, EC2, Glue, Step Functions)
- CI/CD pipelines deploying to AWS
- Data pipelines reading/writing across services
- Scheduled jobs and event-driven processing

## Lambda Execution Role

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CloudWatchLogs",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:us-east-1:123456789012:log-group:/aws/lambda/my-function:*"
    },
    {
      "Sid": "S3ReadSource",
      "Effect": "Allow",
      "Action": ["s3:GetObject"],
      "Resource": "arn:aws:s3:::source-bucket/input/*"
    },
    {
      "Sid": "S3WriteOutput",
      "Effect": "Allow",
      "Action": ["s3:PutObject"],
      "Resource": "arn:aws:s3:::output-bucket/results/*"
    },
    {
      "Sid": "DynamoDBAccess",
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem"
      ],
      "Resource": "arn:aws:dynamodb:us-east-1:123456789012:table/ProcessingState"
    }
  ]
}
```

Trust policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "lambda.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
```

## ECS Task Role

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "SecretsAccess",
      "Effect": "Allow",
      "Action": ["secretsmanager:GetSecretValue"],
      "Resource": "arn:aws:secretsmanager:us-east-1:123456789012:secret:app/db-*"
    },
    {
      "Sid": "SQSAccess",
      "Effect": "Allow",
      "Action": [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ],
      "Resource": "arn:aws:sqs:us-east-1:123456789012:processing-queue"
    }
  ]
}
```

Trust policy:

```json
{
  "Principal": { "Service": "ecs-tasks.amazonaws.com" },
  "Action": "sts:AssumeRole"
}
```

## Glue Job Role

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "GlueServiceActions",
      "Effect": "Allow",
      "Action": [
        "glue:GetTable",
        "glue:GetDatabase",
        "glue:GetPartitions"
      ],
      "Resource": [
        "arn:aws:glue:us-east-1:123456789012:catalog",
        "arn:aws:glue:us-east-1:123456789012:database/analytics",
        "arn:aws:glue:us-east-1:123456789012:table/analytics/*"
      ]
    },
    {
      "Sid": "S3DataLakeAccess",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::data-lake-prod",
        "arn:aws:s3:::data-lake-prod/*"
      ]
    },
    {
      "Sid": "CloudWatchLogs",
      "Effect": "Allow",
      "Action": ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
      "Resource": "arn:aws:logs:us-east-1:123456789012:log-group:/aws-glue/*"
    }
  ]
}
```

## Common Service Principals

| Service | Principal | Notes |
|---------|-----------|-------|
| Lambda | `lambda.amazonaws.com` | Execution role |
| ECS Tasks | `ecs-tasks.amazonaws.com` | Task role (not execution role) |
| EC2 | `ec2.amazonaws.com` | Requires instance profile |
| Glue | `glue.amazonaws.com` | ETL jobs, crawlers |
| Step Functions | `states.amazonaws.com` | State machine execution |
| EventBridge | `events.amazonaws.com` | Scheduled invocations |
| CodePipeline | `codepipeline.amazonaws.com` | CI/CD pipeline actions |
| S3 (replication) | `s3.amazonaws.com` | Cross-region replication |
| RDS | `rds.amazonaws.com` | Enhanced monitoring |

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `MaxSessionDuration` | 3600s | For cross-account; services manage their own |
| Instance profile | Required for EC2 | Container for EC2 role; 1:1 mapping |
| Task role vs execution role | Both needed for ECS | Task role = app perms; execution role = pull images, write logs |
| `SourceArn` condition | Recommended | Prevent confused deputy attacks |

## Confused Deputy Prevention

```json
{
  "Effect": "Allow",
  "Principal": { "Service": "lambda.amazonaws.com" },
  "Action": "sts:AssumeRole",
  "Condition": {
    "ArnLike": {
      "aws:SourceArn": "arn:aws:lambda:us-east-1:123456789012:function:my-*"
    },
    "StringEquals": {
      "aws:SourceAccount": "123456789012"
    }
  }
}
```

## See Also

- [Roles](../concepts/roles.md) -- trust policy mechanics
- [Least Privilege](least-privilege.md) -- scoping service permissions
- [Terraform IAM](terraform-iam.md) -- codifying service roles
