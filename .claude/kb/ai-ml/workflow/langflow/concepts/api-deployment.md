# API Deployment

> **Purpose**: Deploy Langflow flows as REST APIs with authentication and production configuration
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-06

## Overview

All Langflow flows automatically become REST APIs that can be called programmatically. The API provides endpoints for running flows, retrieving results, and managing flow lifecycle. Authentication options include API keys, OAuth, and custom middleware. Deployment strategies range from local development to production Kubernetes clusters.

## API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/v1/run/{flow_id}` | POST | Execute flow with inputs |
| `/api/v1/flows/{flow_id}` | GET | Retrieve flow configuration |
| `/api/v1/flows` | GET | List all flows |
| `/api/v1/flows/{flow_id}` | PUT | Update flow |
| `/api/v1/flows/{flow_id}` | DELETE | Delete flow |
| `/api/v1/mcp/sse` | SSE | MCP server endpoint |

## Running a Flow

```python
# Python client example
import requests

flow_id = "abc-123-def"
api_key = "sk_langflow_abc123"
url = f"https://api.langflow.app/api/v1/run/{flow_id}"

headers = {
    "Authorization": f"Bearer {api_key}",
    "Content-Type": "application/json"
}

payload = {
    "inputs": {
        "question": "What is Langflow?",
        "context": ""
    },
    "tweaks": {
        "temperature": 0.7,
        "max_tokens": 500
    }
}

response = requests.post(url, json=payload, headers=headers)
result = response.json()

print(result["outputs"]["answer"])
```

## Authentication

```python
# API key authentication (recommended for production)
headers = {
    "Authorization": f"Bearer {LANGFLOW_API_KEY}"
}

# Basic authentication (development)
auth = ("username", "password")

# Custom headers
headers = {
    "X-API-Key": api_key,
    "X-User-ID": user_id
}
```

## Environment Configuration

```bash
# .env file for deployment
LANGFLOW_SECRET_KEY=your-secret-key-here
LANGFLOW_DATABASE_URL=postgresql://user:pass@host/db
LANGFLOW_WORKERS=4
LANGFLOW_LOG_LEVEL=INFO
LANGFLOW_CACHE_TYPE=redis
LANGFLOW_REDIS_URL=redis://localhost:6379

# API settings
LANGFLOW_API_RATE_LIMIT=100  # Requests per minute
LANGFLOW_API_TIMEOUT=30  # Seconds
LANGFLOW_ENABLE_CORS=true
```

## Docker Deployment

```dockerfile
# Dockerfile
FROM langflowai/langflow:latest

# Copy flows
COPY flows/ /app/flows/

# Environment variables
ENV LANGFLOW_SECRET_KEY=${SECRET_KEY}
ENV LANGFLOW_DATABASE_URL=${DATABASE_URL}

# Expose port
EXPOSE 7860

# Start server
CMD ["langflow", "run", "--host", "0.0.0.0", "--port", "7860"]
```

```yaml
# docker-compose.yml
version: '3.8'

services:
  langflow:
    image: langflowai/langflow:latest
    ports:
      - "7860:7860"
    environment:
      - LANGFLOW_SECRET_KEY=${SECRET_KEY}
      - LANGFLOW_DATABASE_URL=postgresql://postgres:password@db:5432/langflow
      - LANGFLOW_REDIS_URL=redis://redis:6379
    depends_on:
      - db
      - redis
    volumes:
      - ./flows:/app/flows

  db:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: password
      POSTGRES_DB: langflow
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7
    ports:
      - "6379:6379"

volumes:
  postgres_data:
```

## Kubernetes Deployment

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: langflow
spec:
  replicas: 3
  selector:
    matchLabels:
      app: langflow
  template:
    metadata:
      labels:
        app: langflow
    spec:
      containers:
      - name: langflow
        image: langflowai/langflow:latest
        ports:
        - containerPort: 7860
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
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "2000m"
        livenessProbe:
          httpGet:
            path: /health
            port: 7860
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 7860
          initialDelaySeconds: 5
          periodSeconds: 5
```

## Rate Limiting

```python
# Configure rate limits per API key
rate_limit_config = {
    "enabled": True,
    "per_minute": 60,
    "per_hour": 1000,
    "per_day": 10000,
    "burst": 10  # Allow short bursts
}

# Response headers
# X-RateLimit-Limit: 60
# X-RateLimit-Remaining: 45
# X-RateLimit-Reset: 1620000000
```

## Common Mistakes

### Wrong

```python
# Hardcoded API keys in code
api_key = "sk_abc123..."  # Security risk

# No timeout
requests.post(url, json=payload)  # Can hang forever

# Single instance (no scaling)
# Production needs multiple workers
```

### Correct

```python
# Environment variables
api_key = os.getenv("LANGFLOW_API_KEY")

# Timeout and retry
response = requests.post(
    url,
    json=payload,
    headers=headers,
    timeout=30,
    retries=3
)

# Horizontal scaling with load balancer
replicas: 3
```

## Monitoring

```python
# Health check endpoint
@app.get("/health")
def health():
    return {
        "status": "healthy",
        "version": "1.0.0",
        "uptime": get_uptime(),
        "flows": len(active_flows)
    }

# Metrics endpoint
@app.get("/metrics")
def metrics():
    return {
        "requests_per_minute": rpm,
        "average_latency_ms": latency,
        "error_rate": errors / total,
        "active_flows": active_count
    }
```

## CORS Configuration

```python
# Allow frontend access
cors_config = {
    "allow_origins": [
        "https://app.example.com",
        "https://admin.example.com"
    ],
    "allow_methods": ["GET", "POST", "PUT", "DELETE"],
    "allow_headers": ["Authorization", "Content-Type"],
    "allow_credentials": True
}
```

## Related

- [flows-components.md](../concepts/flows-components.md) - Flow fundamentals
- [production-deployment.md](../patterns/production-deployment.md) - Production best practices
- [api-integration.md](../patterns/api-integration.md) - Integration patterns
