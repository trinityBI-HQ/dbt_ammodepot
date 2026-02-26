# Nodes and Workflows

> **Purpose**: Core building blocks of n8n automation — nodes, connections, execution flow, and v2.x architecture
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Nodes are single action units in n8n workflows. Each node performs one task: HTTP request, data transform, AI agent call, or trigger on events. Workflows are connected sequences of nodes. In v2.0+, workflows use a Save/Publish paradigm — saving preserves edits, publishing promotes to production.

## Node Categories

| Category | Purpose | Examples |
|----------|---------|----------|
| **Triggers** | Start workflows | Webhook, Schedule, Chat, MCP Server, Form, Manual |
| **Actions** | Perform operations | HTTP Request, Database, Email |
| **Transform** | Modify data | Edit Fields, Code, Aggregate, Split Out |
| **Logic** | Control flow | IF, Switch, Merge, Wait, Loop |
| **AI** | Agent orchestration | AI Agent, Basic LLM Chain, Information Extractor |
| **Sub-workflow** | Call other workflows | Execute Workflow |

## Execution Flow

```javascript
// Data passes through nodes as items
// Each node processes ALL items before passing to next node
[
  { "json": { "id": 1, "status": "active" } },
  { "json": { "id": 2, "status": "inactive" } }
]

// Basic structure: Trigger → Transform → Action → Output
Webhook Trigger
  → Edit Fields: Extract email, name
    → HTTP Request: POST to CRM API
      → Send Email: Confirmation
```

## Save vs Publish (v2.0+)

```javascript
// Save: Preserves edits without touching live version
// Publish: Promotes workflow to production (activated)
// Autosave available since v2.1

// Workflow states:
// - Draft: Saved but not published
// - Published: Live, activated version
// - Modified: Published but has unpublished edits
```

## Task Runners (v2.0+)

```javascript
// All Code node executions run in isolated processes
// Mandatory in v2.0+ (cannot disable)

// Modes:
// - Internal: Child process on same machine (default)
// - External: Separate container (production recommended)

// Impact:
// - process.env blocked by default (N8N_BLOCK_ENV_ACCESS_IN_NODE=true)
// - Use credentials or External Secrets instead
// - Python Code runs native Python (not Pyodide)
```

## Node Configuration

```json
{
  "name": "Fetch User Data",
  "type": "n8n-nodes-base.httpRequest",
  "parameters": {
    "method": "GET",
    "url": "https://api.example.com/users/{{ $json.userId }}",
    "authentication": "predefinedCredentialType",
    "nodeCredentialType": "httpHeaderAuth",
    "options": {
      "timeout": 10000,
      "retry": { "maxRetries": 3, "waitBetweenRetries": 1000 }
    }
  }
}
```

## Common Mistakes

### Wrong
```javascript
// All logic in single massive workflow
Webhook → 30 nodes → Final Output
// Hard to debug, maintain, or reuse
```

### Correct
```javascript
// Break into logical sub-workflows
Main: Webhook → Validate → Execute Sub-Workflow → Respond
Sub:  Process Data → Call API → Transform Result
// Easier to test, debug, and reuse
```

## Best Practices

1. **Keep workflows focused** — One workflow per business process
2. **Use sub-workflows** — Reuse logic; expose as Workflow Tool for AI agents
3. **Name nodes clearly** — "Fetch User from CRM", not "HTTP Request 1"
4. **Use Save/Publish** — Test with Save, promote with Publish
5. **Test incrementally** — Execute node-by-node during development

## Production Checklist

```
- ✓ Error Workflow configured
- ✓ Retry logic on external calls
- ✓ Credentials stored securely (not env vars in Code nodes)
- ✓ Task runner mode appropriate for workload
- ✓ Workflow Published (not just Saved)
- ✓ Tested with real data
```

## Related

- [AI Agents](ai-agents.md)
- [Webhooks and Triggers](webhooks-triggers.md)
- [Expressions and Variables](expressions-variables.md)
- [Error Handling](error-handling.md)
