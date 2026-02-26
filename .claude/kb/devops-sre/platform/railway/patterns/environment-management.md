# Environment Management

> **MCP Validated**: 2026-02-19

## Overview

Railway environments enable isolated deployment contexts for production, staging, development, and ephemeral PR previews. Effective environment management involves strategic variable scoping, environment promotion workflows, and resource cost control. This pattern covers multi-environment strategies for teams and solo developers.

## Three-Tier Environment Strategy

### Structure
```
Project: Production App
├── production (main branch)
│   ├── api-service
│   ├── web-app
│   └── postgres
├── staging (develop branch)
│   ├── api-service
│   ├── web-app
│   └── postgres (separate instance)
└── development (feature branches)
    ├── api-service
    └── web-app (shares staging DB)
```

### Branch Mapping
```toml
# railway.toml (conceptual - configure via dashboard)
[environments.production]
branch = "main"
auto_deploy = true

[environments.staging]
branch = "develop"
auto_deploy = true

[environments.development]
branch = "feature/*"
auto_deploy = false  # Manual deploys
```

## Variable Scoping Strategy

- **Shared** (Project Settings): LOG_LEVEL, REGION, APP_NAME
- **Production**: NODE_ENV=production, DEBUG=false, live API keys
- **Staging**: NODE_ENV=staging, DEBUG=true, test API keys
- **Development**: NODE_ENV=development, DEBUG=true, test API keys

## Service-to-Service Variable References

Use `${{service.RAILWAY_PRIVATE_DOMAIN}}` for inter-service references. Resolves to environment-specific instances automatically.

## Database Strategy

- **Production**: Isolated database, persistent, backed up (HA volumes on Metal)
- **Staging**: Isolated database, periodically reset
- **Development/PR**: Shared database or ephemeral per PR. Reference via `${{postgres-NAME.DATABASE_PRIVATE_URL}}`

## PR Preview Environment Pattern

Enable via Project Settings -> Environments -> PR Previews. Inherits staging config, auto-deploys on PR push, auto-cleanup on close (configurable inactivity threshold).

## Environment Promotion Workflow

Feature branch -> develop (auto-deploy staging) -> main (auto-deploy production). Test at each stage. Use `railway dev` for local testing before push.

## Environment-Specific Configuration

Load config based on `RAILWAY_ENVIRONMENT`: `require('dotenv').config({ path: '.env.${env}' })`.

## Resource Allocation

Production: ~60% of credits (HA, replicas). Staging: ~20%. Development/PR: ~20% with auto-cleanup. Enable auto-delete on PR close to control costs.

## Feature Flags

Use `RAILWAY_ENVIRONMENT` to toggle features per environment. Enable beta features in staging/development, disable in production.

## Health Checks

Include environment info in health endpoint: `RAILWAY_ENVIRONMENT`, `RAILWAY_DEPLOYMENT_ID`, `RAILWAY_GIT_COMMIT_SHA`, database connectivity check.

## Best Practices

1. **Three Tiers Minimum**: production, staging, development
2. **Separate Databases**: Isolate production data completely
3. **Variable Parity**: Use same variable names across environments
4. **Auto PR Previews**: Enable for faster review cycles
5. **Auto-Cleanup**: Configure PR preview cleanup to control costs
6. **Private Networking**: Use RAILWAY_PRIVATE_DOMAIN for service references
7. **Monitoring**: Different alerting thresholds per environment
8. **Deployment Flow**: Always test in staging before production

## Related

- [environments](../concepts/environments.md)
- [variables](../concepts/variables.md)
- [deployment-strategies](../patterns/deployment-strategies.md)
