# Task Definitions

> **Purpose**: Blueprint for Fargate containers -- images, resources, roles, logging, and secrets
> **Confidence**: 0.95
> **MCP Validated**: 2026-03-01

## Overview

A task definition is a JSON document that describes one or more containers forming your application. It specifies the Docker image, CPU/memory allocation, port mappings, IAM roles, logging configuration, and environment variables. Fargate requires `requiresCompatibilities: ["FARGATE"]` and `networkMode: "awsvpc"`.

## The Pattern

```json
{
  "family": "my-api",
  "requiresCompatibilities": ["FARGATE"],
  "networkMode": "awsvpc",
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "arn:aws:iam::123456789012:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::123456789012:role/myAppTaskRole",
  "containerDefinitions": [
    {
      "name": "api",
      "image": "123456789012.dkr.ecr.us-east-1.amazonaws.com/my-api:latest",
      "portMappings": [{ "containerPort": 8080, "protocol": "tcp" }],
      "essential": true,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/my-api",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "api"
        }
      },
      "secrets": [
        {
          "name": "DB_PASSWORD",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:123456789012:secret:db-password"
        }
      ],
      "environment": [
        { "name": "APP_ENV", "value": "production" }
      ],
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
```

## Quick Reference

| Field | Required | Description |
|-------|----------|-------------|
| `family` | Yes | Logical name; new revisions share the same family |
| `cpu` | Yes | Task-level vCPU (string: "256", "512", "1024", etc.) |
| `memory` | Yes | Task-level memory in MiB (string: "512", "1024", etc.) |
| `networkMode` | Yes | Must be `"awsvpc"` for Fargate |
| `executionRoleArn` | Yes | Role for ECS agent: pull images, push logs, read secrets |
| `taskRoleArn` | No | Role for application code: access S3, DynamoDB, etc. |
| `containerDefinitions` | Yes | Array of container specs (at least one `essential: true`) |

## Execution Role vs Task Role

| | Execution Role | Task Role |
|---|---|---|
| **Used by** | ECS agent (infrastructure) | Application code |
| **Typical policies** | ECR pull, CloudWatch Logs, Secrets Manager read | S3, DynamoDB, SQS, SNS, custom |
| **Required** | Yes (for Fargate) | No (only if app calls AWS APIs) |
| **Field** | `executionRoleArn` | `taskRoleArn` |

## Secrets Injection

```json
{
  "secrets": [
    {
      "name": "DB_PASSWORD",
      "valueFrom": "arn:aws:secretsmanager:us-east-1:123456789012:secret:my-secret:password::"
    },
    {
      "name": "API_KEY",
      "valueFrom": "arn:aws:ssm:us-east-1:123456789012:parameter/prod/api-key"
    }
  ]
}
```

Secrets Manager and SSM Parameter Store values are injected as environment variables at task start. The execution role must have `secretsmanager:GetSecretValue` or `ssm:GetParameters` permissions.

## Ephemeral Storage

Fargate tasks get 20 GB ephemeral storage by default (expandable to 200 GB):

```json
{
  "ephemeralStorage": {
    "sizeInGiB": 100
  }
}
```

Storage beyond 20 GB incurs additional per-GB charges.

## Common Mistakes

### Wrong

```json
{
  "networkMode": "bridge",
  "cpu": "512"
}
```

### Correct

```json
{
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024"
}
```

Fargate only supports `awsvpc` network mode. CPU and memory must be valid combinations (see `quick-reference.md`).

## Multi-Container Tasks

A task can run multiple containers (sidecar pattern). Only one must be `essential: true` -- if it exits, the entire task stops. Common sidecars: log routers (Fluent Bit), reverse proxies (Envoy), monitoring agents.

## Related

- [networking](networking.md)
- [pricing-model](pricing-model.md)
- [../patterns/service-deployment](../patterns/service-deployment.md)
- [IAM KB](../../iam/)
- [Secrets Manager KB](../../secrets-manager/)
