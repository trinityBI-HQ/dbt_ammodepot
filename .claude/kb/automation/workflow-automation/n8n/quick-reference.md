# n8n Quick Reference

> Fast lookup tables for n8n v2.x. For code examples, see linked files.

## Core Node Types

| Category | Purpose | Examples |
|----------|---------|----------|
| Trigger | Starts workflow | Webhook, Schedule, Chat, MCP Server, Form, Manual |
| Action | Performs operation | HTTP Request, Set, Code, Database |
| Transform | Modifies data | Edit Fields, Aggregate, Split Out |
| Logic | Controls flow | IF, Switch, Merge, Wait, Loop |
| AI | Agent orchestration | AI Agent, Basic LLM Chain, Information Extractor |
| Sub-workflow | Calls workflow | Execute Workflow, Workflow Tool |

## AI Node Types

| Node | Purpose |
|------|---------|
| AI Agent | ReAct agent with tools, memory, LLM |
| Basic LLM Chain | Single-shot LLM call |
| Information Extractor | Structured data extraction |
| Text Classifier | Label classification |
| Chat Model (sub-node) | LLM backend (OpenAI, Anthropic, Gemini, Ollama) |
| Memory (sub-node) | Conversation persistence (Redis, Postgres, Buffer) |
| Tool (sub-node) | Agent capabilities (Code, Workflow, MCP Client, Think) |
| Vector Store | RAG storage (Pinecone, Qdrant, PGVector) |
| Embeddings (sub-node) | Text embeddings (OpenAI, Gemini, Ollama) |

## Expression Syntax

| Pattern | Example |
|---------|---------|
| `{{ $json.field }}` | `{{ $json.email }}` |
| `{{ $input.item.json.field }}` | `{{ $input.item.json.userId }}` |
| `{{ $('NodeName').item.json.field }}` | `{{ $('HTTP Request').item.json.status }}` |
| `{{ $now }}` | Current timestamp |
| `{{ $workflow.id }}` | Workflow metadata |

## Trigger Types (v2.x)

| Trigger | Purpose |
|---------|---------|
| Webhook | HTTP endpoint for external requests |
| Chat Trigger | Hosted chat UI for AI agents |
| MCP Server Trigger | Expose workflow as MCP tool |
| Form Trigger | Hosted HTML form input |
| Schedule | Cron-based recurring execution |
| Manual | On-demand execution |

## v2.0 Breaking Changes

| Change | Impact |
|--------|--------|
| Task runners mandatory | Code nodes run in isolated processes |
| `process.env` blocked | Use credentials or External Secrets |
| Save/Publish paradigm | Save ≠ activate; explicit Publish required |
| MySQL/MariaDB removed | PostgreSQL or SQLite only |
| Start node removed | Use Manual Trigger instead |
| Python Code rewritten | Native Python, not Pyodide |

## Decision Matrix

| Use Case | Choose |
|----------|--------|
| AI chatbot | Chat Trigger + AI Agent + Memory |
| MCP tool server | MCP Server Trigger + workflow logic |
| Event-driven automation | Webhook Trigger + Error Workflow |
| Scheduled data sync | Schedule Trigger + incremental processing |
| API integration | HTTP Request + retry logic |
| Human review gate | AI Agent + Chat node (HITL) |

## Common Pitfalls

| Don't | Do |
|-------|-----|
| Store secrets in workflow | Use Credential manager or External Secrets |
| Single large workflow | Break into sub-workflows |
| Ignore error handling | Add Error Workflow + retries |
| Use Basic LLM Chain for multi-step | Use AI Agent with tools |
| Skip HITL for destructive AI tools | Gate with approval before execute |

## Related Documentation

| Topic | Path |
|-------|------|
| AI Agents | `concepts/ai-agents.md` |
| Getting Started | `concepts/nodes-workflows.md` |
| AI Workflow Patterns | `patterns/ai-agent-workflows.md` |
| Error Handling | `patterns/error-recovery.md` |
| Full Index | `index.md` |
