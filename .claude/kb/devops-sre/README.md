# DevOps/SRE Knowledge Base

> **Last Updated:** 2026-02-20
> **Maintained By:** Claude Code Lab Team

## Overview

DevOps and Site Reliability Engineering (SRE) focus on automating operations, improving reliability, and building systems that scale. This category covers Infrastructure as Code (IaC), CI/CD, monitoring, and operational excellence.

## Philosophy

**DevOps vs SRE:**
- **DevOps**: Cultural movement emphasizing collaboration between development and operations, automation, and continuous delivery
- **SRE**: Google's approach to operations using software engineering principles to solve operational problems

**Both share core principles:**
- **Automate everything**: Manual toil is the enemy
- **Measure everything**: You can't improve what you don't measure
- **Blameless postmortems**: Learn from failures without blame
- **Service Level Objectives (SLOs)**: Define and track reliability targets

**Avoid:**
- ❌ Manual deployments ("ClickOps")
- ❌ Snowflake servers (unique, undocumented configurations)
- ❌ No monitoring or alerting
- ❌ Hero culture (single person who knows everything)
- ❌ "You build it, you run it" without support

## Categories

### 🏗️ Infrastructure as Code (IaC)

**Technologies:** [Terraform](iac/terraform/), [Terragrunt](iac/terragrunt/)

**What it does:** Define and manage infrastructure using code instead of manual configuration.

**When to use:**
- **Terraform**: Any cloud provider, declarative infrastructure
- **Terragrunt**: Multi-environment management, DRY Terraform configs

**Key capabilities:**
- Version-controlled infrastructure
- Reproducible environments (dev/staging/prod)
- Automated provisioning and teardown
- Change preview before apply (plan)
- State management (track deployed resources)

**Terraform vs Alternatives:**
| Tool | Best For | Pros | Cons |
|------|----------|------|------|
| **Terraform** | Multi-cloud IaC | Cloud-agnostic, large ecosystem | State management complexity |
| **CloudFormation** | AWS-only | Native AWS integration | AWS-locked, YAML verbosity |
| **Pulumi** | Developer-focused | Real programming languages | Smaller community |
| **CDK** | AWS with TypeScript/Python | Familiar languages | AWS-focused |

### 🐍 Python Tooling

**Technologies:** [uv](python-tooling/uv/)

**What it does:** Modern Python package/project management with ultra-fast dependency resolution.

**When to use:**
- **uv**: All Python projects — replaces pip, poetry, pyenv, pipx, virtualenv

**Key capabilities:**
- 10-100x faster than pip for dependency resolution
- Universal lockfile (`uv.lock`) for reproducible builds
- Built-in Python version management (replaces pyenv)
- PEP 723 inline script dependencies
- Cargo-style workspaces for monorepos
- Tool management (replaces pipx)

**uv vs Alternatives:**
| Tool | Best For | Pros | Cons |
|------|----------|------|------|
| **uv** | All Python workflows | Fastest, unified toolchain | Newer ecosystem |
| **pip** | Simple installs | Universal, familiar | No lockfile, slow |
| **poetry** | Library publishing | Mature, good UX | Slower resolution |
| **pipenv** | App dependency mgmt | Lockfile support | Slow, less maintained |
| **pdm** | PEP 582 workflows | Standards-compliant | Smaller community |

### 🚀 Platform Engineering

**Technologies:** [Railway](platform/)

**What it does:** Managed platform for rapid deployment with preview environments and CI/CD.

**When to use:**
- Rapid prototyping and MVP development
- Small teams without dedicated DevOps
- Preview environments for every PR
- Simple deployment workflows

**Key capabilities:**
- Git-based deployments (push to deploy)
- Automatic HTTPS and custom domains
- Integrated databases and services
- Preview environments per branch
- Simple pricing (pay for resources used)

**Railway vs Alternatives:**
| Platform | Best For | Pros | Cons |
|----------|----------|------|------|
| **Railway** | Startups, rapid iteration | Simplest setup, great DX | Less control than AWS/GCP |
| **Vercel** | Frontend/Next.js | Best Next.js experience | Primarily frontend |
| **Render** | Full-stack apps | Simple pricing | Limited customization |
| **Fly.io** | Global edge deployment | Low latency worldwide | Smaller ecosystem |
| **Heroku** | Traditional apps | Mature, simple | Expensive at scale |

### 🔄 CI/CD (Continuous Integration/Deployment)

