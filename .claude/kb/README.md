# Claude Code Lab - Knowledge Base

> **Last Updated:** 2026-02-20 (42 technologies)
> **Maintained By:** Claude Code Lab Team

## Overview

The Claude Code Lab Knowledge Base is a hierarchical collection of domain-specific documentation, patterns, and best practices organized by technical specialty. Each domain contains validated, production-ready guidance for building enterprise-grade systems.

## Organization Philosophy

The KB is organized by **specialty first, technology second** to support cross-technology patterns and decision-making:

- **Specialty categories** (data-engineering, ai-ml, cloud) group related technologies
- **Technology folders** contain detailed documentation and patterns
- **Cross-references** connect related concepts across categories
- **MCP validation** ensures accuracy and currency of documentation

This structure helps you:
- **Find the right tool** for your use case through category overviews
- **Compare alternatives** using decision frameworks and comparison tables
- **Learn patterns** that apply across similar technologies
- **Navigate efficiently** with consistent structure and cross-references

## Specialties

### 📊 Data Engineering

**Path:** [data-engineering/](data-engineering/)

Build reliable, scalable data pipelines and platforms.

| Category | Technologies | Use Cases |
|----------|--------------|-----------|
| Code Quality | Flake8 | Python linting, style enforcement, bug detection |
| Orchestration | Dagster | Software-defined assets, data lineage, complex dependencies |
| Transformation | dbt Core, dbt Cloud | SQL-based transformations, testing, documentation |
| Modeling | Data Vault 2.0 | Hub/Link/Satellite architecture, audit trails, parallel loading |
| Data Platforms | Snowflake | Cloud data warehousing, analytics, semi-structured data |
| Data Quality | Great Expectations, Soda | Declarative validation, SodaCL checks, multi-backend, Data Docs |
| Observability | Elementary | dbt-native anomaly detection, data quality monitoring, alerting |
| Table Formats | Apache Iceberg | ACID transactions, schema evolution, hidden partitioning, time travel |
| FinOps | FinOps | Cloud cost optimization for data pipelines, warehouses, storage |
| Data Governance | Data Contracts, OpenMetadata | Schema agreements, SLAs, data catalog, lineage, metadata management |
| ELT | Airbyte | Data integration, connector-based ingestion |

**When to use:** Building data pipelines, managing analytics workloads, orchestrating complex data workflows

### 🤖 AI/ML

**Path:** [ai-ml/](ai-ml/)

Develop production AI systems with LLMs, observability, and multi-agent orchestration.

| Category | Technologies | Use Cases |
|----------|--------------|-----------|
| LLM Platforms | Gemini, OpenRouter | Multimodal AI, model routing, fallback strategies |
| Observability | LangFuse | LLM tracing, cost tracking, performance monitoring |
| Validation | Pydantic | Structured outputs, type safety, LLM response parsing |
| Multi-Agent | CrewAI | Coordinated agent workflows, role-based agents |
| Workflow | LangFlow | Visual AI workflow design, low-code orchestration |

**When to use:** Building AI features, LLM applications, multi-agent systems, production ML monitoring

### ☁️ Cloud

**Path:** [cloud/](cloud/)

Deploy and scale applications on cloud infrastructure.

| Category | Technologies | Use Cases |
|----------|--------------|-----------|
| GCP | Cloud Run, Pub/Sub, BigQuery, GCS | Serverless compute, event streaming, data warehouse |
| AWS | S3, IAM, Glue, Athena, S3 Tables, KMS, CloudWatch, Secrets Manager | Object storage, ETL, SQL analytics, security, monitoring |

**When to use:** Deploying serverless applications, event-driven architectures, managed cloud services

### ⚙️ DevOps/SRE

**Path:** [devops-sre/](devops-sre/)

Automate infrastructure, deployments, and operational excellence.

| Category | Technologies | Use Cases |
|----------|--------------|-----------|
| IaC | Terraform, Terragrunt | Infrastructure as code, multi-environment management |
| Version Control | GitHub | PR workflows, Actions CI/CD, security scanning, project management |
| Containerization | Docker Compose | Multi-container orchestration, local dev, service definitions |
| Monitoring | Grafana, Prometheus | Metrics visualization, alerting, PromQL, time-series collection, dashboard-as-code |
| Python Tooling | uv | Ultra-fast package management, virtual environments, Python version management |
| Platform | Railway | Rapid deployment, preview environments, managed hosting |

**When to use:** Infrastructure automation, CI/CD pipelines, deployment standardization, observability

### 🔄 Automation

**Path:** [automation/](automation/)

Automate workflows, integrations, and business processes.

| Category | Technologies | Use Cases |
|----------|--------------|-----------|
| Workflow Automation | n8n | Integration workflows, API orchestration, event triggers |
| Diagramming | Mermaid | Text-based diagrams, architecture visualization, docs-as-code |

**When to use:** Integrating systems, automating repetitive tasks, event-driven workflows, documentation diagrams

