# Railway Knowledge Base

> **Purpose**: Modern cloud deployment platform on owned Metal infrastructure with automatic deployments, managed databases, and zero-configuration setup
> **MCP Validated**: 2026-02-19

## Quick Navigation

### Concepts (< 150 lines each)

| File | Purpose |
|------|---------|
| [concepts/projects.md](concepts/projects.md) | Organizational units containing services and environments |
| [concepts/services.md](concepts/services.md) | Deployable units from GitHub, Docker, or templates |
| [concepts/deployments.md](concepts/deployments.md) | Build and runtime execution of service versions |
| [concepts/environments.md](concepts/environments.md) | Isolated deployment contexts (production, staging, preview) |
| [concepts/databases.md](concepts/databases.md) | Managed Postgres, MySQL, MongoDB, Redis provisioning |
| [concepts/railway-config.md](concepts/railway-config.md) | railway.json and railway.toml configuration files |
| [concepts/cli.md](concepts/cli.md) | Railway CLI for local development and deployment |
| [concepts/variables.md](concepts/variables.md) | Environment variables and secrets management |

### Patterns (< 200 lines each)

| File | Purpose |
|------|---------|
| [patterns/deployment-strategies.md](patterns/deployment-strategies.md) | GitHub auto-deploy, CLI deploy, Docker deploy strategies |
| [patterns/database-setup.md](patterns/database-setup.md) | Provisioning and connecting to managed databases |
| [patterns/monorepo-handling.md](patterns/monorepo-handling.md) | Deploying multiple services from monorepo structure |
| [patterns/environment-management.md](patterns/environment-management.md) | Multi-environment setup with variable scoping |
| [patterns/custom-domains.md](patterns/custom-domains.md) | Custom domain configuration with automatic SSL |
| [patterns/private-networking.md](patterns/private-networking.md) | Service-to-service communication via private network |

---

## Quick Reference

- [quick-reference.md](quick-reference.md) - Fast lookup tables

---

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Projects** | Top-level container for services, databases, and environments |
| **Services** | Deployable applications from GitHub, Docker, or templates |
| **Deployments** | Immutable builds triggered by code changes or manual actions |
| **Environments** | Isolated contexts (production, staging, PR previews) |
| **Databases** | One-click Postgres, MySQL, MongoDB, Redis provisioning |
| **Variables** | Environment-specific configuration and secrets |
| **Private Network** | Internal service-to-service communication |
| **Railway Metal** | Owned hardware with NVMe SSDs, static IPs, anycast edge network |
| **Config as Code** | railway.json/railway.toml for deployment configuration |

---

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/projects.md, concepts/services.md, concepts/deployments.md |
| **Intermediate** | concepts/variables.md, patterns/deployment-strategies.md, patterns/database-setup.md |
| **Advanced** | patterns/monorepo-handling.md, patterns/private-networking.md, concepts/railway-config.md |

---

## Agent Usage

| Agent | Primary Files | Use Case |
|-------|---------------|----------|
| devops-engineer | patterns/deployment-strategies.md, patterns/environment-management.md | Setup CI/CD and multi-env |
| backend-developer | concepts/databases.md, patterns/database-setup.md, patterns/private-networking.md | Build services with databases |
| infra-engineer | concepts/railway-config.md, patterns/monorepo-handling.md | Configure complex deployments |

---

## Project Context

This KB supports cloud deployment workflows using Railway:
- Railway Metal: owned infrastructure with NVMe SSDs, faster CPUs, direct ISP peering
- Zero-configuration deployments from GitHub repositories
- Automatic Docker containerization with Nixpacks or Dockerfiles
- Managed database provisioning with high-availability volumes
- Static inbound IPs and anycast edge network (Metal)
- Environment variables and secrets management
- Custom domains with automatic SSL certificate provisioning
- Private networking for secure service-to-service communication
- Monorepo support with selective build paths
- PR preview environments for testing
- Local development with `railway dev` TUI (tabbed multi-service runner)
- Pricing: Free ($5 trial then $1/mo), Hobby ($5/mo), Pro ($20/mo), Enterprise
