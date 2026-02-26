# Custom Domains

> **MCP Validated**: 2026-02-19

## Overview

Railway automatically generates public domains for services (*.up.railway.app), but production applications typically require custom domains. Railway provides automatic SSL certificate provisioning via Let's Encrypt, DNS validation, and support for apex domains, subdomains, and wildcard domains. This pattern covers domain setup, SSL configuration, and multi-environment domain strategies.

## Domain Setup Process

### Step-by-Step
```
1. Service Settings → Networking → Custom Domain
2. Enter domain: api.myapp.com
3. Railway provides CNAME record:
   CNAME: c7a8f3b2.railway.app
4. Add CNAME to DNS provider
5. Railway validates domain ownership
6. Railway issues Let's Encrypt SSL certificate
7. Domain active with HTTPS
```

### Timeline
```
DNS Configuration: 0-10 minutes (propagation)
Domain Validation: ~10 minutes
SSL Certificate Issuance: Automatic after validation
Total Time: ~20 minutes
```

## DNS Configuration

### Subdomain (Recommended)
```
Type: CNAME
Name: api
Value: c7a8f3b2.railway.app
TTL: 3600
```

Result: `api.myapp.com` → Railway service

### Apex Domain (Root)
```
Type: CNAME or ALIAS (if supported)
Name: @ or myapp.com
Value: c7a8f3b2.railway.app
TTL: 3600
```

Note: Some DNS providers (Cloudflare, Route53) support CNAME flattening for apex domains.

### Multiple Domains per Service
```
Service: API
Domains:
├── api.myapp.com (primary)
├── api-v2.myapp.com (version alias)
└── api.legacy-domain.com (migration)
```

Add each domain separately via dashboard.

## SSL Certificate Management

### Automatic Provisioning
```
1. Domain configured in Railway
2. DNS CNAME points to Railway
3. Railway creates _acme-challenge CNAME
4. Let's Encrypt validates domain ownership
5. SSL certificate issued automatically
6. Certificate auto-renews before expiration
```

### Certificate Validation
Railway requires `_acme-challenge` CNAME for validation:
```
Type: CNAME
Name: _acme-challenge.api
Value: _acme-challenge.api.myapp.com.c7a8f3b2.railway.app
TTL: 3600
```

### HTTPS Enforcement
Railway automatically:
- Redirects HTTP to HTTPS
- Enables HSTS headers
- Uses TLS 1.2+ only
- Provides A+ SSL rating

## Multi-Environment Domain Strategy

### Pattern
```
production → myapp.com, api.myapp.com
staging → staging.myapp.com, staging-api.myapp.com
development → dev.myapp.com, dev-api.myapp.com
pr-preview → pr-123.myapp.com (optional)
```

### Configuration

#### Production Environment
```
Service: web
Domain: myapp.com
CNAME: production-web.railway.app

Service: api
Domain: api.myapp.com
CNAME: production-api.railway.app
```

#### Staging Environment
```
Service: web
Domain: staging.myapp.com
CNAME: staging-web.railway.app

Service: api
Domain: staging-api.myapp.com
CNAME: staging-api.railway.app
```

## Cloudflare Integration

CNAME to Railway target. Proxy mode (orange cloud) adds DDoS protection, WAF, caching. DNS-only mode (gray cloud) uses Railway SSL directly. SSL/TLS mode: **Full (strict)** or **Full**.

## Wildcard Domains

CNAME `*` to `wildcard.railway.app`. Matches `tenant1.myapp.com`, `tenant2.myapp.com`, etc. Route in application by extracting subdomain from hostname.

## Domain Verification States

| State | Description | Action |
|-------|-------------|--------|
| **Pending** | Waiting for DNS propagation | Wait or verify DNS |
| **Validating** | Railway checking ownership | Let's Encrypt in progress |
| **Active** | Domain live with SSL | No action needed |
| **Failed** | Validation timeout | Check DNS and retry |

## Custom Domain Variables

Railway does not auto-inject custom domains. Set manually: `railway variables set CUSTOM_DOMAIN=api.myapp.com`.

## Domain Migration

Zero-downtime: add new domain, configure DNS, wait for SSL, update references, remove old domain. For gradual migration, use Cloudflare Load Balancing or Workers.

## Troubleshooting

| Issue | Causes | Solutions |
|-------|--------|----------|
| Stuck on "Validating" | DNS not propagated, wrong CNAME, Cloudflare proxy | Verify with `dig`, check CNAME, disable proxy temporarily |
| SSL cert failed | Missing _acme-challenge CNAME, CAA conflicts | Add _acme-challenge CNAME, remove and re-add domain |
| A record vs CNAME | Railway requires CNAME (IPs change) | Use CNAME; apex domains use ALIAS/ANAME if available |

## Best Practices

1. **Use CNAME**: Always use CNAME, not A records
2. **Separate Environments**: Different domains per environment
3. **SSL Validation**: Ensure _acme-challenge CNAME exists
4. **Cloudflare Full Mode**: Use "Full" or "Full (strict)" SSL
5. **Domain Variables**: Set custom domain as environment variable
6. **Migration Strategy**: Add new domain before removing old
7. **DNS TTL**: Use reasonable TTL (3600s) for flexibility
8. **Monitoring**: Verify SSL expiration alerts

## Related

- [services](../concepts/services.md)
- [environments](../concepts/environments.md)
- [deployment-strategies](../patterns/deployment-strategies.md)
