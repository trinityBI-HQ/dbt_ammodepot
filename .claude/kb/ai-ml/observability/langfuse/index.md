# Langfuse Knowledge Base

> **Purpose**: LLMOps observability platform for tracking LLM calls, costs, latency, and quality
> **Version**: 3.x (stable since Dec 2024)
> **MCP Validated**: 2026-02-19

## Quick Navigation

### Concepts (< 150 lines each)

| File | Purpose |
|------|---------|
| [concepts/traces-spans.md](concepts/traces-spans.md) | Trace hierarchy, observation types, agent graphs |
| [concepts/generations.md](concepts/generations.md) | LLM call tracking with model/tokens |
| [concepts/cost-tracking.md](concepts/cost-tracking.md) | Token usage and cost calculation |
| [concepts/scoring.md](concepts/scoring.md) | Quality feedback, evaluation, annotation queues |
| [concepts/prompt-management.md](concepts/prompt-management.md) | Version control and deployment |
| [concepts/model-comparison.md](concepts/model-comparison.md) | A/B testing and model analytics |

### Patterns (< 200 lines each)

| File | Purpose |
|------|---------|
| [patterns/python-sdk-integration.md](patterns/python-sdk-integration.md) | Basic SDK setup and instrumentation |
| [patterns/cloud-run-instrumentation.md](patterns/cloud-run-instrumentation.md) | GCP Cloud Run function tracing |
| [patterns/quality-feedback-loops.md](patterns/quality-feedback-loops.md) | User feedback and LLM-as-Judge |
| [patterns/cost-alerting.md](patterns/cost-alerting.md) | Cost monitoring thresholds |
| [patterns/trace-linking.md](patterns/trace-linking.md) | Distributed tracing with OpenTelemetry |
| [patterns/dashboard-metrics.md](patterns/dashboard-metrics.md) | Key metrics and monitoring setup |

---

## Quick Reference

- [quick-reference.md](quick-reference.md) - Fast lookup tables

---

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Trace** | Single request/operation container for observations |
| **Generation** | Specialized span for LLM calls with token/cost data |
| **Agent Graph** | Visualize real execution flow of complex agents (GA Nov 2025) |
| **Score** | Numeric/categorical/boolean quality metric |
| **Session** | Groups multiple traces (e.g., chat thread) |
| **Annotation Queue** | Team-based labeling with queue assignments |

## v3 Architecture

Langfuse v3 (stable Dec 2024) replaced the single-Postgres architecture with a multi-service stack:

| Component | Role |
|-----------|------|
| **ClickHouse** | OLAP analytics engine for traces, scores, dashboards |
| **PostgreSQL** | Transactional data (prompts, projects, users) |
| **Redis/Valkey** | Caching, rate limiting, queue management |
| **S3/Blob Storage** | Large trace payloads, media storage |
| **Worker Container** | Async processing of ingestion, evaluations |
| **Web Container** | API and UI serving |

## Key v3 Features

- **OpenTelemetry-based tracing**: Reduces vendor lock-in, native OTel bridge
- **New observation types**: Agent, Tool, Chain, Retriever, Embedding, Guardrail
- **Full-text search**: Search across dataset items and traces
- **Table and API filters**: Advanced filtering (Nov 2025)
- **Playground improvements**: reasoning_effort, service_tier parameters
- **Mixpanel integration**: Combine product analytics with LLM metrics
- **50+ library integrations**: LangChain, LlamaIndex, OpenAI SDK, Vercel AI, etc.

---

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/traces-spans.md, concepts/generations.md |
| **Intermediate** | patterns/python-sdk-integration.md, concepts/scoring.md |
| **Advanced** | patterns/trace-linking.md, patterns/quality-feedback-loops.md |

---

## Project Integration

| Use Case | Pattern | Target |
|----------|---------|--------|
| Invoice extraction | python-sdk-integration | Cloud Run function |
| Cost monitoring | cost-alerting | $0.003/invoice threshold |
| Quality tracking | quality-feedback-loops | 90% accuracy target |
| Latency monitoring | dashboard-metrics | P95 < 3s target |
| Agent debugging | traces-spans (agent graphs) | Complex agent flows |
