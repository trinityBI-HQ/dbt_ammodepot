# Kubernetes Networking

> **Purpose**: Services, Ingress, DNS, and NetworkPolicies
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Every Pod gets a unique IP address. Services provide stable endpoints for accessing Pods. Ingress routes external HTTP/HTTPS traffic. NetworkPolicies control traffic flow between Pods at the network layer.

## Services

```yaml
# ClusterIP (internal only — default)
apiVersion: v1
kind: Service
metadata:
  name: backend
spec:
  selector:
    app: backend
  ports:
  - port: 80
    targetPort: 8080
---
# LoadBalancer (external via cloud LB)
apiVersion: v1
kind: Service
metadata:
  name: frontend
spec:
  type: LoadBalancer
  selector:
    app: frontend
  ports:
  - port: 443
    targetPort: 8080
---
# Headless Service (for StatefulSets — no ClusterIP)
apiVersion: v1
kind: Service
metadata:
  name: postgres
spec:
  clusterIP: None
  selector:
    app: postgres
  ports:
  - port: 5432
```

## DNS Resolution

Kubernetes creates DNS records automatically via CoreDNS:

| Resource | DNS Pattern |
|----------|-------------|
| Service | `<svc>.<ns>.svc.cluster.local` |
| Pod (in same ns) | Access via `<svc>` (short name) |
| Headless StatefulSet Pod | `<pod-name>.<svc>.<ns>.svc.cluster.local` |

## Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - app.example.com
    secretName: app-tls
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: backend
            port:
              number: 80
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
```

Requires an Ingress Controller (NGINX, Traefik, AWS ALB, etc.) installed in cluster.

## NetworkPolicy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: postgres
    ports:
    - port: 5432
```

**Default behavior**: All traffic allowed. Once any NetworkPolicy selects a Pod, only explicitly allowed traffic is permitted (deny-by-default for selected pods).

## Quick Reference

| Type | ClusterIP | NodePort | LoadBalancer | ExternalName |
|------|-----------|----------|--------------|--------------|
| Scope | Internal | Node ports | Cloud LB | DNS alias |
| Port range | Any | 30000-32767 | Any | N/A |
| Use case | Internal comms | Dev/debug | Production | External svc |

## EndpointSlices Migration (v1.33+)

The `Endpoints` API is **deprecated** as of v1.33. Use `EndpointSlices` instead (100 endpoints per slice, unlimited slices vs. 1,000 hard limit). EndpointSlices provide better scalability, dual-stack support, and topology-aware routing. Services use them internally; update any code directly querying the Endpoints API.

## Related

- [Architecture](architecture.md) — kube-proxy and CNI plugins
- [Security](security.md) — NetworkPolicies for security
- [Production Best Practices](../patterns/production-best-practices.md)
