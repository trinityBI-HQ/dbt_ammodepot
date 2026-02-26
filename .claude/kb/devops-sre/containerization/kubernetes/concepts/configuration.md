# Kubernetes Configuration

> **Purpose**: ConfigMaps, Secrets, ResourceQuotas, and LimitRanges
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

ConfigMaps store non-sensitive configuration, Secrets store sensitive data (base64-encoded). Both can be consumed as environment variables or mounted as files. ResourceQuotas and LimitRanges enforce resource governance per namespace.

## ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  DATABASE_HOST: "postgres.default.svc.cluster.local"
  LOG_LEVEL: "info"
  # File-like key
  config.yaml: |
    server:
      port: 8080
      timeout: 30s
```

**Consuming in a Pod:**

```yaml
spec:
  containers:
  - name: app
    image: my-app:1.0
    envFrom:                          # All keys as env vars
    - configMapRef:
        name: app-config
    env:                              # Specific key
    - name: DB_HOST
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: DATABASE_HOST
    volumeMounts:                     # As mounted file
    - name: config-vol
      mountPath: /etc/config
  volumes:
  - name: config-vol
    configMap:
      name: app-config
      items:
      - key: config.yaml
        path: config.yaml
```

## Secrets

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
stringData:                           # Plain text (encoded on creation)
  username: admin
  password: s3cur3-p@ss
---
# TLS Secret
apiVersion: v1
kind: Secret
metadata:
  name: app-tls
type: kubernetes.io/tls
data:
  tls.crt: <base64-encoded-cert>
  tls.key: <base64-encoded-key>
```

| Secret Type | Use Case |
|-------------|----------|
| `Opaque` | Default; arbitrary key-value pairs |
| `kubernetes.io/tls` | TLS certificates for Ingress |
| `kubernetes.io/dockerconfigjson` | Private registry authentication |
| `kubernetes.io/basic-auth` | Username/password pairs |

**Security note**: Kubernetes Secrets are base64-encoded, not encrypted at rest by default. Enable encryption at rest or use external secret managers (External Secrets Operator, HashiCorp Vault, AWS Secrets Manager).

## ResourceQuota

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-quota
  namespace: team-a
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    pods: "50"
    persistentvolumeclaims: "10"
```

## LimitRange

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: team-a
spec:
  limits:
  - type: Container
    default:
      cpu: 500m
      memory: 256Mi
    defaultRequest:
      cpu: 100m
      memory: 128Mi
    max:
      cpu: "2"
      memory: 2Gi
```

Sets default requests/limits for containers that don't specify them, and enforces min/max boundaries.

## Quick Reference

| Resource | Purpose | Scope |
|----------|---------|-------|
| ConfigMap | Non-sensitive config | Namespace |
| Secret | Sensitive data | Namespace |
| ResourceQuota | Total resource caps | Namespace |
| LimitRange | Per-container defaults/bounds | Namespace |

## Related

- [Security](security.md) — RBAC for Secret access
- [Workloads](workloads.md) — Using config in Pods
- [Storage](storage.md) — ConfigMap/Secret as volumes
