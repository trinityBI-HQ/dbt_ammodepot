# Error Recovery

> **Purpose**: Retry with backoff, dead-letter queues, monitoring, and self-healing patterns
> **MCP Validated**: 2026-02-19

## When to Use

- Production workflows requiring high reliability
- Systems with external API dependencies
- Workflows processing critical business data
- Automations that must not lose data
- Systems requiring audit trails

## Three-Layer Architecture

```javascript
Layer 1: Node-level retry (transient failures)
Layer 2: Error workflow (recoverable failures)
Layer 3: Dead-letter queue (persistent failures)
```

## Pattern 1: Exponential Backoff

```javascript
Code: "Retry with Backoff"
  async function retryWithBackoff(operation, maxRetries = 4) {
    for (let attempt = 0; attempt < maxRetries; attempt++) {
      try {
        return await operation();
      } catch (error) {
        if (attempt === maxRetries - 1) throw error;

        // Exponential backoff: 1s, 2s, 5s, 13s
        const baseDelay = Math.pow(2, attempt) * 1000;
        const jitter = Math.random() * 0.4 - 0.2; // ±20%
        const delay = baseDelay * (1 + jitter);

        await new Promise(resolve => setTimeout(resolve, delay));
      }
    }
  }

  return await retryWithBackoff(async () => {
    const response = await $http.request({
      method: 'POST',
      url: 'https://api.example.com/data',
      body: $json
    });
    if (response.statusCode !== 200) throw new Error(`HTTP ${response.statusCode}`);
    return response.body;
  });
```

## Pattern 2: Error Classification

```javascript
Error Trigger
  → Function: "Classify Error"
    const statusCode = $json.error.httpCode || 0;

    // Define categories
    const retryable = [
      statusCode >= 500,
      statusCode === 429,
      statusCode === 408,
      $json.error.message.includes('timeout')
    ].some(Boolean);

    return {
      retryable,
      action: retryable ? 'retry' :
              statusCode === 422 ? 'manual_review' :
              statusCode === 401 ? 'refresh_auth' : 'fatal'
    };

  → Switch: Route by action
    retry: → Wait → Retry request
    refresh_auth: → Refresh token → Retry
    manual_review: → DLQ → Alert team
    fatal: → Log → Skip
```

## Pattern 3: Dead-Letter Queue

```javascript
// Main workflow
Webhook: /process-data
  Error Workflow: "DLQ Handler"
  → HTTP Request (3 retries)
  → Database: Store result

// DLQ Handler
Error Trigger
  → Check retry count
  → IF: Exceeded max retries
    → [YES] → Database: dead_letter_queue
      Columns: execution_id, error, data, timestamp
      → Slack: Alert team
    → [NO] → Wait → Retry with backoff
```

## Pattern 4: DLQ Reprocessing

```javascript
// Manual reprocessing workflow
Manual Trigger
  → Database: Fetch DLQ items (pending_review)
  → Loop: For each item
    → Validate data
    → IF: Valid
      → Execute workflow → Update status: reprocessed
      → ELSE: Update status: invalid

  → Email: Reprocessing report
```

## Pattern 5: Circuit Breaker

```javascript
Code: "Circuit Breaker"
  const state = {
    failures: $env.CIRCUIT_FAILURES || 0,
    state: $env.CIRCUIT_STATE || 'closed' // closed, open, half-open
  };

  const threshold = 5;
  const timeout = 60000; // 1 minute

  // Check if circuit is open
  if (state.state === 'open') {
    if (Date.now() - state.lastFailure > timeout) {
      state.state = 'half-open';
    } else {
      throw new Error('Circuit OPEN - skipping request');
    }
  }

  try {
    // Make API call
    const result = await $http.request({
      url: 'https://api.example.com/data',
      method: 'POST',
      body: $json
    });

    // Success - close circuit
    if (state.state === 'half-open') {
      state.state = 'closed';
      state.failures = 0;
    }
    return { success: true, result };

  } catch (error) {
    // Failure - increment and check threshold
    state.failures++;
    if (state.failures >= threshold) {
      state.state = 'open';
      // Alert team
      await $http.request({
        url: $env.SLACK_WEBHOOK,
        method: 'POST',
        body: { text: `🔴 Circuit OPEN for ${$workflow.name}` }
      });
    }
    throw error;
  }
```

## Best Practices

1. **Classify errors** - Different recovery strategies
2. **Exponential backoff** - Prevent overwhelming services
3. **Add jitter** - Avoid thundering herd
4. **Use dead-letter queues** - Never lose data
5. **Monitor DLQ depth** - Alert on growth
6. **Reprocess regularly** - Manual review and retry
7. **Circuit breakers** - Prevent cascading failures
8. **Log all errors** - Audit trail
9. **Alert on critical** - Page on-call
10. **Test error scenarios** - Simulate failures

## See Also

- [Error Handling Concept](../concepts/error-handling.md)
- [API Integration Pattern](api-integration.md)
