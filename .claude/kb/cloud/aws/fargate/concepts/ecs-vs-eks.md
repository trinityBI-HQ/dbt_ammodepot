# ECS vs EKS on Fargate

> **Purpose**: When to use ECS vs EKS as the Fargate orchestrator -- trade-offs and decision criteria
> **Confidence**: 0.95
> **MCP Validated**: 2026-03-01

## Overview

AWS Fargate is a compute engine, not an orchestrator. It runs under either Amazon ECS (AWS-native) or Amazon EKS (Kubernetes). The choice depends on your team's Kubernetes expertise, portability requirements, and operational complexity tolerance. ECS is simpler and cheaper; EKS provides Kubernetes ecosystem access and multi-cloud portability.

## The Pattern

```text
+------------------+          +------------------+
|   Amazon ECS     |          |   Amazon EKS     |
|   (AWS-native)   |          |   (Kubernetes)   |
+--------+---------+          +--------+---------+
         |                             |
         v                             v
+--------------------------------------------------+
|              AWS Fargate (Compute)                |
|  Serverless containers -- no EC2 management       |
+--------------------------------------------------+
```

## Quick Reference

| Dimension | ECS + Fargate | EKS + Fargate |
|-----------|---------------|---------------|
| **Learning curve** | Low (AWS-native concepts) | High (Kubernetes knowledge required) |
| **Control plane cost** | Free | $0.10/hr per cluster ($73/mo) |
| **Task definition format** | ECS JSON | Kubernetes Pod spec (YAML) |
| **Service mesh** | Service Connect (built-in) | App Mesh, Istio, Linkerd |
| **Auto-scaling** | Application Auto Scaling | Kubernetes HPA + Karpenter |
| **CI/CD** | CodePipeline, GitHub Actions | ArgoCD, Flux, GitHub Actions |
| **IAM integration** | Native (task role, execution role) | IRSA (IAM Roles for Service Accounts) |
| **Logging** | awslogs driver (native) | Fluent Bit DaemonSet |
| **Multi-cloud** | AWS only | Portable (with caveats) |
| **Namespace isolation** | Clusters + services | Kubernetes namespaces |
| **Community ecosystem** | AWS-specific tooling | Helm charts, operators, CNCF tools |

## Decision Matrix

| Choose ECS + Fargate When | Choose EKS + Fargate When |
|---------------------------|---------------------------|
| Team is AWS-focused, no K8s experience | Team already uses Kubernetes |
| Simple microservices or batch jobs | Complex service mesh requirements |
| Cost sensitivity (no control plane fee) | Multi-cloud or hybrid strategy |
| Faster time-to-production needed | Need Helm, operators, CRDs |
| < 20 services | Large-scale platform (50+ services) |
| AWS-native CI/CD (CodePipeline) | GitOps workflows (ArgoCD, Flux) |
| Scheduled tasks (EventBridge native) | CronJobs (Kubernetes native) |

## ECS Advantages

1. **No control plane fee** -- ECS is free; you only pay for Fargate compute
2. **Simpler mental model** -- tasks, services, clusters (vs pods, deployments, services, ingress)
3. **Native AWS integration** -- Service Connect, CloudWatch Container Insights, CodeDeploy blue/green
4. **Faster onboarding** -- Smaller API surface, less YAML boilerplate
5. **ECS-native blue/green** -- Built-in (July 2025), no CodeDeploy dependency needed

## EKS Advantages

1. **Portability** -- Standard Kubernetes manifests work across clouds and on-premises
2. **Ecosystem** -- Thousands of Helm charts, operators, and CNCF tools
3. **Advanced networking** -- Istio, Calico network policies, service mesh flexibility
4. **Namespace isolation** -- Multi-tenant workloads with RBAC and quotas
5. **Karpenter** -- Sophisticated node provisioning (though less relevant for Fargate-only)

## Migration Paths

### ECS to EKS

1. Containerize workloads (already done if on Fargate)
2. Translate ECS task definitions to Kubernetes Deployments/Pods
3. Replace ALB target groups with Kubernetes Ingress (AWS Load Balancer Controller)
4. Replace Service Connect with Kubernetes Services
5. Migrate IAM task roles to IRSA

### EKS to ECS

1. Translate Kubernetes manifests to ECS task definitions
2. Replace Kubernetes Services with ECS Service Connect or Cloud Map
3. Replace Ingress with ALB target groups
4. Replace IRSA with ECS task roles
5. Replace Helm/ArgoCD with CodePipeline or GitHub Actions

## Cost Comparison (Monthly, 10 Services)

| Component | ECS + Fargate | EKS + Fargate |
|-----------|---------------|---------------|
| Control plane | $0 | $73 |
| Fargate compute | Same | Same |
| Load balancer | Same | Same |
| **Overhead delta** | **$0** | **+$73/mo** |

For large-scale deployments, the EKS control plane cost becomes negligible relative to compute costs.

## Common Mistakes

### Wrong

Choosing EKS solely because "Kubernetes is the industry standard" without Kubernetes expertise on the team.

### Correct

Start with ECS + Fargate for simplicity. Migrate to EKS only when you genuinely need Kubernetes features (portability, ecosystem, advanced networking).

## Related

- [task-definitions](task-definitions.md)
- [networking](networking.md)
- [pricing-model](pricing-model.md)
- [../patterns/service-deployment](../patterns/service-deployment.md)
