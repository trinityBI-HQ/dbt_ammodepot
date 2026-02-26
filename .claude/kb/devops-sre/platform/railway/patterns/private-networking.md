# Private Networking

> **MCP Validated**: 2026-02-19

## Overview

Railway's private network on Metal infrastructure enables secure, cost-free service-to-service communication within a project. Private networking eliminates egress charges, reduces latency (direct ISP peering), and provides automatic service discovery via DNS. All services and databases within a project communicate over the private network using `*.railway.internal` domains. Metal adds **static inbound IPs** for firewall allowlisting and an **anycast edge network** for global routing.

## The Pattern

### Public vs Private URLs

```javascript
// Public domain (internet-accessible)
// Incurs egress charges, requires authentication
const publicUrl = process.env.RAILWAY_PUBLIC_DOMAIN;
// api-production.up.railway.app

// Private domain (internal only)
// Zero egress cost, internal routing
const privateUrl = process.env.RAILWAY_PRIVATE_DOMAIN;
// api.railway.internal
```

### Private Network Architecture
```
Project: E-commerce
├── web-app (public: web.up.railway.app)
│   └── Calls API privately: http://api.railway.internal:3000
├── api-service (public: api.up.railway.app, private: api.railway.internal)
│   ├── Calls DB privately: postgresql://postgres.railway.internal:5432
│   └── Calls Redis privately: redis://redis.railway.internal:6379
├── worker (no public domain)
│   └── Calls API privately: http://api.railway.internal:3000
├── postgres (private only: postgres.railway.internal)
└── redis (private only: redis.railway.internal)
```

## Database Connections

Always use `*_PRIVATE_URL` for zero egress cost:
```
DATABASE_PRIVATE_URL → postgresql://postgres.railway.internal:5432/railway
REDIS_PRIVATE_URL    → redis://redis.railway.internal:6379
MONGO_PRIVATE_URL    → mongodb://mongo.railway.internal:27017/railway
```

## Service-to-Service Communication

- **Server-side calls**: Use private URL `http://${RAILWAY_PRIVATE_DOMAIN}:PORT`
- **Client-side calls**: Must use public URL (browser cannot access private network)
- **Workers**: Use private URLs, no public domain needed

## Variable References

### Using Service References
```bash
# API service automatically provides:
RAILWAY_PRIVATE_DOMAIN=api.railway.internal

# Worker service references API:
API_URL=http://${{api.RAILWAY_PRIVATE_DOMAIN}}:3000

# Resolves to: http://api.railway.internal:3000
```

### Database References
```bash
# Postgres service provides:
DATABASE_PRIVATE_URL=postgresql://postgres.railway.internal:5432/railway

# API service references database:
DATABASE_URL=${{postgres.DATABASE_PRIVATE_URL}}

# Worker service references same database:
DATABASE_URL=${{postgres.DATABASE_PRIVATE_URL}}
```

## Port Configuration

Services must listen on `PORT` env variable. Include port when calling private services: `http://api.railway.internal:3000`. Railway handles port mapping for public URLs.

## DNS Resolution

### Automatic Service Discovery
```
Service Name → DNS Resolution
├── api → api.railway.internal
├── web → web.railway.internal
├── worker → worker.railway.internal
├── postgres → postgres.railway.internal
└── redis → redis.railway.internal
```

### DNS Lookup
```bash
# Inside Railway container
nslookup api.railway.internal
# Returns internal IP

dig api.railway.internal
# Returns A record for internal routing
```

## Security Benefits

### Private-Only Services
```
Worker Service:
├── Public Networking: Disabled
├── Private Domain: worker.railway.internal
├── Accessible by: Other services in project only
└── Internet: Cannot reach this service
```

Use for:
- Background workers
- Internal APIs
- Admin services
- Database proxies

### Network Isolation
```
Project A:
├── api-a.railway.internal (isolated to Project A)

Project B:
├── api-b.railway.internal (isolated to Project B)

api-a cannot reach api-b (different projects)
```

## Static Inbound IPs (Metal)

Railway Metal provides static inbound IPs for services that need firewall allowlisting:
- Available for all services on Metal infrastructure
- Useful for database connections requiring IP whitelisting
- Configure via service networking settings
- IPs persist across deployments and redeployments

## Anycast Edge Network (Metal)

Global traffic routing via anycast edge network:
- Requests routed to nearest edge node
- Lower latency for geographically distributed users
- Automatic failover between edge locations

## Cost Optimization

Private communication eliminates egress charges and provides lower latency via internal routing. Use `RAILWAY_PRIVATE_DOMAIN` for all server-side calls between services.

## Debugging Private Network

```bash
# Railway shell - test connectivity
railway shell
curl http://api.railway.internal:3000/health
nslookup api.railway.internal
```

## Common Patterns

- **API Gateway**: Public gateway routes to private microservices (`*.railway.internal`)
- **Microservices Mesh**: All services communicate via private network
- **Background Jobs**: API enqueues to Redis (private), worker polls and processes

## Best Practices

1. **Use Private for Internal**: Always use private URLs for service-to-service calls
2. **Database Connections**: Use DATABASE_PRIVATE_URL, not DATABASE_URL
3. **Server-Side Only**: Private network not accessible from browser
4. **Include Port**: Specify port when calling private services
5. **Variable References**: Use `${{service.RAILWAY_PRIVATE_DOMAIN}}` pattern
6. **Security**: Disable public networking for internal-only services
7. **Cost Savings**: Private network eliminates egress charges

## Related

- [services](../concepts/services.md)
- [variables](../concepts/variables.md)
- [databases](../concepts/databases.md)
