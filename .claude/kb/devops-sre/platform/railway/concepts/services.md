# Services

> **Purpose**: Deployable application units from GitHub, Docker, or templates
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

A service is a deployable unit in Railway that represents a single application or component. Services can be deployed from GitHub repositories, Docker images, templates, or created empty for manual configuration. Each service maintains its own deployment history, logs, variables, and settings. Railway automatically builds, containerizes, and deploys your service when changes are detected.

## The Pattern

```bash
# Deploy current directory as service
railway up

# Add service to existing project
# (via dashboard: + New → GitHub Repo / Docker Image / Empty Service)

# View service logs
railway logs

# Check service status
railway status
```

## Service Sources

| Source | Trigger | Use Case |
|--------|---------|----------|
| **GitHub Repo** | Git push | Continuous deployment from code |
| **Docker Image** | Registry update | Pre-built containers |
| **Template** | One-click | Quick start apps (Redis, Postgres, n8n) |
| **Empty** | Manual config | Custom setups, cron jobs |

## Service Configuration

### Build Settings
```json
{
  "build": {
    "builder": "NIXPACKS",  // or DOCKERFILE
    "buildCommand": "npm run build",
    "watchPatterns": ["src/**", "package.json"]
  }
}
```

Deploy settings (`startCommand`, `restartPolicyType`, `healthcheckPath`) are configured in `railway.json` (see [railway-config](../concepts/railway-config.md)).

## Builders

| Builder | Description | Detected From |
|---------|-------------|---------------|
| **Nixpacks** | Auto-detect and build | Language-specific files (package.json, requirements.txt) |
| **Dockerfile** | Custom build | Dockerfile in root or specified path |
| **Custom** | Build script | Custom buildCommand |

## Service Types

### Web Service
```javascript
// Listens on a port, receives HTTP traffic
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => res.send('Hello Railway'));
app.listen(PORT, () => console.log(`Server on port ${PORT}`));
```

### Worker Service
Background job processor (no port binding). Uses Celery, Bull, or similar with Redis/database queue.

### Cron Service
Scheduled task with no port binding. Runs on interval or cron schedule.

## Service Variables

Each service has isolated environment variables:

```bash
# Set service-specific variable
railway variables set DATABASE_URL=postgresql://...

# Reference other service
API_URL=${{api-service.RAILWAY_PUBLIC_DOMAIN}}
```

## Service Networking

### Public Domain
```
https://myapp-production.up.railway.app
```
- Automatically generated
- Custom domains can be added
- Automatic SSL via Let's Encrypt
- **Static inbound IPs** available on Metal for firewall allowlisting

### Private Domain
```
myservice.railway.internal:3000
```
- Service-to-service communication
- No egress costs
- Not accessible from internet
- Routed via **anycast edge network** on Metal

## Service Settings

| Setting | Purpose |
|---------|---------|
| **Root Directory** | Monorepo subdirectory path |
| **Watch Paths** | Files that trigger rebuilds |
| **Build Command** | Custom build step |
| **Start Command** | Override default start |
| **Healthcheck** | Endpoint for health validation |
| **Replicas** | Horizontal scaling (Pro+) |
| **Resources** | CPU/Memory limits |
| **HA Volumes** | High-availability persistent volumes (Metal) |

## Deployment Flow

```
Code Change → Git Push → Railway Detects Change
                              ↓
                         Build Image (Nixpacks/Dockerfile)
                              ↓
                         Run Tests (if configured)
                              ↓
                         Deploy Container
                              ↓
                         Health Check
                              ↓
                         Route Traffic
```


## Related

- [deployments](../concepts/deployments.md)
- [railway-config](../concepts/railway-config.md)
- [variables](../concepts/variables.md)
