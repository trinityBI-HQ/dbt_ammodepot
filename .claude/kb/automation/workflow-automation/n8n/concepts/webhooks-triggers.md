# Webhooks and Triggers

> **Purpose**: Webhook endpoints, Chat Trigger, MCP Server Trigger, Form Trigger, and event-driven activation
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Trigger nodes start workflows on events. n8n v2.x supports webhooks, chat interfaces, MCP server endpoints, forms, schedules, and service-based triggers. New trigger types enable AI agent interactions and protocol-level integration.

## Trigger Types

| Trigger | Purpose | Added |
|---------|---------|-------|
| Webhook | HTTP endpoint for external requests | v1.0 |
| Chat Trigger | Hosted chat UI for AI agents/chatbots | v1.x |
| MCP Server Trigger | Expose workflow as MCP tool | v2.x |
| Form Trigger | Hosted HTML form for data collection | v1.x |
| Schedule | Cron-based recurring execution | v1.0 |
| Manual | On-demand execution | v1.0 |
| Service | App-specific (Gmail, Stripe, Kafka) | v1.0 |
| Polling | Periodic check for changes (RSS, etc.) | v1.0 |

## Webhook Trigger

```javascript
Webhook Trigger
  HTTP Method: POST
  Path: /webhook/user-signup
  Authentication: Header Auth
  Response Mode: "When Last Node Finishes"

// Production URL: https://n8n.example.com/webhook-prod/user-signup
```

## Chat Trigger (AI Agents)

```javascript
// Creates hosted chat interface for AI workflows
Chat Trigger
  → AI Agent
    └── LLM: Anthropic Chat Model
    └── Memory: Postgres Chat Memory
    └── Tools: [Workflow Tool, Code Tool]
  → Respond to Chat

// Provides embedded chat widget URL
// Supports multi-turn conversations via memory
// HITL: "Send message and wait for response" (v2.5+)
```

## MCP Server Trigger

```javascript
// Expose n8n workflow as MCP-compatible tool
MCP Server Trigger
  Tool Name: "lookup_customer"
  Description: "Look up customer by email address"
  Input Schema: { "email": { "type": "string" } }
  → Database: Query customers
  → Return result

// External AI agents (Claude Desktop, etc.) connect via MCP
// Each MCP Server Trigger workflow = one MCP tool
```

## Form Trigger

```javascript
// Hosted HTML form that feeds data into workflow
Form Trigger
  Title: "Support Request"
  Fields:
    - name (text, required)
    - email (email, required)
    - issue (textarea)
  → Code: Validate input
  → Database: Create ticket
  → Email: Send confirmation
```

## Webhook Authentication

| Method | Security | Use Case |
|--------|----------|----------|
| None | Low | Public webhooks |
| Header Auth | Medium | Custom APIs |
| Basic Auth | Medium | Legacy systems |
| JWT | High | Token auth |
| IP Whitelist | Medium | Known sources |

## Signature Verification

```javascript
Webhook Trigger
  → Code: Verify Signature
    const crypto = require('crypto');
    const signature = $input.item.json.headers["stripe-signature"];
    const secret = $env.STRIPE_WEBHOOK_SECRET;

    const expected = crypto
      .createHmac('sha256', secret)
      .update(JSON.stringify($json.body))
      .digest('hex');

    if (signature !== expected) {
      throw new Error('Invalid signature');
    }
```

## Response Modes

| Mode | When Sent | Use Case |
|------|-----------|----------|
| When Last Node Finishes | After completion | Sync processing |
| Immediately | Before workflow | Async, long workflows |
| When Node Finishes | After specific node | Partial response |

## Common Mistakes

```javascript
// WRONG: No auth on production webhook; using Webhook for AI chat
Webhook: /production, Authentication: None  // Open to abuse
Webhook → AI Agent  // No conversation UI or memory

// CORRECT: Secured webhook; Chat Trigger for AI conversations
Webhook, Authentication: Header Auth, IP Whitelist: "known.ips"
Chat Trigger → AI Agent + Memory  // Built-in chat UI
```

## Production Checklist

- Authentication configured (Webhook) or access controlled (Chat/Form)
- MCP Server Trigger: tool names descriptive, schemas defined
- Signature verification for payment/sensitive webhooks
- Error Workflow attached
- Rate limiting considered
- Tested with real data

## Related

- [AI Agents](ai-agents.md)
- [Credentials and Authentication](credentials-auth.md)
- [API Integration Pattern](../patterns/api-integration.md)