### 📄 Document Processing

**Path:** [document-processing/](document-processing/)

Extract, transform, and process documents at scale.

| Category | Technologies | Use Cases |
|----------|--------------|-----------|
| Document Parsing | Docling | PDF extraction, document structure analysis, multi-format parsing |

**When to use:** Processing invoices, extracting structured data, document intelligence pipelines

## Navigation Guide

### Finding the Right Tool

1. **Start with use case** → Check the specialty that matches your problem domain
2. **Review category overview** → Read the specialty README for decision frameworks
3. **Compare technologies** → Use comparison tables to evaluate options
4. **Deep dive** → Explore specific technology folders for patterns and examples

### Quick Reference Paths

```
.claude/kb/
├── data-engineering/
│   ├── code-quality/flake8/
│   ├── orchestration/dagster/
│   ├── transformation/dbt-{core,cloud}/
│   ├── modeling/data-vault/
│   ├── data-platforms/snowflake/
│   ├── data-quality/{great-expectations,soda}/
│   ├── observability/elementary/
│   ├── table-formats/apache-iceberg/
│   ├── finops/finops/
│   ├── data-governance/{data-contracts,openmetadata}/
│   └── elt/airbyte/
├── ai-ml/
│   ├── llm-platforms/{gemini,openrouter}/
│   ├── observability/langfuse/
│   ├── validation/pydantic/
│   ├── multi-agent/crewai/
│   └── workflow/langflow/
├── cloud/
│   ├── gcp/
│   └── aws/{s3,iam,glue,athena,s3-tables,kms,cloudwatch,secrets-manager}/
├── devops-sre/
│   ├── iac/{terraform,terragrunt}/
│   ├── version-control/github/
│   ├── containerization/docker-compose/
│   ├── monitoring/{grafana,prometheus}/
│   ├── python-tooling/uv/
│   └── platform/railway/
├── automation/
│   ├── workflow-automation/n8n/
│   └── diagramming/mermaid/
└── document-processing/
    └── docling/
```

## Adding New Content

### For New Technologies

1. Use `/create-kb` command for consistency
2. Choose appropriate specialty and category
3. Follow the template structure in `_templates/`
4. Validate content with MCP before committing
5. Update the relevant category README

### For New Patterns

1. Add to the appropriate technology's `patterns/` folder
2. Keep files under 200 lines (link to specs/ for details)
3. Include practical, runnable examples
4. Cross-reference related patterns

### File Organization Standards

Each technology folder should contain:
- `index.md` - Overview, installation, getting started
- `quick-reference.md` - Cheat sheet, common commands (max 100 lines)
- `concepts/` - Fundamental concepts (max 150 lines per file)
- `patterns/` - Implementation patterns (max 200 lines per file)
- `specs/` - Detailed specifications (no size limit)

## MCP Integration

The KB integrates with MCP servers for validation and enrichment:
- **Context7**: Library documentation and API references
- **Exa**: Code examples and real-world implementations
- **Ref**: Official framework documentation

Agents use confidence scoring when querying:
- **0.95**: KB + MCP agree (high confidence)
- **0.85**: MCP only (new, not yet in KB)
- **0.75**: KB only (proceed with disclaimer)
- **0.50**: Conflict (ask user to resolve)

## Quality Standards

All KB content must:
✅ Be validated with MCP servers
✅ Include practical, tested examples
✅ Respect file size limits
✅ Use consistent formatting
✅ Link to related content
✅ Include last updated date

## Specialty Comparison Matrix

| Specialty | Primary Focus | Key Technologies | Typical User Role |
|-----------|---------------|------------------|-------------------|
| Data Engineering | Data pipelines, analytics | Dagster, dbt, Snowflake, Elementary, Great Expectations, Soda, Iceberg, FinOps, Data Contracts, OpenMetadata, Flake8 | Data Engineer, Analytics Engineer |
| AI/ML | LLM applications, agents | Gemini, LangFuse, CrewAI | ML Engineer, AI Developer |
| Cloud | Infrastructure, deployment | GCP, AWS (S3, IAM, Glue, Athena, KMS, CloudWatch) | Cloud Architect, DevOps Engineer |
| DevOps/SRE | Automation, reliability | Terraform, Grafana, Prometheus, uv, CI/CD, Monitoring | DevOps Engineer, SRE |
| Automation | Workflow integration | n8n, Mermaid, Zapier, RPA | Integration Engineer, Automation Specialist |
| Document Processing | Document intelligence | Docling, OCR, Extraction | Data Engineer, ML Engineer |

## Getting Help

- **Agents**: Use specialized agents (e.g., `/dagster-expert`, `/snowflake-expert`) for guided assistance
- **Commands**: Run `/create-kb` to add new domains
- **Issues**: Report documentation issues to the Claude Code Lab team

---

**Built with specialized agents • Validated knowledge • Confident execution**
