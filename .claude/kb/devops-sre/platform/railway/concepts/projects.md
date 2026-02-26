# Projects

> **Purpose**: Top-level organizational unit that contains services, databases, and environments
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

A Railway project is the top-level container for your application infrastructure. It groups related services (your applications), databases, and environments together. Projects provide isolation, resource organization, and access control boundaries. Think of a project as a workspace for a complete application or product.

## The Pattern

```bash
# Create new project via CLI
railway init

# Link existing directory to project
railway link

# Switch between projects
railway project select
```

## Project Components

| Component | Purpose | Example |
|-----------|---------|---------|
| **Services** | Deployable applications | API server, frontend app |
| **Databases** | Managed data stores | PostgreSQL, Redis, MongoDB |
| **Environments** | Isolated contexts | production, staging, development |
| **Variables** | Shared configuration | API keys, feature flags |
| **Settings** | Project-level config | Team access, billing |

## Project Structure Example

```
Project: E-commerce Platform
├── Services
│   ├── api-service (Node.js backend)
│   ├── web-app (React frontend)
│   └── worker-service (Background jobs)
├── Databases
│   ├── postgres (Primary database)
│   └── redis (Cache and sessions)
└── Environments
    ├── production
    ├── staging
    └── pr-* (Preview environments)
```

## Creating Projects

### Via Dashboard
1. Login to railway.app
2. Click "New Project"
3. Choose source: GitHub repo, template, or empty project
4. Configure services and databases

### Via CLI
```bash
# Initialize in current directory
railway init

# Select existing project
railway link

# Create with specific name
railway init --name "my-project"
```

## Project Settings

| Setting | Description |
|---------|-------------|
| **Name** | Human-readable project identifier |
| **Team** | Access control and collaboration |
| **Region** | Deployment region (us-west1, eu-west1, etc.) |
| **Preferred Region** | Set preferred deployment region per project (Mar 2025+) |
| **Default Environment** | Environment used by CLI |
| **Danger Zone** | Delete project |

## Multi-Project Patterns

### Microservices per Project
```
Project: User Service
├── user-api
└── user-db

Project: Order Service
├── order-api
└── order-db
```

### Monorepo Single Project
```
Project: Monorepo App
├── Service: API (root: /api)
├── Service: Web (root: /web)
├── Service: Worker (root: /worker)
└── Database: Shared Postgres
```

## Best Practices

1. **One Project per Application**: Keep related services together
2. **Use Environments**: Don't create separate projects for staging/production
3. **Shared Variables**: Use project-level variables for common config
4. **Logical Naming**: Use clear, descriptive project names
5. **Team Access**: Configure team permissions at project level

## Common Mistakes

### Wrong: Too Many Projects
```
❌ MyApp-API-Production
❌ MyApp-API-Staging
❌ MyApp-Web-Production
❌ MyApp-Web-Staging
```

### Correct: Use Environments
```
✅ MyApp
   ├── Environments: production, staging
   └── Services: API, Web
```

## Resource Limits

Projects inherit resource limits from your Railway plan:
- **Free**: $5 one-time trial credits, then $1/month (512MB RAM, 1 vCPU)
- **Hobby**: $5/month + $5 usage credits (8GB RAM, 8 vCPU)
- **Pro**: $20/month + $20 usage credits (8GB RAM, 8 vCPU)
- **Enterprise**: Custom allocation

All services, databases, and deployments within a project consume from the project's credit pool. All workloads run on Railway Metal infrastructure.

## Related

- [services](../concepts/services.md)
- [environments](../concepts/environments.md)
- [variables](../concepts/variables.md)
