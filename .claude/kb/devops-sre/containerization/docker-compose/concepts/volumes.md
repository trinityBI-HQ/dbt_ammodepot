# Volumes

> **Purpose**: Persistent storage with named volumes, bind mounts, and tmpfs
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Volumes provide persistent and shared storage for containers. Docker Compose supports three mount types: named volumes (Docker-managed, persistent), bind mounts (host directory mapping), and tmpfs (in-memory). Named volumes survive `docker compose down`; bind mounts reflect host filesystem changes in real time.

## The Pattern

```yaml
services:
  api:
    build: ./api
    volumes:
      - ./src:/app/src              # Bind mount (development)
      - node_modules:/app/node_modules  # Named volume (preserves deps)

  db:
    image: postgres:16-alpine
    volumes:
      - pgdata:/var/lib/postgresql/data   # Named volume (persistent)
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql:ro  # Read-only bind

  cache:
    image: redis:7-alpine
    volumes:
      - type: tmpfs                 # In-memory storage
        target: /data
        tmpfs:
          size: 100000000           # 100MB limit

volumes:
  pgdata:
  node_modules:
```

## Mount Types

| Type | Syntax | Persistence | Use Case |
|------|--------|-------------|----------|
| Named volume | `pgdata:/var/lib/data` | Survives `down` | Database files, persistent state |
| Bind mount | `./src:/app/src` | Host filesystem | Source code in development |
| tmpfs | `type: tmpfs` | Lost on container stop | Temp files, caches, secrets |

## Long Syntax

```yaml
services:
  api:
    volumes:
      - type: bind
        source: ./src
        target: /app/src
        read_only: false

      - type: volume
        source: app-data
        target: /app/data
        volume:
          nocopy: true        # Don't copy container data into volume

      - type: tmpfs
        target: /tmp
        tmpfs:
          size: 50000000      # 50MB
          mode: 1777
```

## Named Volume Configuration

```yaml
volumes:
  pgdata:
    driver: local                    # Default driver
    driver_opts:
      type: none
      device: /mnt/ssd/pgdata       # Specific host path
      o: bind

  shared-data:
    external: true                   # Pre-existing volume, not managed by Compose

  nfs-data:
    driver: local
    driver_opts:
      type: nfs
      o: addr=192.168.1.100,rw
      device: ":/exports/data"
```

## Quick Reference

| Flag | Purpose | Example |
|------|---------|---------|
| `:ro` | Read-only mount | `./config:/etc/app:ro` |
| `:rw` | Read-write (default) | `./data:/app/data:rw` |
| `:cached` | Mac performance (relaxed consistency) | `./src:/app:cached` |
| `:delegated` | Mac performance (container-authoritative) | `./logs:/logs:delegated` |

## Common Mistakes

### Wrong

```yaml
services:
  db:
    image: postgres:16-alpine
    volumes:
      - ./pgdata:/var/lib/postgresql/data   # Bind mount for DB = permission issues
```

### Correct

```yaml
services:
  db:
    image: postgres:16-alpine
    volumes:
      - pgdata:/var/lib/postgresql/data     # Named volume for DB data

volumes:
  pgdata:                                    # Docker manages permissions
```

## Cleanup Commands

```bash
docker compose down -v              # Remove containers AND named volumes
docker volume ls                    # List all volumes
docker volume prune                 # Remove unused volumes
```

## Related

- [services](services.md)
- [../patterns/database-services](../patterns/database-services.md)
- [../patterns/development-workflow](../patterns/development-workflow.md)
