# Production Deployment

> **Purpose**: Deploy Langflow applications to production with scaling, monitoring, and security best practices
> **MCP Validated**: 2026-02-06

## When to Use

- Deploying Langflow to production environments
- Need high availability and horizontal scaling
- Require comprehensive monitoring and logging
- Must meet security and compliance requirements

## Implementation

```yaml
# 1. KUBERNETES DEPLOYMENT (Production-Ready)

# namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: langflow

---
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: langflow-config
  namespace: langflow
data:
  LANGFLOW_LOG_LEVEL: "INFO"
  LANGFLOW_WORKERS: "4"
  LANGFLOW_CACHE_TYPE: "redis"
  LANGFLOW_ENABLE_CORS: "true"

---
# secrets.yaml (use sealed-secrets or external secrets)
apiVersion: v1
kind: Secret
metadata:
  name: langflow-secrets
  namespace: langflow
type: Opaque
stringData:
  secret-key: "your-secret-key-here"
  database-url: "postgresql://user:pass@postgres:5432/langflow"
  redis-url: "redis://redis:6379"
  openai-api-key: "sk-..."
  pinecone-api-key: "pc-..."

---
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: langflow
  namespace: langflow
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: langflow
  template:
    metadata:
      labels:
        app: langflow
        version: v1.0.0
    spec:
      containers:
      - name: langflow
        image: langflowai/langflow:1.0.0
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 7860
          name: http
        env:
        - name: LANGFLOW_SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: langflow-secrets
              key: secret-key
        - name: LANGFLOW_DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: langflow-secrets
              key: database-url
        - name: LANGFLOW_REDIS_URL
          valueFrom:
            secretKeyRef:
              name: langflow-secrets
              key: redis-url
        - name: OPENAI_API_KEY
          valueFrom:
            secretKeyRef:
              name: langflow-secrets
              key: openai-api-key
        envFrom:
        - configMapRef:
            name: langflow-config
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "4Gi"
            cpu: "2000m"
        livenessProbe:
          httpGet:
            path: /health
            port: 7860
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /ready
            port: 7860
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 2
        volumeMounts:
        - name: flows
          mountPath: /app/flows
          readOnly: true
      volumes:
      - name: flows
        configMap:
          name: langflow-flows

---
# service.yaml
apiVersion: v1
kind: Service
metadata:
  name: langflow
  namespace: langflow
spec:
  type: ClusterIP
  selector:
    app: langflow
  ports:
  - port: 80
    targetPort: 7860
    name: http

---
# ingress.yaml
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
  - hosts:
    - langflow.example.com
    secretName: langflow-tls
  rules:
  - host: langflow.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: langflow
            port:
              number: 80

---
# hpa.yaml (Horizontal Pod Autoscaler)
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
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80


# 2. POSTGRESQL DATABASE

# postgres-deployment.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: langflow
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15
        env:
        - name: POSTGRES_DB
          value: langflow
        - name: POSTGRES_USER
          value: langflow
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: langflow-secrets
              key: postgres-password
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"
          limits:
            memory: "4Gi"
            cpu: "2000m"
  volumeClaimTemplates:
  - metadata:
      name: postgres-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 50Gi


# 3. REDIS CACHE

# redis-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: langflow
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7
        ports:
        - containerPort: 6379
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"


# 4. MONITORING (Prometheus + Grafana)

# servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: langflow
  namespace: langflow
spec:
  selector:
    matchLabels:
      app: langflow
  endpoints:
  - port: http
    path: /metrics
    interval: 30s


# 5. LOGGING (Fluent Bit)

# fluent-bit-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
  namespace: langflow
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush         5
        Daemon        off
        Log_Level     info

    [INPUT]
        Name              tail
        Path              /var/log/containers/langflow*.log
        Parser            docker
        Tag               langflow.*
        Refresh_Interval  5

    [OUTPUT]
        Name   es
        Match  langflow.*
        Host   elasticsearch
        Port   9200
        Index  langflow-logs
```

## Configuration

