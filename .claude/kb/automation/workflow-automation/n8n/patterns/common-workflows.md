# Common Workflow Patterns

> **Purpose**: Production-ready workflow templates for frequent automation use cases
> **MCP Validated**: 2026-02-19

## When to Use

- Starting new automation with proven patterns
- Implementing standard business processes
- Learning n8n best practices
- Building consistent workflows across teams

## Pattern 1: API to Database ETL

```javascript
Schedule Trigger: Every 6 hours
  → HTTP Request: Fetch from API
    Retry: 3 attempts
  → Code: Transform data
    return users.map(u => ({
      id: u.id,
      email: u.email.toLowerCase(),
      created_at: new Date(u.created_at).toISOString()
    }));
  → Postgres: Upsert
    Operation: "Insert or Update"
    Conflict Columns: "id"
```

## Pattern 2: Webhook to Multi-Service Fanout

```javascript
Webhook Trigger: POST /customer-event
  → Edit Fields: Normalize data
  → Split Into Branches:
    Path 1: → HTTP Request: Salesforce CRM
    Path 2: → HTTP Request: Mailchimp
    Path 3: → HTTP Request: Segment Analytics
  → Merge: Wait for all
  → Respond: 200 OK
```

## Pattern 3: File Processing Pipeline

```javascript
Schedule: Every 5 minutes
  → Google Drive: List files in inbox
  → IF: Files found?
    → Loop:
      → Download file
      → Process content
      → Insert to database
      → Move to processed folder
```

## Pattern 4: Data Validation and Enrichment

```javascript
Webhook: POST /lead-capture
  → Code: Validate required fields
  → HTTP Request: Enrich with Clearbit
  → Code: Merge data
  → HTTP Request: POST to CRM
  → Respond: Success
```

## Pattern 5: Error Recovery with DLQ

```javascript
// Main Workflow
Webhook: POST /process-payment
  Error Workflow: "Payment Error Handler"
  → HTTP Request: Charge payment (3 retries)
  → Database: Record transaction
  → Respond: Success

// Error Handler
Error Trigger
  → Classify error
  → IF: Retryable → Wait → Retry
  → ELSE: → Dead Letter Queue → Alert
```

## Best Practices

1. **Always add error workflows** - Production needs error handling
2. **Use sub-workflows** - Break complex logic into reusable pieces
3. **Add logging** - Track key events for debugging
4. **Validate inputs** - Check required fields early
5. **Set timeouts** - Prevent hanging workflows
6. **Test incrementally** - Execute node-by-node
7. **Monitor metrics** - Track success rate, latency

## See Also

- [AI Agent Workflow Patterns](ai-agent-workflows.md) — AI agent, MCP, HITL patterns
- [Data Transformation Pattern](data-transformation.md)
- [API Integration Pattern](api-integration.md)
- [Error Recovery Pattern](error-recovery.md)
