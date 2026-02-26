# FinOps Framework

> **Purpose**: The three-phase lifecycle for technology financial management
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

The FinOps Framework 2025, maintained by the FinOps Foundation, is an iterative lifecycle of three phases: Inform, Optimize, and Operate. Teams cycle through these phases continuously as they mature their cost practices. The 2025 update formally expanded FinOps beyond public cloud by introducing five **Scopes** (Public Cloud, SaaS, Data Center, GenAI, Licensing) and removing "Cloud" from capability names to reflect this broader applicability.

## The Three Phases

### Phase 1: Inform

Build visibility into cloud spend. Know who spends what, where, and why.

**Key activities:**
- Implement cost allocation via tagging and labeling
- Build dashboards showing spend by team, project, pipeline
- Establish budgets and forecasting baselines
- Define unit economics metrics (cost per query, cost per pipeline run)
- Benchmark against industry peers and internal targets

**Data engineering focus:**
- Tag all clusters, warehouses, storage buckets, and pipeline jobs
- Track cost per Dagster asset materialization or dbt model run
- Monitor Snowflake credit consumption by warehouse and user

### Phase 2: Optimize

Reduce waste and improve efficiency using data from the Inform phase.

**Key activities:**
- Right-size compute resources (clusters, warehouses, instances)
- Purchase commitment discounts (Savings Plans, CUDs, capacity contracts)
- Implement storage tiering and lifecycle policies
- Modernize architecture (serverless, spot instances, autoscaling)
- Eliminate idle and unused resources

**Data engineering focus:**
- Switch from all-purpose to Jobs clusters in Databricks
- Use spot/preemptible instances for fault-tolerant Spark jobs
- Set Snowflake auto-suspend to 60 seconds
- Implement S3 lifecycle rules for pipeline staging data

### Phase 3: Operate

Sustain and govern optimizations through policy and automation.

**Key activities:**
- Define governance policies (max cluster size, required tags, budget limits)
- Automate enforcement (tag compliance, auto-termination, budget alerts)
- Establish approval workflows for expensive resources
- Run regular cost reviews with engineering and finance
- Continuously iterate back to Inform with new data

**Data engineering focus:**
- Enforce cluster policies in Databricks (instance types, spot ratios)
- Set Snowflake resource monitors with automatic suspension
- Automate anomaly detection for pipeline cost spikes
- Schedule weekly cost review with data team leads

## FinOps Maturity Model

| Level | Inform | Optimize | Operate |
|-------|--------|----------|---------|
| **Crawl** | Basic tagging, monthly reports | Manual right-sizing | Reactive alerting |
| **Walk** | Full allocation, dashboards | Commitments, automation | Proactive governance |
| **Run** | Real-time metrics, forecasting | AI-driven optimization | Cultural integration |

## FinOps Principles

1. **Teams need to collaborate** -- Engineering, finance, and business work together
2. **Everyone takes ownership** -- Engineers own their cost impact
3. **A centralized team drives FinOps** -- FinOps team enables, does not block
4. **Reports should be accessible and timely** -- Real-time, not monthly
5. **Decisions are driven by business value** -- Not just cost reduction
6. **Take advantage of the variable cost model** -- Cloud is not a fixed cost

## FinOps Framework 2025: Scopes

The 2025 update formally expanded FinOps beyond public cloud. The word "Cloud" was removed from all capability names (e.g., "Cloud Rate Optimization" became "Rate Optimization"). Five Scopes define where FinOps practices apply:

| Scope | Examples | Data Engineering Relevance |
|-------|----------|---------------------------|
| **Public Cloud** | AWS, GCP, Azure | Core infrastructure for data pipelines |
| **SaaS** | Snowflake, Databricks, Fivetran, Salesforce | Major data platform cost centers |
| **GenAI** | OpenAI, Bedrock, Vertex AI, Anthropic | LLM token costs, inference compute, fine-tuning |
| **Data Center** | On-prem Hadoop, Spark clusters | Hybrid deployments, colocation |
| **Licensing** | Oracle, SAP, Tableau | Software license cost management |

### GenAI as an Explicit Scope

GenAI cost management is now formalized, covering:
- **Token-based pricing**: Input/output token costs for LLM APIs
- **Model selection optimization**: Choosing the right model size for the task
- **Inference caching**: Reducing redundant API calls
- **Batch vs real-time**: Scheduling non-urgent inference for lower costs
- **Fine-tuning vs prompting**: Cost tradeoffs in customization approaches

## Related

- [Cost Allocation](cost-allocation.md) -- Implementing the Inform phase
- [Governance](governance.md) -- Implementing the Operate phase
- [Unit Economics](unit-economics.md) -- Measuring business value of cloud spend
