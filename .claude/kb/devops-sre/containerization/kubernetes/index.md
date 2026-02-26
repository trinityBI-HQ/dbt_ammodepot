# Kubernetes Knowledge Base

> **Purpose**: Container orchestration platform for deploying, scaling, and managing containerized applications
> **MCP Validated**: 2026-02-19

## Quick Navigation

### Concepts (< 150 lines each)

| File | Purpose |
|------|---------|
| [concepts/architecture.md](concepts/architecture.md) | Control plane, worker nodes, cluster components |
| [concepts/workloads.md](concepts/workloads.md) | Pods, Deployments, StatefulSets, DaemonSets, Jobs |
| [concepts/networking.md](concepts/networking.md) | Services, Ingress, DNS, NetworkPolicies |
| [concepts/storage.md](concepts/storage.md) | Volumes, PersistentVolumes, StorageClasses |
| [concepts/configuration.md](concepts/configuration.md) | ConfigMaps, Secrets, ResourceQuotas |
| [concepts/security.md](concepts/security.md) | RBAC, ServiceAccounts, PodSecurityStandards |

### Patterns (< 200 lines each)

| File | Purpose |
|------|---------|
| [patterns/deployment-strategies.md](patterns/deployment-strategies.md) | Rolling updates, blue-green, canary deployments |
| [patterns/scaling-autoscaling.md](patterns/scaling-autoscaling.md) | HPA, VPA, Cluster Autoscaler, KEDA |
| [patterns/helm-kustomize.md](patterns/helm-kustomize.md) | Package management with Helm and Kustomize |
| [patterns/production-best-practices.md](patterns/production-best-practices.md) | Resource limits, PDBs, probes, affinity |

---

## Quick Reference

- [quick-reference.md](quick-reference.md) - kubectl commands and manifest cheat sheet

---

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Pod** | Smallest deployable unit; one or more containers sharing network/storage |
| **Deployment** | Declarative updates for Pods and ReplicaSets with rolling updates |
| **Service** | Stable network endpoint for accessing a set of Pods |
| **Ingress** | HTTP/HTTPS routing from external traffic to Services |
| **ConfigMap/Secret** | Decouple configuration and sensitive data from container images |
| **RBAC** | Role-based access control for cluster security |
| **Namespace** | Virtual cluster for resource isolation and multi-tenancy |
| **In-Place Pod Resizing** | Resize CPU/memory without restarting pods (GA in v1.35) |
| **DRA** | Dynamic Resource Allocation for GPUs/accelerators (v1.34+) |

**Version Notes (v1.33-1.35):**
- **v1.35 "Timbernetes" (Dec 2025)**: In-Place Pod Resizing GA, Workload-Aware Scheduling Alpha
- **v1.34 "Of Wind & Will" (Aug 2025)**: DRA matured for GPU/accelerator management
- **v1.33 "Octarine" (Apr 2025)**: `Endpoints` API deprecated (use `EndpointSlices`), `--subresource` flag stable
- **v1.32 EOL**: February 28, 2026

---

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/architecture.md, concepts/workloads.md |
| **Intermediate** | concepts/networking.md, concepts/storage.md, concepts/configuration.md |
| **Advanced** | concepts/security.md, patterns/production-best-practices.md, patterns/scaling-autoscaling.md |

---

## Agent Usage

| Agent | Primary Files | Use Case |
|-------|---------------|----------|
| ci-cd-specialist | patterns/deployment-strategies.md | CI/CD with Kubernetes |
| infra-deployer | patterns/helm-kustomize.md | Infrastructure deployment |
| spark-specialist | patterns/scaling-autoscaling.md | Spark on Kubernetes |
