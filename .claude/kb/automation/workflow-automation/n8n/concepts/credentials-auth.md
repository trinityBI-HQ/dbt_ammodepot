# Credentials and Authentication

> **Purpose**: Secure credential management, authentication methods, and External Secrets for n8n v2.x
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Credentials store authentication data securely for external services. In v2.0+, `process.env` is blocked in Code nodes by default — use credentials, External Secrets (Enterprise), or the Credentials API for programmatic rotation.

## Authentication Methods

| Method | Security | Use Case |
|--------|----------|----------|
| OAuth2 | High | Google, Salesforce, GitHub |
| API Key | Medium | OpenAI, Stripe, SendGrid |
| Header Auth | Medium | Custom APIs with shared secret |
| Basic Auth | Low | Legacy systems (HTTPS only) |
| JWT | High | Token-based API auth |

## OAuth2 Configuration

```javascript
{
  "name": "Google Sheets OAuth2",
  "type": "oAuth2Api",
  "data": {
    "grantType": "authorizationCode",
    "authUrl": "https://accounts.google.com/o/oauth2/v2/auth",
    "accessTokenUrl": "https://oauth2.googleapis.com/token",
    "clientId": "{{ stored securely }}",
    "clientSecret": "{{ stored securely }}",
    "scope": "https://www.googleapis.com/auth/spreadsheets"
  }
}
// n8n handles token refresh automatically
```

## API Key Pattern

```javascript
// Header Auth
Credentials → HTTP Header Auth
  Name: "Production API Key"
  Header Name: "X-API-Key"
  Value: stored securely in credential

// Reference in HTTP Request node
HTTP Request
  Authentication: "Predefined Credential Type"
  Credential: "Production API Key"
```

## External Secrets (Enterprise)

```javascript
// v2.0+ integrates with external secret managers
// Vault, AWS Secrets Manager, Azure Key Vault, GCP Secret Manager

// Configuration in n8n settings:
// External Secrets → Add Provider → AWS Secrets Manager
// Secrets auto-sync and available as credential values

// v2.9+: Project-scoped external secret connections
// Different projects can use different secret sources
```

## Credentials API (v2.4+)

```javascript
// Programmatic credential rotation
PATCH /credentials/:id
{
  "data": { "value": "new-api-key-xyz789" }
}
// No workflow changes needed — all referencing nodes use new value
```

## v2.0 Security Changes

| Change | Detail |
|--------|--------|
| `process.env` blocked | `N8N_BLOCK_ENV_ACCESS_IN_NODE=true` default |
| OAuth callback requires auth | `N8N_SKIP_AUTH_ON_OAUTH_CALLBACK=false` default |
| File access sandboxed | ReadWriteFile limited to `~/.n8n-files` |
| Config file permissions | Must be `chmod 600` |

## Common Mistakes

### Wrong
```javascript
// Using process.env in Code node (blocked in v2.0+)
const apiKey = process.env.API_KEY;  // Blocked by default

// Hardcoding secrets in workflow
URL: "https://api.example.com?api_key=abc123"  // Exposed
```

### Correct
```javascript
// Use credential manager
Credentials → "Production API" → Header Auth
HTTP Request → Authentication: "Production API"

// Or External Secrets for enterprise
External Secrets → AWS Secrets Manager → auto-sync
```

## Security Best Practices

1. **Use credentials manager** — Never hardcode or use env vars in Code nodes
2. **External Secrets for enterprise** — Vault/AWS SM integration
3. **Rotate via API** — Automate credential rotation with PATCH endpoint
4. **Limit credential scope** — Separate per environment and project
5. **Use OAuth2 when available** — Better than static keys

## Related

- [Webhooks and Triggers](webhooks-triggers.md)
- [API Integration Pattern](../patterns/api-integration.md)
