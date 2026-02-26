# Railway Quick Reference

> **MCP Validated**: 2026-02-19

## CLI Commands

| Command | Description |
|---------|-------------|
| `railway login` | Authenticate with Railway account |
| `railway init` | Initialize project in current directory |
| `railway link` | Link directory to existing project |
| `railway up` | Deploy current directory |
| `railway open` | Open project in browser |
| `railway status` | Show project deployment status |
| `railway logs` | Stream deployment logs |
| `railway run <cmd>` | Run command with Railway environment |
| `railway variables` | List environment variables |
| `railway variables set KEY=VALUE` | Set environment variable |
| `railway dev` | Run entire environment locally with TUI (tabbed per service) |
| `railway domain` | Manage custom domains |
| `railway environment` | Switch between environments |

## Configuration (railway.json/railway.toml)

| Field | Description | Example |
|-------|-------------|---------|
| `builder` | Build method | `NIXPACKS`, `DOCKERFILE` |
| `buildCommand` | Custom build | `npm run build` |
| `startCommand` | Override start | `node dist/index.js` |
| `restartPolicyType` | Restart policy | `ON_FAILURE` |
| `healthcheckPath` | Health endpoint | `/health` |

## Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `RAILWAY_ENVIRONMENT` | Current environment name | `production` |
| `RAILWAY_PROJECT_ID` | Project identifier | `abc123...` |
| `RAILWAY_SERVICE_ID` | Service identifier | `def456...` |
| `RAILWAY_PUBLIC_DOMAIN` | Public service URL | `myapp.up.railway.app` |
| `RAILWAY_PRIVATE_DOMAIN` | Private network URL | `myapp.railway.internal` |
| `DATABASE_URL` | Auto-generated database connection | `postgresql://...` |
| `REDIS_URL` | Auto-generated Redis connection | `redis://...` |

## Database Templates

| Database | Template Command | Connection Variable |
|----------|------------------|---------------------|
| PostgreSQL | Add via dashboard | `DATABASE_URL` |
| MySQL | Add via dashboard | `MYSQL_URL` |
| MongoDB | Add via dashboard | `MONGO_URL` |
| Redis | Add via dashboard | `REDIS_URL` |

## Service Types

| Type | Source | Use Case |
|------|--------|----------|
| GitHub Repo | Git push triggers deploy | Continuous deployment |
| Docker Image | Registry pull | Pre-built containers |
| Template | One-click deploy | Quick starts |
| Empty Service | Manual configuration | Custom setups |

## Deployment Triggers

| Trigger | Description |
|---------|-------------|
| Git Push | Automatic on commits to watched branch |
| Manual Deploy | CLI or dashboard button |
| API Call | Railway API webhook |
| Redeploy | Re-run last successful build |
| Rollback | Deploy previous version |

## Common Patterns

| Pattern | Implementation |
|---------|----------------|
| Multi-environment | Separate environments per branch |
| PR Previews | Auto-create env for each PR |
| Monorepo | Root directory + watch paths |
| Service mesh | Private networking between services |
| Database replicas | Multiple database services |
| Cron jobs | Service with schedule trigger |

## Pricing Tiers

| Tier | Monthly Cost | Included Credits | Limits | Use Case |
|------|--------------|------------------|--------|----------|
| Free | $5 trial then $1/mo | $5 one-time trial | 512MB RAM, 1 vCPU | Experimentation |
| Hobby | $5 | $5 usage credits | 8GB RAM, 8 vCPU | Personal projects |
| Pro | $20 | $20 usage credits | 8GB RAM, 8 vCPU | Production apps |
| Enterprise | Custom | Custom credits | Custom | Large scale |

*All workloads run on Railway Metal (owned hardware with NVMe SSDs)*