**Status:** Placeholder - Knowledge base content coming soon

**Why CI/CD?**
Automate testing, building, and deployment to reduce manual errors and increase deployment frequency.

**Categories:**
- **CI (Continuous Integration)**: Automated testing on every commit
- **CD (Continuous Deployment)**: Automated deployment to production
- **CD (Continuous Delivery)**: Automated deployment to staging, manual to production

**Technologies to be added:**
- GitHub Actions
- GitLab CI
- CircleCI
- Jenkins
- Azure DevOps

**Related Technologies:**
- See [iac/terraform/](iac/terraform/) for infrastructure deployment

### 📊 Monitoring & Observability

**Technologies:** [Grafana](monitoring/grafana/), [Prometheus](monitoring/prometheus/)

**What it does:** Collect, store, query, visualize, and alert on metrics, logs, and traces across your infrastructure and applications.

**Three Pillars of Observability:**
1. **Metrics**: Time-series data (CPU, latency, error rates) -- Prometheus + Grafana
2. **Logs**: Event records (structured logging) -- Loki + Grafana
3. **Traces**: Request flow across services (distributed tracing) -- Tempo + Grafana

**When to use:**
- **Prometheus**: Metrics collection, PromQL queries, alerting rules, service discovery, Kubernetes monitoring
- **Grafana**: Dashboarding, alerting, multi-source monitoring (Prometheus, Loki, SQL, CloudWatch)

**Key capabilities:**
- 150+ data source plugins (Prometheus, Loki, Tempo, SQL, CloudWatch)
- Unified alerting with multi-dimensional rules and flexible routing
- Dashboard-as-code via file provisioning, Terraform, and Grafonnet
- LGTM stack (Loki, Grafana, Tempo, Mimir) for full-stack observability

**Grafana vs Alternatives:**
| Tool | Best For | Pros | Cons |
|------|----------|------|------|
| **Grafana** | Multi-source visualization | Open-source, 150+ sources, extensible | Requires setup |
| **Datadog** | All-in-one SaaS | Easy setup, APM + logs + metrics | Expensive at scale |
| **New Relic** | APM-focused | Strong APM, free tier | Complex pricing |
| **Kibana** | Elasticsearch ecosystem | Native ES integration | ES-focused only |

**Technologies to be added:**
- Datadog
- New Relic
- Sentry (error tracking)

**Related Technologies:**
- See [ai-ml/observability/langfuse/](../ai-ml/observability/langfuse/) for LLM observability

### 🔧 Version Control

**Technologies:** [GitHub](version-control/github/)

**What it does:** Cloud-based Git hosting with pull requests, Actions CI/CD, security scanning, and project management.

**When to use:**
- **GitHub**: Repository hosting, PR workflows, CI/CD with Actions, security scanning, project management

**Key capabilities:**
- Pull request code review with merge strategies (merge, squash, rebase)
- GitHub Actions for CI/CD (test, build, deploy, matrix builds)
- Security: Dependabot, code scanning (CodeQL), secret scanning
- Project management with Issues and Projects v2
- Branch protection, CODEOWNERS, rulesets
- GitHub CLI (gh) for full terminal-based workflows

**GitHub vs Alternatives:**
| Platform | Best For | Pros | Cons |
|----------|----------|------|------|
| **GitHub** | Most teams, open-source | Largest ecosystem, Actions, security | Pricing at scale |
| **GitLab** | Self-hosted, DevSecOps | All-in-one platform, self-hosted | Heavier UI |
| **Bitbucket** | Atlassian shops | Jira integration | Smaller community |
| **Azure DevOps** | Microsoft/Enterprise | Azure integration, boards | Complex setup |

**Technologies to be added:**
- GitLab
- Monorepo strategies

### 🐳 Containerization & Orchestration

**Technologies:** [Docker Compose](containerization/docker-compose/), [Kubernetes](containerization/kubernetes/)

**What it does:** Package applications with dependencies for consistent deployment across environments. Orchestrate multi-container applications with declarative configuration.

**When to use:**
- **Docker Compose**: Multi-container local development, service orchestration, CI/CD testing, small-scale production
- **Kubernetes**: Production container orchestration, microservices, auto-scaling, multi-cloud deployments

**Key capabilities:**
- Declarative YAML service definitions
- DNS-based service discovery between containers
- Watch mode for hot-reload development workflows (Compose)
- Auto-scaling, self-healing, rolling updates (Kubernetes)
- RBAC, NetworkPolicies, Pod Security Standards (Kubernetes)
- Helm/Kustomize package management (Kubernetes)

