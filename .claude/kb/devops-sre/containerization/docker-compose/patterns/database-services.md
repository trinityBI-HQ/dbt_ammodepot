# Database Services

> **Purpose**: Database + application patterns with initialization scripts, persistence, and backup strategies
> **MCP Validated**: 2026-02-19

## When to Use

- Running databases alongside application services in development
- Initializing databases with schema and seed data on first startup
- Ensuring applications wait for database readiness before connecting

## Implementation

### PostgreSQL with Application

```yaml
services:
  api:
    build: ./api
    environment:
      DATABASE_URL: postgres://appuser:${DB_PASSWORD}@db:5432/myapp
    depends_on:
      db:
        condition: service_healthy
      migrate:
        condition: service_completed_successfully

  migrate:
    build: ./api
    command: ["python", "manage.py", "migrate"]
    environment:
      DATABASE_URL: postgres://appuser:${DB_PASSWORD}@db:5432/myapp
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16-alpine
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./db/init:/docker-entrypoint-initdb.d:ro
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: appuser
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U appuser -d myapp"]
      interval: 5s
      timeout: 3s
      retries: 5

volumes:
  pgdata:
```

### Init Scripts

Files in `/docker-entrypoint-initdb.d/` run on first database creation only:

```sql
-- db/init/01-extensions.sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- db/init/02-schema.sql
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### MySQL with Application

```yaml
services:
  db:
    image: mysql:8.4
    volumes:
      - mysqldata:/var/lib/mysql
      - ./db/init:/docker-entrypoint-initdb.d:ro
    environment:
      MYSQL_DATABASE: myapp
      MYSQL_USER: appuser
      MYSQL_PASSWORD: ${DB_PASSWORD}
      MYSQL_ROOT_PASSWORD: ${DB_ROOT_PASSWORD}
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 5s
      timeout: 3s
      retries: 5

volumes:
  mysqldata:
```

### Redis with Application

```yaml
services:
  api:
    build: ./api
    environment:
      REDIS_URL: redis://cache:6379/0
      CELERY_BROKER_URL: redis://cache:6379/1
    depends_on:
      cache:
        condition: service_healthy

  worker:
    build: ./api
    command: ["celery", "-A", "tasks", "worker", "--loglevel=info"]
    depends_on:
      cache:
        condition: service_healthy

  cache:
    image: redis:7-alpine
    volumes:
      - redisdata:/data
    command: ["redis-server", "--appendonly", "yes", "--maxmemory", "256mb"]
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5

volumes:
  redisdata:
```

## Healthcheck Reference

| Database | Healthcheck Command |
|----------|-------------------|
| PostgreSQL | `pg_isready -U user -d dbname` |
| MySQL | `mysqladmin ping -h localhost` |
| Redis | `redis-cli ping` |
| MongoDB | `mongosh --eval "db.adminCommand('ping')"` |
| Elasticsearch | `curl -f http://localhost:9200/_cluster/health` |

## Data Management Commands

```bash
# Reset database (delete volume and recreate)
docker compose down -v && docker compose up -d

# Backup PostgreSQL
docker compose exec db pg_dump -U appuser myapp > backup.sql

# Restore PostgreSQL
docker compose exec -T db psql -U appuser myapp < backup.sql

# Access database shell
docker compose exec db psql -U appuser myapp
```

## See Also

- [production-deployment](production-deployment.md)
- [../concepts/volumes](../concepts/volumes.md)
- [../concepts/lifecycle](../concepts/lifecycle.md)
