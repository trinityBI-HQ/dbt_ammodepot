# Database Setup

> **MCP Validated**: 2026-02-19

## Overview

Railway provides one-click managed databases (PostgreSQL, MySQL, MongoDB, Redis) with automatic connection strings, private networking, and persistent storage. This pattern covers provisioning, connecting, migrating, and managing databases in Railway projects.

## PostgreSQL Setup

Provision via Dashboard -> + New -> Database -> PostgreSQL. Railway creates container with NVMe SSD volume, auto-generated credentials, and `DATABASE_URL`/`DATABASE_PRIVATE_URL` variables.

### Connection Pattern
```javascript
const pool = new Pool({
  connectionString: process.env.DATABASE_PRIVATE_URL,
  ssl: { rejectUnauthorized: false },
  max: 20, idleTimeoutMillis: 30000, connectionTimeoutMillis: 2000
});
const result = await pool.query('SELECT * FROM users WHERE id = $1', [userId]);
```

### Migrations
Run on deploy via `railway.json`: `"startCommand": "npx knex migrate:latest && node server.js"` (Knex) or `"alembic upgrade head && python app.py"` (Alembic).

## MySQL Setup

Provision via Dashboard. Variables: `MYSQL_URL`, `MYSQL_PRIVATE_URL`. Use `mysql2/promise` pool with `connectionLimit: 10`.

## MongoDB Setup

Provision via Dashboard. Variables: `MONGO_URL`, `MONGO_PRIVATE_URL`. Use `MongoClient` with `maxPoolSize: 10` or Mongoose with same connection string.

## Redis Setup

Provision via Dashboard. Variables: `REDIS_URL`, `REDIS_PRIVATE_URL`. Use `ioredis` (Node.js) or `redis-py` (Python). Common patterns: caching with TTL (`EX` flag), session storage, Pub/Sub, job queues.

## Multi-Database Pattern

### API + Primary DB + Cache
```
Project: E-commerce
├── api-service
│   └── Variables:
│       ├── DATABASE_PRIVATE_URL → ${{postgres.DATABASE_PRIVATE_URL}}
│       └── REDIS_PRIVATE_URL → ${{redis.REDIS_PRIVATE_URL}}
├── postgres (primary data)
└── redis (cache + sessions)
```

### Microservices with Isolated DBs
```
Project: Microservices
├── user-service
│   └── user-postgres
├── order-service
│   └── order-postgres
├── inventory-service
│   └── inventory-mongo
└── shared-redis
```

## Database Backup Pattern

Create a backup service with `pg_dump $DATABASE_PRIVATE_URL | gzip > backup.sql.gz` and upload to S3. Seed non-production environments only: check `RAILWAY_ENVIRONMENT !== 'production'`.

## Connection Pooling Best Practices

| Database | Pool Size | Timeout | Key Settings |
|----------|-----------|---------|--------------|
| PostgreSQL | max: 20, min: 5 | idle: 30s, connect: 2s | `statement_timeout: 10000` |
| MongoDB | maxPoolSize: 10 | serverSelection: 5s | `socketTimeoutMS: 45000` |

## Health Check with Database

```javascript
app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'healthy', database: 'connected' });
  } catch (error) {
    res.status(503).json({ status: 'unhealthy', error: error.message });
  }
});
```

## Related

- [databases](../concepts/databases.md)
- [variables](../concepts/variables.md)
- [private-networking](../patterns/private-networking.md)
