# API Deployment

> **Purpose**: Deploy Langflow flows as REST APIs with authentication and production configuration
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-06

## Overview

All Langflow flows automatically become REST APIs. The API provides endpoints for running flows, retrieving results, and managing lifecycle. Authentication options include API keys, OAuth, and custom middleware.

## API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/v1/run/{flow_id}` | POST | Execute flow with inputs |
| `/api/v1/flows/{flow_id}` | GET | Retrieve flow configuration |
| `/api/v1/flows` | GET | List all flows |
| `/api/v1/flows/{flow_id}` | PUT/DELETE | Update or delete flow |
| `/api/v1/mcp/sse` | SSE | MCP server endpoint |

## Running a Flow

```python
import requests, os

flow_id = "abc-123-def"
url = f"https://api.langflow.app/api/v1/run/{flow_id}"
headers = {"Authorization": f"Bearer {os.getenv('LANGFLOW_API_KEY')}", "Content-Type": "application/json"}
payload = {"inputs": {"question": "What is Langflow?"}, "tweaks": {"temperature": 0.7, "max_tokens": 500}}

result = requests.post(url, json=payload, headers=headers, timeout=30).json()
```

## Authentication

```python
# API key (recommended)
headers = {"Authorization": f"Bearer {os.getenv('LANGFLOW_API_KEY')}"}
# Basic auth (development only)
auth = ("username", "password")
```

## Environment Configuration

```bash
LANGFLOW_SECRET_KEY=your-secret-key-here
LANGFLOW_DATABASE_URL=postgresql://user:pass@host/db
LANGFLOW_WORKERS=4
LANGFLOW_LOG_LEVEL=INFO
LANGFLOW_CACHE_TYPE=redis
LANGFLOW_REDIS_URL=redis://localhost:6379
LANGFLOW_API_RATE_LIMIT=100
LANGFLOW_API_TIMEOUT=30
LANGFLOW_ENABLE_CORS=true
```

## Docker Deployment

```yaml
# docker-compose.yml
services:
  langflow:
    image: langflowai/langflow:latest
    ports: ["7860:7860"]
    environment:
      - LANGFLOW_SECRET_KEY=${SECRET_KEY}
      - LANGFLOW_DATABASE_URL=postgresql://postgres:password@db:5432/langflow
    depends_on: [db, redis]
    volumes: ["./flows:/app/flows"]
  db:
    image: postgres:15
    environment: {POSTGRES_PASSWORD: password, POSTGRES_DB: langflow}
    volumes: ["postgres_data:/var/lib/postgresql/data"]
  redis:
    image: redis:7
volumes:
  postgres_data:
```

## Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata: {name: langflow}
spec:
  replicas: 3
  selector: {matchLabels: {app: langflow}}
  template:
    metadata: {labels: {app: langflow}}
    spec:
      containers:
      - name: langflow
        image: langflowai/langflow:latest
        ports: [{containerPort: 7860}]
        envFrom: [{secretRef: {name: langflow-secrets}}]
        resources:
          requests: {memory: "512Mi", cpu: "500m"}
          limits: {memory: "2Gi", cpu: "2000m"}
        livenessProbe: {httpGet: {path: /health, port: 7860}, initialDelaySeconds: 30}
        readinessProbe: {httpGet: {path: /ready, port: 7860}, initialDelaySeconds: 5}
```

## Rate Limiting

```python
rate_limit_config = {"enabled": True, "per_minute": 60, "per_hour": 1000, "per_day": 10000, "burst": 10}
# Response headers: X-RateLimit-Limit, X-RateLimit-Remaining, X-RateLimit-Reset
```

## Common Mistakes

```python
# Wrong: Hardcoded keys, no timeout, single instance
api_key = "sk_abc123..."
requests.post(url, json=payload)

# Correct: Env vars, timeout+retry, horizontal scaling
api_key = os.getenv("LANGFLOW_API_KEY")
requests.post(url, json=payload, headers=headers, timeout=30)
# Deploy with replicas: 3 and load balancer
```

## Monitoring

```python
# /health returns: {"status": "healthy", "version": "1.0.0", "uptime": ..., "flows": count}
# /metrics returns: {"requests_per_minute": rpm, "average_latency_ms": ..., "error_rate": ...}
```

## CORS Configuration

```python
cors_config = {
    "allow_origins": ["https://app.example.com"],
    "allow_methods": ["GET", "POST", "PUT", "DELETE"],
    "allow_headers": ["Authorization", "Content-Type"],
    "allow_credentials": True
}
```

## Related

- [flows-components.md](../concepts/flows-components.md) - Flow fundamentals
- [production-deployment.md](../patterns/production-deployment.md) - Production best practices
- [api-integration.md](../patterns/api-integration.md) - Integration patterns
