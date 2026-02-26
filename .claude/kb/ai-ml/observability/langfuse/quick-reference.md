# Langfuse Quick Reference

> Fast lookup tables. For code examples, see linked files.
> **Version**: 3.x | **MCP Validated**: 2026-02-19

## SDK Installation

| Action | Command |
|--------|---------|
| Install | `pip install langfuse` |
| Initialize | `from langfuse import get_client; langfuse = get_client()` |
| Verify | `langfuse.auth_check()` |
| Flush | `langfuse.flush()` |

## Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `LANGFUSE_SECRET_KEY` | API secret key | `sk-lf-...` |
| `LANGFUSE_PUBLIC_KEY` | API public key | `pk-lf-...` |
| `LANGFUSE_BASE_URL` | Server endpoint | `https://cloud.langfuse.com` |

## Observation Types (v3)

| Type | Use Case | Tracks |
|------|----------|--------|
| `span` | Generic operations | Duration, I/O |
| `generation` | LLM calls | Model, tokens, cost |
| `event` | Discrete points | Timestamp only |
| `agent` | Agent execution | Agent graph visualization |
| `tool` | Tool invocations | Function calls |
| `chain` | Processing chains | Sequential steps |
| `retriever` | RAG retrieval | Document fetch |
| `embedding` | Embedding generation | Vector operations |
| `guardrail` | Safety checks | Validation results |

## v3 Architecture Components

| Component | Purpose |
|-----------|---------|
| ClickHouse | OLAP analytics, trace queries |
| PostgreSQL | Transactional data, prompts |
| Redis/Valkey | Cache, rate limiting, queues |
| S3/Blob | Large payloads, media |
| Worker | Async ingestion, evaluations |

## Score Data Types

| Type | Values | Example |
|------|--------|---------|
| `NUMERIC` | Float 0.0-1.0 | `0.95` |
| `CATEGORICAL` | String labels | `"correct"`, `"incorrect"` |
| `BOOLEAN` | True/False | `True` |

## Key Methods

| Method | Purpose |
|--------|---------|
| `start_as_current_observation()` | Context manager for spans |
| `create_score()` | Add evaluation score |
| `get_prompt()` | Fetch versioned prompt |
| `prompt.compile()` | Render template variables |

## Decision Matrix

| Use Case | Choose |
|----------|--------|
| Track LLM call | `as_type="generation"` |
| Track agent step | `as_type="agent"` |
| Track function | `as_type="span"` |
| Group conversation | Use `session_id` |
| Link across services | Share `trace_id` or use OTel |

## Common Pitfalls

| Do Not | Do |
|--------|-----|
| Forget `flush()` in Lambda/Cloud Run | Call `langfuse.flush()` before exit |
| Hardcode prompts | Use `get_prompt()` with labels |
| Skip user_id | Track users for analytics |
| Ignore costs | Set up cost alerting |
| Use single Postgres in prod (v3) | Deploy full stack: ClickHouse + Redis + S3 |

## Related Documentation

| Topic | Path |
|-------|------|
| SDK Setup | `patterns/python-sdk-integration.md` |
| Full Index | `index.md` |
