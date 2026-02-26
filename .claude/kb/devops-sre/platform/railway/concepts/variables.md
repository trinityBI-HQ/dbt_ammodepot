# Variables

> **Purpose**: Environment variables and secrets management with scoping and references
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Railway variables provide a secure way to manage configuration and secrets across services and environments. Variables are injected as environment variables during both build and runtime. Railway supports service-specific variables, shared variables across services, environment scoping, and service-to-service variable references. Variables can be marked as sealed to prevent viewing via UI or API.

## The Pattern

```bash
# Set variable via CLI
railway variables set API_KEY=abc123

# Set via dashboard
# Service → Variables → New Variable

# Access in code
const apiKey = process.env.API_KEY;
```

## Variable Scopes

| Scope | Description | Use Case |
|-------|-------------|----------|
| **Service** | Single service only | Service-specific API keys |
| **Shared** | All services in project | Common configuration |
| **Environment** | Per environment | Production vs staging secrets |

### Service Variables
```bash
railway variables set DATABASE_URL=postgresql://...
railway variables set --service api API_KEY=abc123
```

### Shared Variables
Set via Project Settings -> Shared Variables. Available to all services (REGION, LOG_LEVEL, feature flags).

### Environment Variables
```bash
railway variables set --environment production API_KEY=prod_key
railway variables set --environment staging API_KEY=stage_key
```

## Variable References

Reference variables from other services:

```bash
# Reference service's public domain
API_URL=${{api-service.RAILWAY_PUBLIC_DOMAIN}}

# Reference service's private domain
API_URL=${{api-service.RAILWAY_PRIVATE_DOMAIN}}

# Reference custom variable
DB_HOST=${{postgres.HOST}}
```

### Reference Syntax
```
${{service-name.VARIABLE_NAME}}
```

### Example: Frontend → Backend
```bash
# Backend service automatically has:
RAILWAY_PUBLIC_DOMAIN=backend-prod.up.railway.app
RAILWAY_PRIVATE_DOMAIN=backend.railway.internal

# Frontend service references backend:
NEXT_PUBLIC_API_URL=${{backend.RAILWAY_PUBLIC_DOMAIN}}
# Resolves to: backend-prod.up.railway.app
```

## Railway-Injected Variables

Railway automatically injects system variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `RAILWAY_ENVIRONMENT` | Environment name | `production` |
| `RAILWAY_PROJECT_ID` | Project identifier | `abc123...` |
| `RAILWAY_SERVICE_ID` | Service identifier | `def456...` |
| `RAILWAY_SERVICE_NAME` | Service name | `api` |
| `RAILWAY_PUBLIC_DOMAIN` | Public URL | `api.up.railway.app` |
| `RAILWAY_PRIVATE_DOMAIN` | Private network URL | `api.railway.internal` |
| `RAILWAY_GIT_COMMIT_SHA` | Git commit hash | `a1b2c3d...` |
| `RAILWAY_GIT_BRANCH` | Git branch | `main` |
| `RAILWAY_DEPLOYMENT_ID` | Deployment ID | `xyz789...` |

## Database Variables

Auto-created when provisioned. Each database gets public (`*_URL`) and private (`*_PRIVATE_URL`) connection strings. Always prefer private URLs for zero egress cost.

## Sealed Variables

Seal via dashboard (Service -> Variables -> Seal). Once sealed, value cannot be viewed, only overwritten or deleted. Use for production secrets, API keys, private keys.

## Variable Precedence

Service-specific > Shared > Railway-injected. Upload `.env` files: `railway variables set --from .env`.

## Variable Management Best Practices

1. **Use Private URLs**: Reference services via RAILWAY_PRIVATE_DOMAIN for zero egress costs
2. **Seal Secrets**: Mark production secrets as sealed
3. **Environment Parity**: Use same variable names across environments
4. **Service References**: Use variable references instead of hardcoding URLs
5. **Don't Commit Secrets**: Never commit .env files with real secrets

## Common Patterns

- **Multi-service**: `DATABASE_URL=${{database.DATABASE_PRIVATE_URL}}` (same for API and workers)
- **Frontend-Backend**: `API_URL=https://${{backend.RAILWAY_PUBLIC_DOMAIN}}` (public) or `http://${{backend.RAILWAY_PRIVATE_DOMAIN}}:3000` (private)
- **Environment-specific**: Same variable names, different values per environment

## Debugging Variables

```bash
railway variables                    # List all
railway run env | grep API_KEY       # Check value locally
railway run bash                     # Shell with variables
```

## Related

- [services](../concepts/services.md)
- [environments](../concepts/environments.md)
- [private-networking](../patterns/private-networking.md)
