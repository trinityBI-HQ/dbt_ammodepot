# Deployments

> **Purpose**: Immutable builds representing a specific version of a service
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

A deployment is an immutable build and runtime instance of your service running on Railway Metal infrastructure (owned hardware with NVMe SSDs, more powerful CPUs, and direct ISP peering). Each deployment represents a specific version of your code, configuration, and dependencies. Railway creates a new deployment whenever code changes are detected, manual deployments are triggered, or configuration is updated. Metal infrastructure enables faster builds, quicker incident recovery, and improved performance.

## The Pattern

```bash
# Trigger deployment from CLI
railway up

# View deployment logs
railway logs

# Check deployment status
railway status

# Rollback to previous deployment (via dashboard)
```

## Deployment Lifecycle

```
Queued → Building → Deploying → Active
   ↓         ↓          ↓          ↓
Canceled  Failed    Failed    Removed/Replaced
```

| State | Description |
|-------|-------------|
| **Queued** | Waiting for build resources |
| **Building** | Creating container image |
| **Deploying** | Starting container and running health checks |
| **Active** | Serving traffic |
| **Failed** | Build or deploy error occurred |
| **Removed** | Replaced by newer deployment |

## Deployment Triggers

### Automatic (GitHub)
```yaml
# Triggers on:
- Git push to watched branch (main, develop, etc.)
- PR opened/updated (creates preview environment)
- Tag pushed (if configured)
```

### Manual
```bash
# CLI deployment
railway up

# Dashboard: Click "Deploy" button

# API webhook
curl -X POST https://backboard.railway.app/graphql/v2 \
  -H "Authorization: Bearer $RAILWAY_TOKEN" \
  -d '{"query":"mutation { deploymentTrigger(...) }"}'
```

### Configuration Change
Environment variable updates, build/deploy settings changes, or railway.json/railway.toml modifications also trigger new deployments.

## Build Process

### Nixpacks (Auto-detect)
```
1. Detect language and framework
2. Install dependencies (npm install, pip install, etc.)
3. Run build command (if specified)
4. Create optimized container
5. Set default start command
```

### Dockerfile
Railway also supports custom Dockerfiles for build control (see [railway-config](../concepts/railway-config.md)).

## Deployment Variables

Railway injects deployment metadata:

```javascript
process.env.RAILWAY_DEPLOYMENT_ID      // Unique deployment ID
process.env.RAILWAY_ENVIRONMENT        // production, staging, etc.
process.env.RAILWAY_GIT_COMMIT_SHA     // Git commit hash
process.env.RAILWAY_GIT_BRANCH         // Git branch name
process.env.RAILWAY_GIT_AUTHOR         // Commit author
process.env.RAILWAY_SERVICE_NAME       // Service name
```

## Health Checks

Railway validates deployment health before routing traffic. Configure via `railway.json` (see [railway-config](../concepts/railway-config.md) for full options).

```javascript
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy' });
});
```

## Rollback Pattern

```
Current: Deployment #47 (Active)
         Deployment #46 (Removed)
         Deployment #45 (Removed)

Rollback → Click "Redeploy" on #46

Result:  Deployment #48 (Active, from #46 source)
         Deployment #47 (Removed)
```

Rollbacks create a new deployment using the source from a previous successful deployment.

## Deployment Logs

```bash
# Stream live logs
railway logs

# Filter by deployment
railway logs --deployment <id>

# Export logs
railway logs > deployment.log
```

## Zero-Downtime Deployments

Railway achieves zero-downtime on Metal infrastructure by:
1. Building new deployment while old one runs (NVMe SSDs for faster builds)
2. Starting new container on Metal hardware
3. Running health checks
4. Routing traffic only after health check passes (anycast edge network)
5. Draining connections from old container
6. Terminating old container

Metal benefits: faster incident recovery due to owned hardware, direct ISP peering for lower latency.

## Related

- [services](../concepts/services.md)
- [railway-config](../concepts/railway-config.md)
- [environments](../concepts/environments.md)
