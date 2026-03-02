# Networking

> **Purpose**: Fargate networking -- awsvpc mode, ENI, security groups, Service Connect, Cloud Map
> **Confidence**: 0.95
> **MCP Validated**: 2026-03-01

## Overview

AWS Fargate exclusively uses `awsvpc` network mode. Each task receives its own Elastic Network Interface (ENI) with a private IPv4 address in your VPC. This means tasks behave like EC2 instances from a networking perspective -- each gets its own security group and can be placed in specific subnets.

## The Pattern

```json
{
  "networkConfiguration": {
    "awsvpcConfiguration": {
      "subnets": ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"],
      "securityGroups": ["sg-0123456789abcdef0"],
      "assignPublicIp": "DISABLED"
    }
  }
}
```

## Quick Reference

| Component | Limit | Notes |
|-----------|-------|-------|
| Subnets per service | 16 | Spread across AZs for HA |
| Security groups per task | 5 | Applied to the task ENI |
| ENIs per task | 1 | Each task gets exactly one ENI |
| Public IP | Optional | Only in public subnets; use NAT GW for private |

## Network Architecture

```
Internet
    |
[ALB / NLB]  (public subnets)
    |
[Fargate Tasks]  (private subnets)
    |--- ENI (private IP + security group)
    |--- NAT Gateway (for outbound internet: ECR pull, API calls)
    |
[RDS / ElastiCache]  (private subnets, separate security groups)
```

## Security Group Configuration

```hcl
# Terraform: ALB security group
resource "aws_security_group" "alb" {
  name_prefix = "alb-"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Terraform: Fargate task security group
resource "aws_security_group" "fargate_task" {
  name_prefix = "fargate-task-"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

## Service Connect

Service Connect provides built-in service mesh for ECS services, using Cloud Map namespaces for DNS-based discovery with short names:

```json
{
  "serviceConnectConfiguration": {
    "enabled": true,
    "namespace": "my-app.local",
    "services": [
      {
        "portName": "http",
        "discoveryName": "api-service",
        "clientAliases": [
          { "port": 8080, "dnsName": "api" }
        ]
      }
    ]
  }
}
```

Other services in the same namespace can reach this service at `http://api:8080`.

## Private Subnet Requirements

Tasks in private subnets need outbound internet for ECR pulls, CloudWatch Logs, and Secrets Manager. Use NAT Gateway or VPC endpoints:

| Service | VPC Endpoint Type | Avoids NAT |
|---------|-------------------|------------|
| ECR (API) | Interface | Yes |
| ECR (Docker) | Interface | Yes |
| S3 (layers) | Gateway | Yes |
| CloudWatch Logs | Interface | Yes |
| Secrets Manager | Interface | Yes |
| SSM Parameter Store | Interface | Yes |

## Common Mistakes

### Wrong

```json
{
  "assignPublicIp": "ENABLED",
  "securityGroups": []
}
```

### Correct

```json
{
  "assignPublicIp": "DISABLED",
  "subnets": ["subnet-private-a", "subnet-private-b"],
  "securityGroups": ["sg-restricted"]
}
```

Place tasks in private subnets with a NAT Gateway or VPC endpoints. Always attach a security group.

## Related

- [task-definitions](task-definitions.md), [ecs-vs-eks](ecs-vs-eks.md)
- [../patterns/service-deployment](../patterns/service-deployment.md)
- [IAM KB](../../iam/), [CloudWatch KB](../../cloudwatch/)
