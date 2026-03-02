# Production Deployment

> **Purpose**: Deploy Langflow applications to production with scaling, monitoring, and security best practices
> **MCP Validated**: 2026-02-06

## When to Use

- Deploying Langflow to production environments
- Need high availability and horizontal scaling
- Require comprehensive monitoring and logging

## Implementation

```yaml
# Kubernetes Deployment (core resources)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: langflow
  namespace: langflow
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate: { maxSurge: 1, maxUnavailable: 0 }
  selector:
    matchLabels: { app: langflow }
  template:
    metadata:
      labels: { app: langflow, version: v1.0.0 }
    spec:
      containers:
      - name: langflow
        image: langflowai/langflow:1.0.0
        ports:
        - containerPort: 7860
        envFrom:
        - configMapRef: { name: langflow-config }
        - secretRef: { name: langflow-secrets }
        resources:
          requests: { memory: "1Gi", cpu: "500m" }
          limits: { memory: "4Gi", cpu: "2000m" }
        livenessProbe:
          httpGet: { path: /health, port: 7860 }
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet: { path: /ready, port: 7860 }
          initialDelaySeconds: 10
          periodSeconds: 5
---
# HPA
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: langflow
  namespace: langflow
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: langflow
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target: { type: Utilization, averageUtilization: 70 }
---
# Ingress with TLS + rate limiting
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: langflow
  namespace: langflow
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts: [langflow.example.com]
    secretName: langflow-tls
  rules:
  - host: langflow.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service: { name: langflow, port: { number: 80 } }
```

## Configuration

| Setting | Production Value | Description |
|---------|------------------|-------------|
| `replicas` | 3+ | Minimum pods for HA |
| `resources.memory` | 1-4Gi | Based on flow complexity |
| `resources.cpu` | 500m-2000m | Based on traffic |
| `max_replicas` | 10+ | HPA maximum |
| `rate_limit` | 100/min | API rate limiting |

## Docker Compose (Simpler Deployment)

```yaml
version: '3.8'
services:
  langflow:
    image: langflowai/langflow:latest
    deploy:
      replicas: 3
      resources:
        limits: { cpus: '2', memory: 4G }
    environment:
      - LANGFLOW_SECRET_KEY=${SECRET_KEY}
      - LANGFLOW_DATABASE_URL=postgresql://postgres:${POSTGRES_PASSWORD}@postgres:5432/langflow
      - LANGFLOW_REDIS_URL=redis://redis:6379
      - LANGFLOW_WORKERS=4
    depends_on: [postgres, redis]
    ports: ["7860:7860"]
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:7860/health"]
      interval: 30s
      timeout: 10s
      retries: 3
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: langflow
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes: [postgres_data:/var/lib/postgresql/data]
  redis:
    image: redis:7
    volumes: [redis_data:/data]
volumes:
  postgres_data:
  redis_data:
```

## Monitoring Metrics

```python
from prometheus_client import Counter, Histogram, Gauge

flow_executions = Counter('langflow_executions_total', 'Total flow executions', ['flow_id', 'status'])
execution_duration = Histogram('langflow_execution_duration_seconds', 'Flow execution duration', ['flow_id'])
active_flows = Gauge('langflow_active_flows', 'Currently executing flows')
```

## Common Pitfalls

```yaml
# Always use multiple replicas, resource limits, Secrets (not ConfigMaps), and health probes
# Bad: replicas: 1, resources: {}, secrets in ConfigMap, no livenessProbe
# Good: replicas: 3, memory/cpu limits set, Secrets for credentials, probes configured
```

## Example Usage

```bash
kubectl apply -f namespace.yaml configmap.yaml secrets.yaml deployment.yaml service.yaml ingress.yaml hpa.yaml
kubectl get pods -n langflow
kubectl get hpa -n langflow
curl https://langflow.example.com/health
```

## See Also

- [api-deployment.md](../concepts/api-deployment.md) - API configuration
- [api-integration.md](../patterns/api-integration.md) - API client integration
