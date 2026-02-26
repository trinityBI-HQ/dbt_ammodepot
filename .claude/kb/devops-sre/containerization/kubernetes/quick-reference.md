# Kubernetes Quick Reference

> Fast lookup tables. For code examples, see linked files.

## Version History (Recent)

| Version | Codename | Release | EOL | Highlights |
|---------|----------|---------|-----|------------|
| 1.35 | Timbernetes | Dec 2025 | Dec 2026 | In-Place Pod Resizing GA, Workload-Aware Scheduling Alpha |
| 1.34 | Of Wind & Will | Aug 2025 | Aug 2026 | DRA matured for GPUs/accelerators |
| 1.33 | Octarine | Apr 2025 | Apr 2026 | Endpoints deprecated, --subresource stable |
| 1.32 | - | Dec 2024 | **Feb 28, 2026** | - |

## Essential kubectl Commands

| Command | Purpose | Example |
|---------|---------|---------|
| `kubectl get` | List resources | `kubectl get pods -n my-ns -o wide` |
| `kubectl describe` | Show resource details | `kubectl describe pod my-pod` |
| `kubectl apply` | Create/update from manifest | `kubectl apply -f deployment.yaml` |
| `kubectl delete` | Delete resources | `kubectl delete pod my-pod` |
| `kubectl logs` | View container logs | `kubectl logs -f pod/my-pod -c my-container` |
| `kubectl exec` | Execute command in container | `kubectl exec -it my-pod -- /bin/sh` |
| `kubectl port-forward` | Forward local port to pod | `kubectl port-forward svc/my-svc 8080:80` |
| `kubectl scale` | Scale a resource | `kubectl scale deploy/my-app --replicas=3` |
| `kubectl rollout` | Manage rollouts | `kubectl rollout status deploy/my-app` |
| `kubectl top` | Resource usage (metrics-server) | `kubectl top pods --sort-by=memory` |
| `kubectl config` | Manage kubeconfig | `kubectl config use-context prod` |
| `kubectl create` | Create resource imperatively | `kubectl create ns my-namespace` |

## Resource Shortnames

| Full Name | Short | Full Name | Short |
|-----------|-------|-----------|-------|
| pods | po | services | svc |
| deployments | deploy | namespaces | ns |
| replicasets | rs | configmaps | cm |
| statefulsets | sts | persistentvolumeclaims | pvc |
| daemonsets | ds | persistentvolumes | pv |
| ingresses | ing | storageclasses | sc |
| nodes | no | serviceaccounts | sa |
| horizontalpodautoscalers | hpa | networkpolicies | netpol |

## Workload Selection Guide

| Use Case | Resource |
|----------|----------|
| Stateless app (web servers, APIs) | **Deployment** |
| Stateful app (databases, queues) | **StatefulSet** |
| Per-node agent (monitoring, logs) | **DaemonSet** |
| Run-to-completion task | **Job** |
| Scheduled task (backups, reports) | **CronJob** |

## Service Types

| Type | Scope | Use Case |
|------|-------|----------|
| `ClusterIP` | Internal only | Service-to-service communication |
| `NodePort` | External via node port (30000-32767) | Development, debugging |
| `LoadBalancer` | External via cloud LB | Production external traffic |
| `ExternalName` | DNS CNAME alias | External service integration |

## Common Pitfalls

| Don't | Do |
|-------|-----|
| Skip resource requests/limits | Always set `requests` and `limits` for CPU/memory |
| Use `latest` image tag | Pin specific image versions (e.g., `nginx:1.25.3`) |
| Run as root in containers | Set `runAsNonRoot: true` in securityContext |
| Store secrets in ConfigMaps | Use Secrets (or external secret managers) |
| Ignore health probes | Configure liveness, readiness, and startup probes |
| Deploy without PodDisruptionBudget | Set PDB for production workloads |
| Use default namespace for apps | Create dedicated namespaces per team/app |

## Related Documentation

| Topic | Path |
|-------|------|
| Architecture | `concepts/architecture.md` |
| Full Index | `index.md` |
| Docker Compose (local dev) | `../docker-compose/index.md` |
