# Deployment Strategies

> **MCP Validated**: 2026-02-19

## Overview

Railway supports multiple deployment strategies on Metal infrastructure (owned hardware, NVMe SSDs, anycast edge network): automatic GitHub deployments, manual CLI deployments, Docker image deployments, and API-triggered deployments. All workloads run on Railway Metal since June 2025. Use `railway dev` for local development with TUI before deploying.

## GitHub Auto-Deploy

### Pattern
```yaml
# Automatic deployment on git push
1. Connect GitHub repository to Railway
2. Select branch (main, develop, etc.)
3. Railway watches for commits
4. Auto-deploy on push to watched branch
```

### Configuration
```
Service Settings → Source → GitHub
├── Repository: username/repo-name
├── Branch: main
└── Root Directory: / (or /api for monorepo)
```

### Watch Patterns
```json
// railway.json
{
  "build": {
    "watchPatterns": [
      "src/**",
      "package.json",
      "package-lock.json"
    ]
  }
}
```

Only triggers rebuild when files matching patterns change.

### Branch Strategy
```
main → production environment
develop → staging environment
feature/* → PR preview environments
```

## CLI Deployment

### Pattern
```bash
# Manual deployment via CLI
railway login
railway link
railway up

# Deploy specific environment
railway up --environment production

# Deploy specific service
railway up --service api
```

### Use Cases
- Local development testing
- Manual production deployments
- CI/CD pipelines without GitHub integration
- Deployment from private repos

### CI/CD Integration
```yaml
# GitHub Actions
name: Deploy
on:
  workflow_dispatch:  # Manual trigger

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install Railway
        run: npm install -g @railway/cli
      - name: Deploy
        run: railway up --environment production
        env:
          RAILWAY_TOKEN: ${{ secrets.RAILWAY_TOKEN }}
```

## Docker Image Deployment

### Pattern
Deploy pre-built Docker images from any registry (Docker Hub, GHCR, etc.). Configure via Service Settings -> Source -> Docker Image with registry, image name, and tag. Automate with GitHub Actions: build, push to registry, then `railway service update --image <image:tag>`.

## Template Deployment

One-click deployment from Railway templates. Browse templates, click "Deploy", fork or use as-is. Auto-provisions services and databases. Use cases: quick starts (Next.js, FastAPI), multi-service stacks, reference architectures.

## API-Triggered Deployment

Trigger deployments via Railway GraphQL API at `https://backboard.railway.app/graphql/v2` with `RAILWAY_TOKEN`. Use cases: external CI/CD systems, scheduled deployments, webhook integrations, custom deployment logic.

## Blue-Green Deployment

Deploy new version to staging, run smoke tests, promote to production if tests pass. Keep old version for instant rollback via dashboard "Redeploy" on previous version.

## Canary Deployment (Pro Plan)

Use `numReplicas` with canary settings in `railway.json` to gradually shift traffic to new deployments while monitoring metrics.

## Zero-Downtime Strategy (Metal)

Railway automatically implements zero-downtime on Metal infrastructure:

```
1. New deployment starts building (NVMe SSDs for fast builds)
2. Old deployment continues serving traffic
3. New deployment passes health check
4. Traffic routes to new deployment (anycast edge network)
5. Old deployment drains connections
6. Old deployment terminates
```

Metal benefits: faster builds on NVMe SSDs, lower latency via direct ISP peering, faster incident recovery on owned hardware.

### Health Check Configuration
```json
{
  "deploy": {
    "healthcheckPath": "/health",
    "healthcheckTimeout": 300,
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 10
  }
}
```

## Rollback Strategy

Via dashboard: Service -> Deployments -> Click "Redeploy" on previous version. Creates new deployment from old source. Via CLI: `git checkout <previous-commit> && railway up`.

## Environment Promotion

### Pattern
```
PR → Preview → Staging → Production
```

### Implementation
PR creates preview (automatic via GitHub integration). Merge to develop -> staging auto-deploy. Merge to main -> production auto-deploy.

## Best Practices

1. **Use GitHub Integration**: Automatic deployments for most projects
2. **Health Checks**: Always configure health checks for zero-downtime
3. **Watch Patterns**: Limit to relevant files to avoid unnecessary builds
4. **Environment Strategy**: Use environments, not separate projects
5. **Rollback Ready**: Test rollback procedure in staging
6. **Monitor Deployments**: Use Railway logs to verify successful deployments
7. **Gradual Rollout**: Use PR previews → staging → production flow

## Comparison Matrix

| Strategy | Automation | Control | Use Case |
|----------|------------|---------|----------|
| **GitHub Auto** | High | Low | Standard workflows |
| **CLI Deploy** | Low | High | Manual control, custom CI/CD |
| **Docker Image** | Medium | Medium | Pre-built images |
| **API Triggered** | Medium | High | Custom integrations |
| **Template** | High | Low | Quick starts |

## Related

- [deployments](../concepts/deployments.md)
- [cli](../concepts/cli.md)
- [environments](../concepts/environments.md)
