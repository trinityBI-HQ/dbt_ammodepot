# Networking

> **Purpose**: Networks, DNS-based service discovery, port mapping, and network isolation
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Compose automatically creates a default bridge network for each project. Services on the same network can reach each other by service name via built-in DNS. Custom networks allow isolation between groups of services (e.g., separating frontend from backend).

## The Pattern

```yaml
services:
  api:
    build: ./api
    ports:
      - "8000:8000"        # Published to host
    networks:
      - frontend
      - backend

  db:
    image: postgres:16-alpine
    expose:
      - "5432"             # Only accessible on backend network
    networks:
      - backend

  nginx:
    image: nginx:1.27-alpine
    ports:
      - "80:80"
    networks:
      - frontend

networks:
  frontend:
  backend:
    internal: true         # No external access
```

## DNS and Service Discovery

Services communicate by name. Compose creates DNS entries automatically:

```yaml
services:
  api:
    environment:
      DATABASE_URL: postgres://user:pass@db:5432/myapp    # "db" resolves to db container
      REDIS_URL: redis://cache:6379                        # "cache" resolves to cache container

  db:
    image: postgres:16-alpine

  cache:
    image: redis:7-alpine
```

## Ports vs Expose

| Directive | Visibility | Syntax | Use Case |
|-----------|-----------|--------|----------|
| `ports` | Host + containers | `"HOST:CONTAINER"` | External access |
| `expose` | Containers only | `"CONTAINER"` | Internal services |
| Neither | Containers on same network | N/A | Default (all ports accessible between services) |

Port mapping formats:

```yaml
ports:
  - "8080:80"              # host:container
  - "8080:80/udp"          # with protocol
  - "127.0.0.1:8080:80"   # bind to localhost only
  - "8080-8090:80-90"     # port range
```

## Network Drivers

| Driver | Use Case | Multi-Host |
|--------|----------|------------|
| `bridge` | Default, single-host isolation | No |
| `host` | Container uses host network stack | No |
| `overlay` | Multi-host (Swarm mode) | Yes |
| `none` | Disable networking | N/A |

```yaml
networks:
  backend:
    driver: bridge
    internal: true         # No internet access
    ipam:
      config:
        - subnet: 172.28.0.0/16
```

## Network Aliases

```yaml
services:
  primary-db:
    image: postgres:16-alpine
    networks:
      backend:
        aliases:
          - db             # Also reachable as "db"
          - database       # Also reachable as "database"
```

## Common Mistakes

### Wrong

```yaml
services:
  db:
    image: postgres:16-alpine
    ports:
      - "5432:5432"        # Exposes DB to host network
```

### Correct

```yaml
services:
  db:
    image: postgres:16-alpine
    # No ports mapping -- only accessible from other services on same network
    networks:
      - backend

networks:
  backend:
    internal: true
```

## Related

- [services](services.md)
- [../patterns/production-deployment](../patterns/production-deployment.md)
