# Railway Config

> **Purpose**: Configuration as code using railway.json or railway.toml files
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Railway supports defining deployment configuration alongside your code using `railway.json` or `railway.toml` files. Config-as-code enables version control of build and deploy settings, ensures consistency across environments, and allows team collaboration on infrastructure configuration. Configuration defined in code always overrides dashboard settings.

## The Pattern

### railway.json
```json
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "NIXPACKS",
    "buildCommand": "npm run build",
    "watchPatterns": ["src/**", "package.json"]
  },
  "deploy": {
    "startCommand": "npm start",
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 10,
    "healthcheckPath": "/health",
    "healthcheckTimeout": 300
  }
}
```

### railway.toml
```toml
[build]
builder = "NIXPACKS"
buildCommand = "npm run build"
watchPatterns = ["src/**", "package.json"]

[deploy]
startCommand = "npm start"
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 10
healthcheckPath = "/health"
healthcheckTimeout = 300
```

## File Location

Railway looks for config files at project root:

```
my-project/
├── railway.json    ← Detected here
├── package.json
└── src/

monorepo/
├── api/
│   ├── railway.toml    ← Must specify path in service settings
│   └── package.json
└── web/
    ├── railway.toml
    └── package.json
```

For monorepos, set **Root Directory** in service settings: `/api`

## Build Configuration

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `builder` | string | Build method | `NIXPACKS`, `DOCKERFILE` |
| `buildCommand` | string | Custom build command | `npm run build` |
| `dockerfilePath` | string | Dockerfile location | `./docker/Dockerfile` |
| `watchPatterns` | array | Files triggering rebuilds | `["src/**"]` |

### Builder Options

```json
{
  "build": {
    "builder": "NIXPACKS"  // Auto-detect language and build
  }
}
```

```json
{
  "build": {
    "builder": "DOCKERFILE",
    "dockerfilePath": "./Dockerfile.prod"
  }
}
```

## Deploy Configuration

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `startCommand` | string | Override start command | `node dist/index.js` |
| `restartPolicyType` | string | When to restart | `ON_FAILURE`, `ALWAYS`, `NEVER` |
| `restartPolicyMaxRetries` | number | Max restart attempts | `10` |
| `healthcheckPath` | string | Health check endpoint | `/health` |
| `healthcheckTimeout` | number | Health check timeout (sec) | `300` |
| `numReplicas` | number | Horizontal scaling | `2` (Pro+) |

### Restart Policies

```json
{
  "deploy": {
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 10
  }
}
```

| Policy | Behavior |
|--------|----------|
| `ON_FAILURE` | Restart if container exits with error |
| `ALWAYS` | Always restart (even on success) |
| `NEVER` | No automatic restarts |

## Monorepo Configuration

Set **Root Directory** per service. Use `watchPatterns` to limit rebuilds. See [monorepo-handling](../patterns/monorepo-handling.md) for full patterns.

## Environment-Specific Config

Config files apply to all environments but can reference env variables: `"startCommand": "npm run start:${RAILWAY_ENVIRONMENT}"`.

## Priority Order

1. Railway defaults < 2. Dashboard settings < 3. **railway.json/railway.toml** (highest priority)

## Best Practices

1. **Version Control**: Always commit railway.json/railway.toml
2. **Use Schema**: Include `$schema` for validation
3. **Watch Patterns**: Limit to relevant files to avoid unnecessary rebuilds
4. **Health Checks**: Always define healthcheck for web services
5. **Restart Policy**: Use `ON_FAILURE` for most services

## Related

- [services](../concepts/services.md)
- [deployments](../concepts/deployments.md)
- [monorepo-handling](../patterns/monorepo-handling.md)
