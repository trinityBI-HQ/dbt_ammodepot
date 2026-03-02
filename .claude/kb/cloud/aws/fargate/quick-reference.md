# AWS Fargate Quick Reference

> Fast lookup tables. For code examples, see linked files.

## Valid CPU/Memory Combinations

| vCPU | Memory Options (GB) | Use Case |
|------|---------------------|----------|
| 0.25 | 0.5, 1, 2 | Lightweight sidecars, small APIs |
| 0.5 | 1, 2, 3, 4 | Standard web services |
| 1 | 2, 3, 4, 5, 6, 7, 8 | General-purpose workloads |
| 2 | 4-16 (1 GB increments) | Medium compute, batch jobs |
| 4 | 8-30 (1 GB increments) | Data processing, ML inference |
| 8 | 16-60 (4 GB increments) | Heavy compute, large models |
| 16 | 32-120 (8 GB increments) | Memory-intensive workloads |

## Core AWS CLI Commands

| Command | Purpose |
|---------|---------|
| `aws ecs register-task-definition --cli-input-json file://task-def.json` | Register task definition |
| `aws ecs create-service --cluster my-cluster --service-name my-svc ...` | Create ECS service |
| `aws ecs update-service --cluster my-cluster --service my-svc --force-new-deployment` | Force redeployment |
| `aws ecs run-task --cluster my-cluster --task-definition my-task` | Run one-off task |
| `aws ecs describe-tasks --cluster my-cluster --tasks <task-id>` | Inspect running task |
| `aws ecs stop-task --cluster my-cluster --task <task-id>` | Stop a task |
| `aws logs tail /ecs/my-service --follow` | Stream container logs |

## IAM Roles

| Role | Purpose | Attach To |
|------|---------|-----------|
| Task Execution Role | Pull images from ECR, push logs to CloudWatch, read secrets | `executionRoleArn` |
| Task Role | Application-level AWS API access (S3, DynamoDB, SQS, etc.) | `taskRoleArn` |

## Decision Matrix

| Use Case | Choose |
|----------|--------|
| Simple containerized API | ECS + Fargate + ALB |
| Kubernetes required (portability/ecosystem) | EKS + Fargate |
| Batch/scheduled jobs | ECS + Fargate + EventBridge |
| Cost-sensitive steady workloads | ECS + EC2 (not Fargate) |
| Fault-tolerant batch processing | Fargate Spot |
| Predictable long-running services | Compute Savings Plans |
| GPU workloads | ECS + EC2 (Fargate GPU limited) |
| < 15 min short tasks | Lambda (if < 10 GB memory) |

## Pricing (US East, On-Demand, Linux/x86)

| Resource | Per-Second Rate | Per-Hour Rate |
|----------|-----------------|---------------|
| vCPU | $0.000011244 | $0.04048 |
| Memory (GB) | $0.000001235 | $0.004445 |
| Ephemeral Storage (>20 GB) | $0.000001244/GB | $0.000111/GB/hr |

## Common Pitfalls

| Don't | Do |
|-------|-----|
| Use task execution role for app permissions | Use separate task role for app AWS access |
| Hard-code secrets in task definitions | Use Secrets Manager / Parameter Store references |
| Skip health checks on ALB targets | Configure container health checks + ALB target health |
| Ignore ephemeral storage limits (default 20 GB) | Configure up to 200 GB when needed |
| Run long steady workloads on-demand | Use Compute Savings Plans (up to 50% off) |
| Overlook awsvpc ENI limits per subnet | Size subnets for peak task count (1 ENI per task) |

## Platform Versions

| OS | Latest Version | Key Feature |
|----|---------------|-------------|
| Linux | 1.4.0 | EFS, ephemeral storage, container dependencies |
| Windows | 1.0.0 | Windows Server 2019/2022, gMSA support |

## Related Documentation

| Topic | Path |
|-------|------|
| Task Definitions | `concepts/task-definitions.md` |
| Networking | `concepts/networking.md` |
| Service Deployment | `patterns/service-deployment.md` |
| Full Index | `index.md` |
