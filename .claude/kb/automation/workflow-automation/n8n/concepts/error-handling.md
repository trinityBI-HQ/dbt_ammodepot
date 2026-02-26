# Error Handling

> **Purpose**: Error workflows, retry logic, and failure recovery for resilient automation
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

n8n provides node-level retries, error workflows that execute on failure, and Error Trigger nodes. Production workflows should always implement error handling to prevent data loss and enable recovery.

## The Pattern

```javascript
// Three-layer strategy
1. Node-level retries (transient failures)
2. Error workflow (workflow-level failures)
3. Dead-letter queue (persistent failures)

// HTTP Request with retries
HTTP Request
  Retry On Fail: ON
  Max Tries: 4
  Wait Between Tries: 1000ms

// Workflow settings
Settings → Error Workflow: "Error Handler"
```

## Node-Level Retry

```json
{
  "name": "Call External API",
  "type": "n8n-nodes-base.httpRequest",
  "retryOnFail": true,
  "maxTries": 4,
  "waitBetweenTries": 1000
}
```

## Error Workflow Pattern

```javascript
// Main Workflow
Settings → Error Workflow: "Production Error Handler"

// Error Handler workflow
Error Trigger
  → Function: Extract error details
    → IF: Is retryable?
      → [YES] → Wait → Retry
      → [NO] → Dead Letter Queue → Alert

// Error data structure
{
  "execution": { "id": "12345" },
  "workflow": { "id": "workflow-123", "name": "Production" },
  "node": { "name": "HTTP Request" },
  "error": { "message": "Status 500", "stack": "..." }
}
```

## Retry Strategies

| Strategy | Backoff | Use Case |
|----------|---------|----------|
| Fixed | 1s, 1s, 1s | Fast APIs |
| Exponential | 1s, 2s, 5s, 13s | Rate-limited APIs |
| Exp + Jitter | 1s±20%, 2s±20% | Production default |

## Error Classification

```javascript
Function: "Classify Error"
const error = $json.error;
const statusCode = error.httpCode || 0;

const retryable = [
  statusCode >= 500,
  statusCode === 429,
  statusCode === 408,
  error.message.includes('timeout')
].some(Boolean);

return {
  retryable,
  category: statusCode === 422 ? 'validation' : 'system',
  statusCode
};
```

## Common Mistakes

### Wrong
```javascript
// No error handling
HTTP Request → Database
// ❌ Failures stop workflow

// Continue On Fail without handling
HTTP Request
  Continue On Fail: true
→ Database
// ❌ Writes invalid data
```

### Correct
```javascript
// Comprehensive handling
HTTP Request
  Retry: 3 attempts
  Error Workflow: "Handler"
→ IF: Check status
  → [200] → Database
  → [ERROR] → Log error → Alert
```

## AI Agent Error Handling (v2.x)

For AI Agent workflows, use HITL approval gates on destructive tools (v2.6+) to prevent unintended actions. AI tool errors route through the same Error Workflow system. See [AI Agent Workflow Patterns](../patterns/ai-agent-workflows.md).

## Related

- [Error Recovery Pattern](../patterns/error-recovery.md)
- [API Integration Pattern](../patterns/api-integration.md)
- [AI Agents](ai-agents.md)
