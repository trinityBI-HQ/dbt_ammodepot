# n8n Knowledge Base

> **Purpose**: Open-source workflow automation platform with 400+ integrations, 70+ AI nodes (LangChain), and MCP support
> **Version**: 2.7.x (stable)
> **MCP Validated**: 2026-02-19

## Quick Navigation

### Concepts (< 150 lines each)

| File | Purpose |
|------|---------|
| [concepts/nodes-workflows.md](concepts/nodes-workflows.md) | Core building blocks: nodes, connections, execution flow, task runners |
| [concepts/ai-agents.md](concepts/ai-agents.md) | AI Agent nodes, LangChain integration, vector stores, memory |
| [concepts/credentials-auth.md](concepts/credentials-auth.md) | Credential management, authentication, external secrets |
| [concepts/expressions-variables.md](concepts/expressions-variables.md) | JavaScript expressions, data references, variable syntax |
| [concepts/error-handling.md](concepts/error-handling.md) | Error workflows, retry logic, failure recovery |
| [concepts/webhooks-triggers.md](concepts/webhooks-triggers.md) | Webhooks, MCP Server Trigger, Chat Trigger, Form Trigger |

### Patterns (< 200 lines each)

| File | Purpose |
|------|---------|
| [patterns/common-workflows.md](patterns/common-workflows.md) | Production-ready workflow templates for common use cases |
| [patterns/ai-agent-workflows.md](patterns/ai-agent-workflows.md) | AI agent orchestration, MCP integration, HITL patterns |
| [patterns/data-transformation.md](patterns/data-transformation.md) | JSON mapping, aggregation, data reshaping patterns |
| [patterns/api-integration.md](patterns/api-integration.md) | REST API integration, authentication, rate limiting |
| [patterns/error-recovery.md](patterns/error-recovery.md) | Retry with backoff, dead-letter queues, monitoring |

---

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Node** | Single action unit (HTTP request, AI agent, data transform, trigger) |
| **Workflow** | Connected sequence of nodes; saved vs published (v2.0+) |
| **AI Agent** | LangChain-based agent node with tools, memory, and LLM backends |
| **MCP** | Model Context Protocol — n8n as MCP client or MCP server |
| **Expression** | `{{ }}` syntax for dynamic data access using JavaScript |
| **Credential** | Stored authentication for external service integration |
| **Trigger** | Node that starts workflow execution (webhook, chat, MCP, schedule) |
| **Task Runner** | Isolated process for Code node execution (mandatory v2.0+) |

---

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/nodes-workflows.md, concepts/webhooks-triggers.md |
| **Intermediate** | concepts/expressions-variables.md, patterns/data-transformation.md |
| **Advanced** | concepts/ai-agents.md, patterns/ai-agent-workflows.md |
| **Production** | patterns/error-recovery.md, patterns/api-integration.md |

---

## v2.0 Migration Notes

Key breaking changes from v1.x → v2.x:
- Task runners mandatory for Code nodes (isolated execution)
- `process.env` blocked in Code nodes by default
- Save/Publish workflow paradigm (save ≠ activate)
- MySQL/MariaDB database support removed (PostgreSQL or SQLite only)
- Start node removed (use Manual Trigger)
- Sub-workflow + Wait node behavior changed
- Python Code node rewritten (native Python, not Pyodide)

---

## Agent Usage

| Agent | Primary Files | Use Case |
|-------|---------------|----------|
| genai-architect | concepts/ai-agents.md, patterns/ai-agent-workflows.md | AI agent system design |
| pipeline-architect | patterns/common-workflows.md | Event-driven automation pipelines |
| function-developer | patterns/api-integration.md | Webhook-triggered serverless functions |
| dataops-builder | patterns/error-recovery.md | Self-healing pipeline implementation |