**Docker Compose vs Kubernetes:**
| Tool | Best For | Pros | Cons |
|------|----------|------|------|
| **Docker Compose** | Single-host multi-container | Simple, declarative, built-in | Single host only |
| **Kubernetes** | Production orchestration | Auto-scaling, self-healing, HA | Complex setup |
| **Docker Swarm** | Simple clustering | Built into Docker | Limited ecosystem |
| **Podman Compose** | Rootless containers | Daemonless, compatible | Smaller community |

**Technologies to be added:**
- Docker (containerization fundamentals)
- Helm (Kubernetes package manager)

**Related Technologies:**
- See [cloud/gcp/](../cloud/gcp/) for GKE (Google Kubernetes Engine)

## Decision Frameworks

### IaC Tool Selection

| Scenario | Recommended Tool | Why |
|----------|------------------|-----|
| Multi-cloud infrastructure | **Terraform** | Cloud-agnostic, mature ecosystem |
| AWS-only, TypeScript familiar | **AWS CDK** | Native AWS, familiar language |
| Complex multi-environment | **Terragrunt + Terraform** | DRY configs, environment management |
| Small project, single cloud | **Cloud-native** (CloudFormation, etc.) | Simpler, less abstraction |

### Deployment Platform Selection

| Scenario | Recommended Platform | Why |
|----------|---------------------|-----|
| MVP/prototype | **Railway** | Fastest setup, preview envs |
| Next.js frontend | **Vercel** | Optimized for Next.js |
| Full control needed | **AWS/GCP/Azure** | Maximum flexibility |
| Global edge deployment | **Fly.io** or **Cloudflare Workers** | Low latency worldwide |
| Enterprise compliance | **AWS/GCP/Azure** | Security certifications |

### Monitoring Strategy

| Stage | Focus | Tools |
|-------|-------|-------|
| **Local Dev** | Logs, debugger | Console logs, IDE debugger |
| **CI/CD** | Test results, build time | GitHub Actions logs |
| **Staging** | Integration issues, perf | Lightweight monitoring (Cloud Logging) |
| **Production** | Uptime, errors, latency | Full stack (Datadog, Prometheus, Sentry) |

## Common Patterns

### GitOps Workflow

```
Code Change → Git Push → CI Pipeline (test + build) → CD Pipeline (deploy) → Production
                                ↓                            ↓
                          Automated Tests            Terraform Apply / kubectl
```

**Principles:**
1. Git is the single source of truth
2. All changes via pull requests
3. Automated testing before merge
4. Automated deployment after merge
5. Infrastructure changes also via Git

### Multi-Environment Management with Terragrunt

**Directory structure:**
```
infrastructure/
├── terragrunt.hcl          # Root config
├── dev/
│   └── terragrunt.hcl      # Dev environment
├── staging/
│   └── terragrunt.hcl      # Staging environment
└── prod/
    └── terragrunt.hcl      # Production environment
```

