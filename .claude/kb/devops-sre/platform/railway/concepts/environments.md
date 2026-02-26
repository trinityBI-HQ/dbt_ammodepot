# Environments

> **Purpose**: Isolated deployment contexts for production, staging, and preview workflows
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Environments in Railway provide isolated contexts for deploying and testing your applications. Each environment has its own set of deployments, variables, and configurations while sharing the same services and project structure. Environments enable safe development workflows by separating production, staging, and ephemeral preview environments for pull requests.

## The Pattern

```bash
# List environments
railway environment

# Switch environment
railway environment production

# Deploy to specific environment
railway up --environment staging

# View environment variables
railway variables --environment production
```

## Environment Types

| Type | Purpose | Lifetime |
|------|---------|----------|
| **Production** | Live application serving users | Permanent |
| **Staging** | Pre-production testing | Permanent |
| **Development** | Developer testing | Permanent |
| **PR Preview** | Pull request testing | Ephemeral (deleted with PR) |

## Environment Structure

```
Project: E-commerce App
├── production
│   ├── api-service (v2.5.0)
│   ├── web-app (v2.5.0)
│   └── postgres (shared)
├── staging
│   ├── api-service (v2.6.0-beta)
│   ├── web-app (v2.6.0-beta)
│   └── postgres (separate)
└── pr-#123-new-checkout
    ├── api-service (pr-branch)
    └── web-app (pr-branch)
```

## Creating Environments

Via dashboard (New Environment -> empty, fork, or PR preview) or CLI:
```bash
railway environment create staging
railway environment create staging --from production  # Fork
```

## Environment Variables

Variables scoped per environment. See [variables](../concepts/variables.md) for full details.
- **Project-level**: Shared across all environments (LOG_LEVEL, REGION)
- **Environment-specific**: Different values per environment (API_KEY, DEBUG)

## PR Preview Environments

Auto-created for each pull request via GitHub integration. Preview URL (`https://myapp-pr-123.up.railway.app`) posted as PR comment. Auto-cleanup on PR close.

## Environment Promotion

Test in staging, verify, then promote to production. See [environment-management](../patterns/environment-management.md) for full promotion workflows.

## Environment Isolation

Each environment has isolated:

| Resource | Isolation Level |
|----------|----------------|
| **Deployments** | Completely separate |
| **Variables** | Separate + shared variables |
| **Domains** | Unique URLs per environment |
| **Logs** | Separate log streams |
| **Metrics** | Individual resource tracking |

### Shared Resources
- Project settings
- Service definitions
- Database schemas (if using same DB)
- Team access

## Branch Mapping

Map Git branches to environments: `main` -> production, `develop` -> staging, `pr/*` -> preview. Configure via dashboard or `railway.toml`.

## Resource Management

Each environment consumes project credits independently. Control costs by enabling auto-cleanup for PR previews.

## Environment Best Practices

1. **Naming Convention**: Use clear names (production, staging, not prod1, prod2)
2. **Variable Parity**: Keep same variable names across environments
3. **Auto-cleanup**: Enable PR preview cleanup after merge
4. **Database Isolation**: Use separate databases per environment
5. **Cost Control**: Monitor preview environment resource usage

## Common Patterns

- **Three-Stage**: development -> staging -> production
- **Preview-First**: PR preview -> QA testing -> merge to staging -> production

## Related

- [projects](../concepts/projects.md)
- [deployments](../concepts/deployments.md)
- [variables](../concepts/variables.md)
