# AWS Fargate Knowledge Base

> **Purpose**: Serverless compute engine for containers -- run ECS/EKS workloads without managing EC2 instances
> **MCP Validated**: 2026-03-01

## Quick Navigation

### Concepts (< 150 lines each)

| File | Purpose |
|------|---------|
| [concepts/task-definitions.md](concepts/task-definitions.md) | Task definitions, containers, CPU/memory, roles, logging |
| [concepts/networking.md](concepts/networking.md) | awsvpc mode, ENI, security groups, Service Connect, Cloud Map |
| [concepts/ecs-vs-eks.md](concepts/ecs-vs-eks.md) | Fargate with ECS vs EKS -- trade-offs and when to use each |
| [concepts/pricing-model.md](concepts/pricing-model.md) | vCPU/memory billing, Fargate Spot, Compute Savings Plans |

### Patterns (< 200 lines each)

| File | Purpose |
|------|---------|
| [patterns/service-deployment.md](patterns/service-deployment.md) | ECS service with ALB, blue/green and rolling deployments |
| [patterns/task-scheduling.md](patterns/task-scheduling.md) | Scheduled tasks with EventBridge, one-off task runs |
| [patterns/cicd-pipeline.md](patterns/cicd-pipeline.md) | CI/CD with GitHub Actions, ECR push, task definition updates |
| [patterns/auto-scaling.md](patterns/auto-scaling.md) | Target tracking, step scaling, custom metrics |

---

## Quick Reference

- [quick-reference.md](quick-reference.md) - Fast lookup tables

---

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Serverless Containers** | No EC2 instances to provision -- AWS manages the underlying infrastructure |
| **Task Definition** | Blueprint for containers: image, CPU, memory, ports, IAM roles, logging |
| **awsvpc Network Mode** | Each task gets its own ENI with a private IP and security group |
| **Per-Second Billing** | Pay for vCPU and memory from image pull to task termination |
| **Fargate Spot** | Up to 70% discount for fault-tolerant workloads with 2-minute interruption notice |
| **Platform Versions** | Fargate runtime versions (latest: 1.4.0 for Linux, 1.0.0 for Windows) |
| **Service Connect** | Service mesh for inter-service communication with short names |
| **Deployment Circuit Breaker** | Automatic rollback when new tasks fail health checks |

---

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/task-definitions.md, concepts/pricing-model.md |
| **Intermediate** | concepts/networking.md, patterns/service-deployment.md |
| **Advanced** | patterns/auto-scaling.md, patterns/cicd-pipeline.md |

---

## Agent Usage

| Agent | Primary Files | Use Case |
|-------|---------------|----------|
| aws-deployer | patterns/service-deployment.md, patterns/cicd-pipeline.md | Fargate service deployments |
| aws-lambda-architect | concepts/task-definitions.md | IAM roles for Fargate tasks |
| infra-deployer | patterns/service-deployment.md | Terraform Fargate infrastructure |
| ci-cd-specialist | patterns/cicd-pipeline.md | CI/CD pipeline setup |

---

## Cross-References

| Technology | KB Path | Relationship |
|------------|---------|--------------|
| IAM | `../iam/` | Task roles and execution roles |
| CloudWatch | `../cloudwatch/` | Container Insights, log groups |
| Secrets Manager | `../secrets-manager/` | Inject secrets into containers |
| Terraform | `../../../devops-sre/iac/terraform/` | Infrastructure as Code for Fargate |
| Docker | `../../../devops-sre/containerization/docker/` | Container image builds |
