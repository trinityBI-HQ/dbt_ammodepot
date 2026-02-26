# Docker Compose Quick Reference

> Fast lookup tables. For code examples, see linked files.

## Core Commands

| Command | Purpose | Example |
|---------|---------|---------|
| `docker compose up` | Create and start services | `docker compose up -d` |
| `docker compose down` | Stop and remove services | `docker compose down -v` |
| `docker compose build` | Build or rebuild services | `docker compose build --no-cache` |
| `docker compose ps` | List running services | `docker compose ps -a` |
| `docker compose logs` | View service logs | `docker compose logs -f api` |
| `docker compose exec` | Run command in running container | `docker compose exec api bash` |
| `docker compose run` | Run one-off command | `docker compose run api pytest` |
| `docker compose watch` | Watch mode with file sync | `docker compose watch` |
| `docker compose stop` | Stop services (keep containers) | `docker compose stop api` |
| `docker compose restart` | Restart services | `docker compose restart api` |
| `docker compose pull` | Pull service images | `docker compose pull` |
| `docker compose config` | Validate and view config | `docker compose config --quiet` |
| `docker compose alpha convert` | Convert to Kubernetes manifests | `docker compose alpha convert` |

## Compose File Top-Level Elements

| Element | Purpose |
|---------|---------|
| `services` | Container definitions (required) |
| `networks` | Custom network configuration |
| `volumes` | Named volume declarations |
| `configs` | Per-service config file objects |
| `secrets` | Sensitive data definitions |
| `models` | AI model declarations (2025+) |

## Service Configuration Keys

| Key | Purpose | Example |
|-----|---------|---------|
| `image` | Container image | `postgres:16-alpine` |
| `build` | Build from Dockerfile | `build: ./api` |
| `ports` | Publish ports | `"8080:80"` |
| `volumes` | Mount volumes | `./src:/app/src` |
| `environment` | Set env vars | `DB_HOST: db` |
| `depends_on` | Service dependencies | `condition: service_healthy` |
| `profiles` | Assign to profile | `profiles: [debug]` |
| `restart` | Restart policy | `unless-stopped` |
| `healthcheck` | Health check config | `test: ["CMD", "pg_isready"]` |
| `deploy` | Resource limits | `deploy.resources.limits` |
| `command` | Override CMD | `["uvicorn", "main:app"]` |
| `entrypoint` | Override ENTRYPOINT | `["/entrypoint.sh"]` |

## Decision Matrix

| Use Case | Choose |
|----------|--------|
| Local multi-service dev | `docker compose up` with watch |
| Run tests in containers | `docker compose run --rm api pytest` |
| Optional service (debug tools) | `profiles: [debug]` |
| Wait for DB before app starts | `depends_on` + `service_healthy` |
| Persistent database data | Named volumes |
| Env-specific config | Override files + `.env` |
| Production on single host | Resource limits + healthchecks |
| Multi-host orchestration | Use Kubernetes instead |

## Common Pitfalls

| Don't | Do |
|-------|-----|
| Use `docker-compose` (V1 binary) | Use `docker compose` (V2 plugin) |
| Add `version:` key | Omit it (officially deprecated, ignored) |
| Use `latest` tag in production | Pin specific image versions |
| Hardcode secrets in compose file | Use `.env` files or Docker secrets |
| Use `restart: always` in dev | Use `restart: unless-stopped` |
| Expose database ports publicly | Use internal networks only |
| Pull unauthenticated from Docker Hub | `docker login` (100 pulls/6hrs unauth limit) |

## Related Documentation

| Topic | Path |
|-------|------|
| Getting Started | `concepts/compose-file.md` |
| Full Index | `index.md` |
