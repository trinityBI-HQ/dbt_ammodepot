# Databases

> **Purpose**: One-click provisioning of managed PostgreSQL, MySQL, MongoDB, and Redis
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Railway provides managed database services that can be provisioned with zero configuration on Metal infrastructure. Databases run on NVMe SSDs for high I/O performance and support high-availability (HA) volumes for persistent storage. Databases are deployed as services within your project and automatically provide connection strings via environment variables. Railway supports PostgreSQL, MySQL, MongoDB, and Redis, all accessible via a secure private network. Deleted volumes can be restored (Aug 2025+).

## The Pattern

```bash
# Add database via dashboard
# Project → + New → Database → PostgreSQL

# Connection string automatically injected
echo $DATABASE_URL
# postgresql://postgres:password@postgres.railway.internal:5432/railway
```

## Supported Databases

| Database | Use Case | Connection Variable |
|----------|----------|---------------------|
| **PostgreSQL** | Relational data, JSON support | `DATABASE_URL` |
| **MySQL** | Traditional relational database | `MYSQL_URL` |
| **MongoDB** | Document store | `MONGO_URL` |
| **Redis** | Cache, sessions, queues | `REDIS_URL` |

## Provisioning

All databases provisioned via: Dashboard -> + New -> Database -> {type}. Railway auto-generates credentials and injects connection strings. See [database-setup](../patterns/database-setup.md) for detailed connection patterns.

### Quick Connection Examples
```javascript
// PostgreSQL (Node.js)
const pool = new Pool({ connectionString: process.env.DATABASE_PRIVATE_URL });

// Redis (Node.js)
const redis = new Redis(process.env.REDIS_PRIVATE_URL);

// MongoDB (Node.js)
const client = new MongoClient(process.env.MONGO_PRIVATE_URL);
```

## Private Networking

Databases are accessible via private network:

```
Public: Not exposed to internet
Private: postgres.railway.internal:5432
```

Benefits:
- Zero egress costs for service-to-service calls
- Automatic DNS resolution
- Secure by default
- No additional configuration needed

## Environment Variables

Railway automatically injects:

```bash
# PostgreSQL
DATABASE_URL=postgresql://user:pass@host:5432/db
DATABASE_PRIVATE_URL=postgresql://postgres.railway.internal:5432/railway

# MySQL
MYSQL_URL=mysql://user:pass@host:3306/db
MYSQL_PRIVATE_URL=mysql://mysql.railway.internal:3306/railway

# MongoDB
MONGO_URL=mongodb://user:pass@host:27017/db
MONGO_PRIVATE_URL=mongodb://mongo.railway.internal:27017/railway

# Redis
REDIS_URL=redis://user:pass@host:6379
REDIS_PRIVATE_URL=redis://redis.railway.internal:6379
```

## Database Management

### Via Railway Dashboard
- Query editor (PostgreSQL, MySQL)
- View tables and data
- Run migrations
- Monitor resource usage

### Via External Tools
```bash
# Connect with psql
psql $DATABASE_URL

# Connect with mysql client
mysql $MYSQL_URL

# Connect with mongosh
mongosh $MONGO_URL

# Connect with redis-cli
redis-cli -u $REDIS_URL
```

## Backups and Persistence

Railway provides on Metal infrastructure:
- **NVMe SSD volumes**: High I/O performance for database workloads
- **High-availability volumes**: HA volumes for critical databases (Metal)
- **Persistent volumes**: Data survives container restarts
- **Automatic backups**: Available on Pro plan
- **Point-in-time recovery**: Restore to specific timestamp
- **Volume restoration**: Recover deleted volumes (Aug 2025+)

Volume path: `/var/lib/postgresql/data` (Postgres)

## Migrations

Run migrations on deploy via `startCommand` in `railway.json`. See [database-setup](../patterns/database-setup.md) for Knex, Alembic, and other migration patterns.


## Related

- [services](../concepts/services.md)
- [variables](../concepts/variables.md)
- [private-networking](../patterns/private-networking.md)
