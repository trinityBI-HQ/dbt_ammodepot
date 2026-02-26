# Kubernetes Architecture

> **Purpose**: Cluster components — control plane, worker nodes, and addons
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Kubernetes is a distributed system with a control plane managing cluster state and worker nodes running application workloads. The control plane makes scheduling decisions while nodes execute container workloads via kubelet and container runtimes.

## Control Plane Components

```
┌─────────────────── Control Plane ───────────────────┐
│  kube-apiserver ←→ etcd                              │
│       ↕                                              │
│  kube-scheduler    kube-controller-manager           │
│                    cloud-controller-manager           │
└──────────────────────────────────────────────────────┘
         ↕ (kubelet communicates via API server)
┌─────────────────── Worker Node ─────────────────────┐
│  kubelet → container runtime (containerd/CRI-O)     │
│  kube-proxy (iptables/nftables rules)               │
│  [Pods] [Pods] [Pods]                               │
└──────────────────────────────────────────────────────┘
```

| Component | Role |
|-----------|------|
| **kube-apiserver** | REST API gateway; all components communicate through it |
| **etcd** | Distributed key-value store for all cluster state |
| **kube-scheduler** | Assigns Pods to nodes (filtering → scoring) |
| **kube-controller-manager** | Runs controllers (Deployment, ReplicaSet, Node, Job) |
| **cloud-controller-manager** | Integrates with cloud APIs (load balancers, nodes, routes) |

## Worker Node Components

| Component | Role |
|-----------|------|
| **kubelet** | Agent on each node; manages Pod lifecycle via CRI |
| **kube-proxy** | Maintains network rules for Service routing (iptables/nftables) |
| **Container Runtime** | Runs containers (containerd, CRI-O) |

## Key Addons

| Addon | Purpose |
|-------|---------|
| **CoreDNS** | Cluster DNS for service discovery (`svc.cluster.local`) |
| **CNI Plugin** | Pod networking (Calico, Cilium, Flannel) |
| **Metrics Server** | Resource usage metrics for HPA and `kubectl top` |
| **Ingress Controller** | HTTP routing (NGINX, Traefik, Envoy) |

## etcd Fault Tolerance

| Nodes | Tolerates Failures | Formula |
|-------|-------------------|---------|
| 3 | 1 | `(n-1)/2` |
| 5 | 2 | |
| 7 | 3 | |

Always run odd number of etcd members. 3 nodes for small clusters, 5 for production.

## Recent Architecture Enhancements (v1.33-1.35)

| Feature | Version | Impact |
|---------|---------|--------|
| Workload-Aware Scheduling (Alpha) | v1.35 | Scheduler considers AI/ML batch job requirements for better placement |
| Streaming LIST encoding | v1.33 | Improved API server performance for large resource lists |
| Extended Toleration Operators (Alpha) | v1.35 | `Gt`/`Lt` operators for tolerations enable numeric comparisons |

The kube-scheduler in v1.35 introduces alpha support for workload-aware scheduling, which optimizes placement for AI/ML batch jobs by considering gang scheduling and topology-aware allocation requirements.

## Common Mistakes

### Wrong

Exposing etcd directly or running single etcd instance in production.

### Correct

Run etcd as an HA cluster (3+ members), restrict access to API server only, enable TLS for all etcd communication, and back up etcd regularly with `etcdctl snapshot save`.

## Related

- [Networking](networking.md) — how Services and DNS work
- [Security](security.md) — RBAC and access control
- [Production Best Practices](../patterns/production-best-practices.md)
