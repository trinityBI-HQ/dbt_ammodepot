# API Integration

> **Purpose**: REST API integration with authentication, rate limiting, and error handling
> **MCP Validated**: 2026-02-19

## When to Use

- Integrating third-party APIs (CRM, payment, analytics)
- Building custom API connectors
- Implementing OAuth2 flows
- Handling rate limits and retry logic
- Creating resilient API workflows

## Pattern 1: Basic REST API Call

```javascript
HTTP Request
  Method: GET
  URL: "https://api.example.com/v1/users"
  Authentication: "API Key Credential"
  Headers: { "Accept": "application/json" }
  Query: { "limit": 100, "offset": {{ $json.offset || 0 }} }
  Timeout: 10000
  Retry On Fail: true
  Max Tries: 3

→ IF: Status 200
  → Process response
  → ELSE: Log error → Alert
```

## Pattern 2: Pagination

```javascript
Code: Initialize
  return { offset: 0, limit: 100, hasMore: true, allData: [] };

→ Loop: While hasMore
  → HTTP Request: Fetch page
  → Code: Process page
    const data = $json.results || [];
    return {
      offset: $json.offset + $json.limit,
      hasMore: data.length === $json.limit,
      allData: [...$json.allData, ...data]
    };

→ Split Out: allData array
```

## Pattern 3: OAuth2 Flow

```javascript
// Credential setup
OAuth2 Credential
  Grant Type: "Authorization Code"
  Auth URL: "https://provider.com/oauth/authorize"
  Token URL: "https://provider.com/oauth/token"
  Client ID: {{ $env.OAUTH_CLIENT_ID }}
  Client Secret: {{ $env.OAUTH_CLIENT_SECRET }}
  Scope: "read write"

// n8n handles token refresh automatically
HTTP Request
  Authentication: "OAuth2"
  Credential: "Provider OAuth2"
```

## Pattern 4: Rate Limit Handling

```javascript
// Strategy 1: Respect headers
HTTP Request
  → Code: Check rate limit
    const remaining = parseInt($json.headers['x-ratelimit-remaining']) || 0;
    const resetTime = parseInt($json.headers['x-ratelimit-reset']) || 0;

    if (remaining < 5) {
      return { shouldWait: true, waitMs: (resetTime * 1000) - Date.now() };
    }
    return { shouldWait: false };

  → IF: Should wait?
    → [YES] → Wait → Retry
    → [NO] → Continue

// Strategy 2: Queue-based throttling
Schedule: Every 5 seconds
  → Database: Fetch pending calls (FIFO)
    → HTTP Request → Mark completed
```

## Pattern 5: Error Handling

```javascript
HTTP Request
  Retry On Fail: true
  Max Tries: 4
  Error Workflow: "API Error Handler"

// Error Handler
Error Trigger
  → Classify error by status code
    429: Wait for rate limit
    500: Retry with backoff
    401: Refresh credentials
    422: Skip (validation error)
    default: Alert team

  → Route accordingly
```

## Pattern 6: Parallel API Calls

```javascript
Webhook → Split Into 3 Branches:
  Branch 1: → GET /users/{{ $json.userId }}
  Branch 2: → GET /orders?userId={{ $json.userId }}
  Branch 3: → GET /analytics/{{ $json.userId }}

→ Merge: Wait for all
→ Code: Combine results
```

## Best Practices

1. **Always use credentials** - Never hardcode keys
2. **Implement retry logic** - Network failures happen
3. **Handle rate limits** - Respect API quotas
4. **Validate responses** - Check status and structure
5. **Set timeouts** - Prevent hanging
6. **Log API calls** - Track for debugging
7. **Use environment variables** - Different configs per environment
8. **Test error scenarios** - Simulate failures
9. **Monitor API health** - Track success rate
10. **Document API versions** - Track compatibility

## Authentication Examples

```javascript
// API Key in header
Headers: { "X-API-Key": {{ $credentials.api.key }} }

// Bearer token
Headers: { "Authorization": "Bearer {{ $credentials.api.token }}" }

// Custom signature (HMAC)
const crypto = require('crypto');
const timestamp = Date.now();
const signature = crypto
  .createHmac('sha256', $env.API_SECRET)
  .update(`${timestamp}:${JSON.stringify($json)}`)
  .digest('hex');

Headers: {
  "X-Timestamp": timestamp,
  "X-Signature": signature
}
```

## MCP Client Integration

```javascript
// Use MCP Client Tool in AI Agent to consume external MCP servers
AI Agent
  └── Tool: MCP Client Tool
       Server URL: "https://api-mcp.example.com/sse"
       Auth: Bearer token
// Agent can call tools exposed by any MCP server
```

## See Also

- [AI Agent Workflow Patterns](ai-agent-workflows.md) — MCP integration patterns
- [Credentials Concept](../concepts/credentials-auth.md)
- [Error Recovery Pattern](error-recovery.md)
- [Common Workflows Pattern](common-workflows.md)