| Setting | Production Value | Description |
|---------|------------------|-------------|
| `replicas` | 3+ | Minimum pods for HA |
| `resources.memory` | 1-4Gi | Based on flow complexity |
| `resources.cpu` | 500m-2000m | Based on traffic |
| `max_replicas` | 10+ | HPA maximum |
| `rate_limit` | 100/min | API rate limiting |

## Example Usage

```bash
# Deploy to Kubernetes
kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml
kubectl apply -f secrets.yaml
kubectl apply -f postgres-deployment.yaml
kubectl apply -f redis-deployment.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml
kubectl apply -f hpa.yaml

# Check deployment status
kubectl get pods -n langflow
kubectl logs -n langflow -l app=langflow -f

# Scale manually
kubectl scale deployment langflow -n langflow --replicas=5

# Check HPA status
kubectl get hpa -n langflow

# Access application
curl https://langflow.example.com/health
```

## Docker Compose (Simpler Deployment)

```yaml
# docker-compose.production.yml
version: '3.8'

services:
  langflow:
    image: langflowai/langflow:latest
    deploy:
      replicas: 3
      resources:
        limits:
          cpus: '2'
          memory: 4G
        reservations:
          cpus: '0.5'
          memory: 1G
    environment:
      - LANGFLOW_SECRET_KEY=${SECRET_KEY}
      - LANGFLOW_DATABASE_URL=postgresql://postgres:${POSTGRES_PASSWORD}@postgres:5432/langflow
      - LANGFLOW_REDIS_URL=redis://redis:6379
      - LANGFLOW_WORKERS=4
      - LANGFLOW_LOG_LEVEL=INFO
    depends_on:
      - postgres
      - redis
    ports:
      - "7860:7860"
    volumes:
      - ./flows:/app/flows:ro
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:7860/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: langflow
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped

  redis:
    image: redis:7
    volumes:
      - redis_data:/data
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
    depends_on:
      - langflow
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:
```

## Security Best Practices

```yaml
# Network Policy (restrict access)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: langflow-network-policy
  namespace: langflow
spec:
  podSelector:
    matchLabels:
      app: langflow
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 7860
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: postgres
    ports:
    - protocol: TCP
      port: 5432
  - to:
    - podSelector:
        matchLabels:
          app: redis
    ports:
    - protocol: TCP
      port: 6379
```

## Monitoring Dashboard

```python
# Custom Prometheus metrics
from prometheus_client import Counter, Histogram, Gauge

# Flow execution metrics
flow_executions = Counter(
    'langflow_executions_total',
    'Total flow executions',
    ['flow_id', 'status']
)

execution_duration = Histogram(
    'langflow_execution_duration_seconds',
    'Flow execution duration',
    ['flow_id']
)

active_flows = Gauge(
    'langflow_active_flows',
    'Number of currently executing flows'
)

# Track in application
@app.post("/api/v1/run/{flow_id}")
async def run_flow(flow_id: str):
    active_flows.inc()
    start_time = time.time()

    try:
        result = await execute_flow(flow_id)
        flow_executions.labels(flow_id=flow_id, status='success').inc()
        return result

    except Exception as e:
        flow_executions.labels(flow_id=flow_id, status='error').inc()
        raise

    finally:
        duration = time.time() - start_time
        execution_duration.labels(flow_id=flow_id).observe(duration)
        active_flows.dec()
```

## Common Pitfalls

```yaml
# ❌ Don't: Single replica (no HA)
replicas: 1

# ✓ Do: Multiple replicas
replicas: 3

# ❌ Don't: No resource limits
resources: {}

# ✓ Do: Set appropriate limits
resources:
  limits:
    memory: "4Gi"
    cpu: "2000m"

# ❌ Don't: Secrets in ConfigMap
configMap:
  API_KEY: "sk-abc123..."  # Visible!

# ✓ Do: Use Secrets
secret:
  API_KEY: "..."  # Encrypted

# ❌ Don't: No health checks
livenessProbe: null

# ✓ Do: Configure probes
livenessProbe:
  httpGet:
    path: /health
```

## See Also

- [api-deployment.md](../concepts/api-deployment.md) - API configuration
- [api-integration.md](../patterns/api-integration.md) - API client integration
