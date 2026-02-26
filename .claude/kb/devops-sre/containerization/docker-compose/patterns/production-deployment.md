# Production Deployment

> **Purpose**: Production-ready Compose patterns with resource limits, security, logging, and reliability
> **MCP Validated**: 2026-02-19

## When to Use

- Deploying applications on a single host with Docker Compose
- Small to medium workloads that do not require Kubernetes-level orchestration
- Self-hosted applications where simplicity outweighs cluster management

## Implementation

```yaml
# compose.prod.yaml
services:
  api:
    image: myapp/api:${TAG:?TAG must be set}
    restart: unless-stopped
    read_only: true
    tmpfs:
      - /tmp
    security_opt:
      - no-new-privileges:true
    deploy:
      resources:
        limits:
          cpus: "2.0"
          memory: 1G
        reservations:
          cpus: "0.5"
          memory: 256M
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "5"
        compress: "true"
    networks:
      - frontend
      - backend
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16-alpine
    restart: unless-stopped
    read_only: true
    tmpfs:
      - /tmp
      - /run/postgresql
    volumes:
      - pgdata:/var/lib/postgresql/data
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_password
    deploy:
      resources:
        limits:
          cpus: "2.0"
          memory: 2G
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - backend

  nginx:
    image: nginx:1.27-alpine
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/prod.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      api:
        condition: service_healthy
    networks:
      - frontend

networks:
  frontend:
  backend:
    internal: true

volumes:
  pgdata:

secrets:
  db_password:
    file: ./secrets/db_password.txt
```

## Security Checklist

| Practice | Configuration | Purpose |
|----------|---------------|---------|
| Read-only filesystem | `read_only: true` | Prevent container writes |
| No privilege escalation | `security_opt: [no-new-privileges:true]` | Block setuid binaries |
| Non-root user | `user: "1000:1000"` | Drop root privileges |
| Internal networks | `internal: true` | Isolate backend services |
| Secrets management | `secrets:` + `_FILE` env vars | Avoid plaintext passwords |
| Pinned image tags | `image: app:1.2.3` | Reproducible deployments |

## Resource Limits

```yaml
deploy:
  resources:
    limits:
      cpus: "2.0"
      memory: 1G
      pids: 100
    reservations:
      cpus: "0.25"
      memory: 128M
```

## Logging Drivers

| Driver | Use Case | Key Options |
|--------|----------|-------------|
| `json-file` | Default, local | `max-size`, `max-file`, `compress` |
| `syslog` | Centralized syslog | `syslog-address` |
| `fluentd` | Log aggregation | `fluentd-address`, `tag` |
| `awslogs` | AWS CloudWatch | `awslogs-group`, `awslogs-region` |

## Deployment Commands

```bash
# Deploy with specific image tag
TAG=1.2.3 docker compose -f compose.yaml -f compose.prod.yaml up -d

# Update single service (no-deps avoids restarting dependencies)
TAG=1.2.4 docker compose -f compose.yaml -f compose.prod.yaml up -d --no-deps api

# Scale workers
docker compose up -d --scale worker=3

# Wait for healthchecks before completing
docker compose up -d --wait api
```

## Docker Hub Rate Limits (Apr 2025+)

| Account Type | Pull Limit | Period |
|-------------|-----------|--------|
| Unauthenticated | 100 pulls | 6 hours |
| Personal (free) | 200 pulls | 6 hours |
| Docker Pro/Team/Business | Unlimited | N/A |

Always authenticate in CI/CD (`docker login`) and consider private registries for high-volume workloads. To convert Compose to Kubernetes manifests (v2.40+): `docker compose alpha convert --output k8s-manifests/`

## Backup Pattern

```yaml
services:
  db-backup:
    image: postgres:16-alpine
    profiles: [backup]
    volumes:
      - ./backups:/backups
    entrypoint: >
      /bin/sh -c "
      pg_dump -h db -U $${DB_USER} $${DB_NAME} |
      gzip > /backups/backup-$$(date +%Y%m%d-%H%M%S).sql.gz
      "
    depends_on:
      db:
        condition: service_healthy
    networks:
      - backend
```

```bash
docker compose --profile backup run --rm db-backup
```

## See Also

- [multi-environment](multi-environment.md)
- [../concepts/lifecycle](../concepts/lifecycle.md)
