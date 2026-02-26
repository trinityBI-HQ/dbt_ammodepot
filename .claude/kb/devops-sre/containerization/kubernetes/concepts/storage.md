# Kubernetes Storage

> **Purpose**: Volumes, PersistentVolumes, PersistentVolumeClaims, and StorageClasses
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Containers have ephemeral filesystems. Kubernetes provides Volumes for shared/persistent data. PersistentVolumes (PVs) and PersistentVolumeClaims (PVCs) decouple storage provisioning from consumption. StorageClasses enable dynamic provisioning.

## Volume Types (In-Pod)

```yaml
spec:
  containers:
  - name: app
    volumeMounts:
    - name: cache
      mountPath: /tmp/cache
    - name: config
      mountPath: /etc/config
  volumes:
  - name: cache
    emptyDir: {}              # Ephemeral, lives with Pod
  - name: config
    configMap:
      name: app-config        # Mount ConfigMap as files
```

| Volume Type | Lifetime | Use Case |
|-------------|----------|----------|
| `emptyDir` | Pod lifetime | Scratch space, caches |
| `configMap` | Pod lifetime | Configuration files |
| `secret` | Pod lifetime | Certificates, credentials |
| `hostPath` | Node lifetime | Node-level data (avoid in prod) |
| `persistentVolumeClaim` | Independent | Persistent data |

## PersistentVolume and PersistentVolumeClaim

```yaml
# StorageClass for dynamic provisioning
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: pd.csi.storage.gke.io    # Cloud-specific
parameters:
  type: pd-ssd
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
---
# PersistentVolumeClaim (requests storage)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: fast-ssd
  resources:
    requests:
      storage: 20Gi
---
# Pod using the PVC
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
  - name: app
    image: my-app:1.0
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: app-data
```

## Access Modes

| Mode | Abbreviation | Description |
|------|-------------|-------------|
| ReadWriteOnce | RWO | Single node read-write |
| ReadOnlyMany | ROX | Multiple nodes read-only |
| ReadWriteMany | RWX | Multiple nodes read-write |
| ReadWriteOncePod | RWOP | Single pod read-write (1.29+) |

## Reclaim Policies

| Policy | Behavior |
|--------|----------|
| **Delete** | PV and backing storage deleted when PVC deleted (default for dynamic) |
| **Retain** | PV kept after PVC deleted; manual cleanup required |

## Volume Binding Modes

| Mode | When Binding Happens |
|------|---------------------|
| `Immediate` | PV bound as soon as PVC created |
| `WaitForFirstConsumer` | PV bound when Pod using PVC is scheduled (preferred) |

`WaitForFirstConsumer` ensures storage is provisioned in the same zone as the Pod.

## Common Mistakes

### Wrong

Using `hostPath` for persistent data in production.

### Correct

Use PVCs with a StorageClass for dynamic provisioning. Use `WaitForFirstConsumer` binding mode for zone-aware provisioning.

## Related

- [Workloads](workloads.md) — StatefulSet volumeClaimTemplates
- [Configuration](configuration.md) — ConfigMap and Secret volumes
- [Production Best Practices](../patterns/production-best-practices.md)
