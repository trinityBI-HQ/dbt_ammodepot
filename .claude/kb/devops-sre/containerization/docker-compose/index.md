# Docker Compose Knowledge Base

> **Purpose**: Define and run multi-container Docker applications using declarative YAML configuration
> **MCP Validated**: 2026-02-19

## Quick Navigation

### Concepts (< 150 lines each)

| File | Purpose |
|------|---------|
| [concepts/services.md](concepts/services.md) | Service definitions, images, build context |
| [concepts/networking.md](concepts/networking.md) | Networks, DNS, service discovery |
| [concepts/volumes.md](concepts/volumes.md) | Named volumes, bind mounts, tmpfs |
| [concepts/compose-file.md](concepts/compose-file.md) | File structure, profiles, extensions, include |
| [concepts/environment.md](concepts/environment.md) | Environment variables, .env files, secrets |
| [concepts/lifecycle.md](concepts/lifecycle.md) | depends_on, healthchecks, restart policies |

### Patterns (< 200 lines each)

| File | Purpose |
|------|---------|
| [patterns/development-workflow.md](patterns/development-workflow.md) | Hot reload, watch mode, debugging |
| [patterns/multi-environment.md](patterns/multi-environment.md) | Dev/staging/prod overrides |
| [patterns/production-deployment.md](patterns/production-deployment.md) | Resource limits, security, logging |
| [patterns/database-services.md](patterns/database-services.md) | Database + app patterns, init scripts |

---

## Quick Reference

- [quick-reference.md](quick-reference.md) - Fast lookup tables

---

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Compose Specification** | Declarative format replacing legacy v2/v3 versioned files |
| **Services** | Containers defined by image or build context with configuration |
| **Networks** | Automatic DNS-based service discovery between containers |
| **Volumes** | Persistent and shared storage for container data |
| **Profiles** | Selectively enable services for different workflows |
| **Watch** | File sync and auto-rebuild for development workflows |
| **Models (2025+)** | AI models as first-class top-level section with OCI model access |
| **K8s Conversion (v2.40+)** | Convert Compose files to Kubernetes manifests |

---

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/services.md, concepts/compose-file.md |
| **Intermediate** | concepts/networking.md, concepts/volumes.md, concepts/lifecycle.md |
| **Advanced** | patterns/production-deployment.md, patterns/multi-environment.md |

---

## Agent Usage

| Agent | Primary Files | Use Case |
|-------|---------------|----------|
| ci-cd-specialist | patterns/production-deployment.md | CI/CD container orchestration |
| infra-deployer | patterns/multi-environment.md | Multi-environment deployments |
| python-developer | patterns/development-workflow.md | Local development setup |
