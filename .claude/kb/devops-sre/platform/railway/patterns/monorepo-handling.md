# Monorepo Handling

> **MCP Validated**: 2026-02-19

## Overview

Railway supports monorepo deployments where multiple services are deployed from a single repository. This pattern covers two approaches: isolated monorepos (independent services with minimal shared code) and shared monorepos (services with heavy interdependencies). Proper configuration prevents unnecessary rebuilds and optimizes deployment times.

## Isolated Monorepo Pattern

### Structure
```
monorepo/
├── api/
│   ├── railway.json
│   ├── package.json
│   └── src/
├── web/
│   ├── railway.json
│   ├── package.json
│   └── src/
├── worker/
│   ├── railway.json
│   ├── package.json
│   └── src/
└── README.md
```

### Service Configuration

#### API Service
```
Service Settings:
├── Root Directory: /api
└── Watch Patterns: api/**
```

```json
// api/railway.json
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "NIXPACKS",
    "buildCommand": "npm ci && npm run build",
    "watchPatterns": [
      "api/**"
    ]
  },
  "deploy": {
    "startCommand": "node dist/index.js",
    "healthcheckPath": "/health"
  }
}
```

#### Web Service
```
Service Settings:
├── Root Directory: /web
└── Watch Patterns: web/**
```

```json
// web/railway.json
{
  "build": {
    "builder": "NIXPACKS",
    "buildCommand": "npm ci && npm run build",
    "watchPatterns": [
      "web/**"
    ]
  },
  "deploy": {
    "startCommand": "npm start"
  }
}
```

### Benefits
- Changes in `/api` don't trigger `/web` rebuild
- Isolated dependencies per service
- Clear service boundaries
- Faster deployments

## Shared Monorepo Pattern

For packages with shared dependencies, set Root Directory to `/` (repository root) and include shared package watch patterns:
```json
{
  "build": {
    "buildCommand": "npm install && npm run build:api",
    "watchPatterns": ["packages/api/**", "packages/shared/**"]
  },
  "deploy": { "startCommand": "node packages/api/dist/index.js" }
}
```

## Turborepo / Nx Integration

- **Turborepo**: `"buildCommand": "npx turbo run build --filter=api"`
- **Nx**: `"buildCommand": "npx nx build api"`
- Set Root Directory to `/` for both (builds need workspace root access)

## Dockerfile Approach

Use multi-stage builds with Root Directory `/`. Set `"builder": "DOCKERFILE"` and `"dockerfilePath"` in railway.json. Copy root package files and all packages in builder stage, then copy only built artifacts to production stage.

## Watch Patterns Strategy

- **Isolated**: `["api/**"]` -- only that directory triggers rebuild
- **Shared deps**: `["api/**", "packages/shared/**", "package.json"]`
- **Exclude**: `["api/**", "!api/tests/**", "!api/**/*.test.js"]`

## Environment Variables for Monorepo

### Service References
```bash
# API service
API_PORT=3000

# Web service references API
NEXT_PUBLIC_API_URL=https://${{api.RAILWAY_PUBLIC_DOMAIN}}

# Worker references API privately
API_PRIVATE_URL=http://${{api.RAILWAY_PRIVATE_DOMAIN}}:3000
```

## GitHub Actions with Monorepo

Use `dorny/paths-filter` to detect changes per service, then selectively deploy with `railway up --service <name>`.

## Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| All services rebuild | Missing watch patterns | Configure specific watch patterns |
| Can't find shared package | Wrong root directory | Set Root Directory to `/` |
| Dependencies not resolved | Workspace misconfigured | Add `workspaces` to root package.json |

## Best Practices

1. **Isolated When Possible**: Prefer isolated monorepos for simpler deployment
2. **Watch Patterns**: Always configure watch patterns to prevent unnecessary builds
3. **Shared Code**: Use packages for shared code, not relative imports across services
4. **Build Tools**: Use Turborepo or Nx for efficient monorepo builds
5. **Root Directory**: Set Root Directory per service for isolated monorepos
6. **CI/CD**: Implement selective deployment based on changed files
7. **Testing**: Run tests only for changed services

## Related

- [services](../concepts/services.md)
- [railway-config](../concepts/railway-config.md)
- [deployment-strategies](../patterns/deployment-strategies.md)
