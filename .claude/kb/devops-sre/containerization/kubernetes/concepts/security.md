# Kubernetes Security

> **Purpose**: RBAC, ServiceAccounts, PodSecurityStandards, and network security
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Kubernetes security spans authentication (who are you), authorization (what can you do via RBAC), admission control (is this request allowed), and runtime security (Pod security contexts, NetworkPolicies). Defense in depth requires all layers.

## RBAC (Role-Based Access Control)

```yaml
# Role — namespace-scoped permissions
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: production
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
---
# RoleBinding — grants Role to a subject
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: production
subjects:
- kind: ServiceAccount
  name: app-sa
  namespace: production
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
---
# ClusterRole — cluster-wide permissions
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-viewer
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch"]
```

| Resource | Scope | Use Case |
|----------|-------|----------|
| Role | Namespace | App-specific permissions |
| ClusterRole | Cluster-wide | Node access, CRDs, cross-namespace |
| RoleBinding | Namespace | Bind Role/ClusterRole in a namespace |
| ClusterRoleBinding | Cluster-wide | Bind ClusterRole globally |

## ServiceAccounts

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  namespace: production
automountServiceAccountToken: false   # Don't mount token unless needed
```

**Best practices**: Create dedicated ServiceAccounts per workload. Disable automatic token mounting. Use Workload Identity (GKE/EKS) for cloud API access instead of static credentials.

## Pod Security Standards

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/audit: restricted
```

| Level | Allows | Use Case |
|-------|--------|----------|
| **Privileged** | Everything | System-level workloads (CNI, storage) |
| **Baseline** | Sane defaults, no privilege escalation | General workloads |
| **Restricted** | Most secure, non-root, drop capabilities | Production apps |

## Security Context

```yaml
spec:
  securityContext:                # Pod-level
    runAsNonRoot: true
    fsGroup: 1000
  containers:
  - name: app
    securityContext:              # Container-level
      runAsUser: 1000
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
```

## Quick Reference

| Practice | Implementation |
|----------|---------------|
| Least privilege RBAC | Namespace-scoped Roles, specific verbs |
| No root containers | `runAsNonRoot: true`, `runAsUser: 1000` |
| Read-only filesystem | `readOnlyRootFilesystem: true` |
| Drop capabilities | `capabilities.drop: ["ALL"]` |
| Network segmentation | NetworkPolicies per namespace |
| Secret encryption | Enable encryption at rest, use external secret managers |
| Image security | Use signed images, scan for vulnerabilities |

## Related

- [Configuration](configuration.md) — Secrets management
- [Networking](networking.md) — NetworkPolicies
- [Production Best Practices](../patterns/production-best-practices.md)