**Benefits:**
- DRY (Don't Repeat Yourself) - shared modules
- Environment-specific variables
- Dependency management across stacks
- Remote state locking

### Blue-Green Deployment

```
Production Traffic → Load Balancer → Blue (current version)
                                   ↘ Green (new version, deployed but not active)

After testing Green:
Production Traffic → Load Balancer → Green (promoted to active)
                                   ↘ Blue (kept for quick rollback)
```

**Benefits:**
- Zero-downtime deployments
- Instant rollback (switch traffic back)
- Test production environment with new version

### Canary Deployment

```
Production Traffic → Load Balancer → 95% to Stable Version
                                   → 5% to Canary Version

Monitor canary metrics (errors, latency). If good, gradually increase to 100%.
```

**When to use:** High-risk changes, large user base, need gradual rollout

## Best Practices

### Infrastructure as Code
✅ Version control all Terraform/CloudFormation
✅ Use modules for reusability
✅ Remote state with locking (S3 + DynamoDB, GCS)
✅ Plan before apply (review changes)
✅ Separate state per environment (dev, staging, prod)
✅ Use `.tfvars` files for variables (don't hardcode)
✅ Tag all resources (environment, owner, cost-center)

### CI/CD
✅ Run tests on every commit
✅ Require passing tests before merge
✅ Automate deployments (no manual steps)
✅ Use preview environments for PRs
✅ Implement rollback mechanisms
✅ Secret management (never hardcode credentials)

### Monitoring
✅ Monitor business metrics, not just infrastructure
✅ Set up alerts with appropriate thresholds
✅ Use structured logging (JSON)
✅ Implement distributed tracing for microservices
✅ Create dashboards for key metrics
✅ Practice alert fatigue prevention (tune alerts)

### Deployments
✅ Immutable infrastructure (rebuild, don't patch)
✅ Automate rollbacks
✅ Deployment checklists for high-risk changes
✅ Off-hours deployments for risky changes (with team available)
✅ Feature flags for gradual rollouts

### Operational Excellence
✅ Blameless postmortems after incidents
✅ Document runbooks for common issues
✅ Regularly test disaster recovery procedures
✅ Set SLOs (Service Level Objectives)
✅ Track error budgets (remaining allowed downtime)
✅ Automate toil (repetitive manual tasks)

## SRE Principles

### Service Level Objectives (SLOs)

**Example SLO:**
- **SLI (Service Level Indicator)**: Request success rate
- **SLO (Service Level Objective)**: 99.9% of requests succeed (measured over 30 days)
- **SLA (Service Level Agreement)**: Customer-facing commitment (usually lower than SLO)

**Error Budget:**
- If SLO is 99.9%, you have 0.1% error budget (43 minutes/month downtime)
- When error budget is exhausted, freeze feature launches and focus on reliability
- When error budget is healthy, take more risks (faster deployments, experiments)

### Toil Reduction

**Toil:** Repetitive, manual operational work with no enduring value

**Examples:**
- Manually deploying code
- Manually provisioning servers
- Manually running database migrations
- Restarting servers when they hang

**Solution:** Automate! If you do it more than twice, automate it.

### On-Call Best Practices

✅ Rotate on-call duties (share the burden)
✅ Maximum alert response time SLO (e.g., 15 minutes)
✅ Alerts should be actionable (not informational)
✅ Runbooks for common alerts
✅ Post-incident reviews (learn and improve)
✅ Limit on-call load (max 2 pages per shift)

## Anti-Patterns

❌ **ClickOps**: Manually creating resources in cloud console → Use Terraform
❌ **Snowflake servers**: Unique configurations per server → Immutable infrastructure
❌ **No rollback plan**: Deploy and pray → Test rollback before deploying
❌ **Alert fatigue**: Too many noisy alerts → Tune thresholds, use alert grouping
❌ **No monitoring**: "It works on my machine" → Monitor production actively
❌ **Manual secrets**: Credentials in code or Slack → Use secrets management
❌ **Long-lived branches**: Feature branches open for weeks → Trunk-based development
❌ **Deployment freezes**: "No deploys on Fridays" → Automate and deploy confidently

## Recommended Learning Path

1. **Fundamentals** (2-3 weeks)
   - Git and GitHub (branching, PRs, merging)
   - Linux command line basics
   - Networking fundamentals (DNS, HTTP, load balancers)

2. **Infrastructure as Code** (2-3 weeks)
   - Terraform basics (resources, variables, outputs)
   - State management (local vs remote)
   - Modules and reusability

3. **CI/CD** (2 weeks)
   - GitHub Actions or GitLab CI setup
   - Automated testing pipelines
   - Deployment automation

4. **Containers** (2 weeks)
   - Docker fundamentals (images, containers, Dockerfiles)
   - Docker Compose for local dev
   - Container registries (Docker Hub, GCR, ECR)

5. **Observability** (2 weeks)
   - Structured logging
   - Metrics and dashboards
   - Alerting best practices

6. **Advanced Topics** (ongoing)
   - Kubernetes (orchestration)
   - Service meshes (Istio, Linkerd)
   - SRE practices (SLOs, error budgets)
   - Incident response

## Related Knowledge

- **Cloud**: See [cloud/](../cloud/) for cloud provider services (GCP, AWS, Azure)
- **Data Engineering**: See [data-engineering/](../data-engineering/) for data pipeline deployment
- **AI/ML**: See [ai-ml/](../ai-ml/) for LLM application deployment

## Agents

Specialized agents for DevOps/SRE tasks:
- `/ci-cd-specialist` - Azure DevOps, Terraform, Databricks Asset Bundles
- `/infra-deployer` - GCP serverless deployment with Terraform/Terragrunt

---

**Automate relentlessly • Measure everything • Learn from failures**
