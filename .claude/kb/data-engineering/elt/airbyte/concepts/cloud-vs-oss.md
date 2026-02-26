# Cloud vs OSS

> **Purpose**: Deployment options comparison - managed SaaS vs self-hosted open source
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Airbyte offers multiple deployment models: **Cloud** (managed SaaS), **OSS** (self-hosted open source), **Enterprise** (self-hosted with enterprise features), and **Enterprise Flex** (hybrid deployment, Oct 2025). A mid-tier **Airbyte Plus** pricing option was introduced in Oct 2025 between Cloud and Enterprise.

## Quick Reference

| Feature | Cloud | Plus | OSS | Enterprise | Enterprise Flex |
|---------|-------|------|-----|-----------|----------------|
| **Cost** | Credits | Credits | Free | License + infra | License + infra |
| **Control Plane** | Airbyte | Airbyte | Self | Self | **Airbyte-managed** |
| **Data Plane** | Airbyte | Airbyte | Self | Self | **Self-hosted** |
| **Scaling** | Automatic | Automatic | Manual | Manual | Manual (data) |
| **Updates** | Automatic | Automatic | Manual | Manual | Hybrid |
| **SSO/RBAC** | Basic | Yes | No | Advanced | Advanced |
| **Compliance** | SOC 2 | SOC 2 | Self | SOC 2 | SOC 2 |
| **Data Location** | Airbyte | Airbyte | Yours | Yours | **Yours** |

## The Pattern

### Airbyte Cloud Architecture

```
┌─────────────────────────────────────────┐
│         Airbyte Cloud (SaaS)            │
│  ┌──────────────────────────────────┐   │
│  │  Control Plane (Airbyte-hosted)  │   │
│  │  - UI/API                        │   │
│  │  - Scheduling                    │   │
│  │  - Metadata                      │   │
│  └──────────────────────────────────┘   │
│                  │                       │
│  ┌──────────────┴────────────────────┐  │
│  │  Data Plane (Your VPC - optional) │  │
│  │  - Connector execution            │  │
│  │  - Data never touches Airbyte     │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
        │                        │
    [Source]                [Destination]
```

### Airbyte Enterprise Flex Architecture (Hybrid)

```
┌───────────────── Airbyte-Managed ────────────────┐
│  Control Plane (Airbyte Cloud)                   │
│  - UI, API, Scheduling, Metadata                 │
└────────────────────┬─────────────────────────────┘
                     │ (secure connection)
┌────────────────────┴─────────────────────────────┐
│  Data Plane (Your VPC)                           │
│  - Connector execution, data processing          │
│  - Data never leaves your infrastructure         │
└────────────────────┬──────────┬──────────────────┘
                 [Source]    [Destination]
```

## Deployment Comparison

### Airbyte Cloud

**Pros:**
- Zero infrastructure management
- Automatic connector updates and patches
- Elastic scaling for large data volumes
- Built-in monitoring and alerting
- Professional support with SLA
- SOC 2 Type II compliance out of the box

**Cons:**
- Credit-based pricing can be expensive at scale
- Limited customization options
- Vendor lock-in
- Control plane hosted by Airbyte (metadata visibility)

**Use when:**
- Small to medium data volumes (< 10TB/month)
- Prefer simplicity over control
- Lack DevOps resources for self-hosting
- Need fast time-to-value
- Compliance requirements met by Airbyte's certifications

### Airbyte OSS

**Pros:**
- Free and open source
- Full code customization
- Complete data control (no vendor access)
- Deploy on-premises or in your VPC
- No usage-based pricing

**Cons:**
- Requires DevOps expertise (Docker/Kubernetes)
- Manual updates and patches
- Self-managed scaling and monitoring
- Community support only (no SLA)
- Must implement own security controls

**Use when:**
- Large data volumes (> 10TB/month)
- Need full customization
- Regulatory requirements mandate on-prem
- Have DevOps team to manage infrastructure
- Cost-sensitive workloads

### Airbyte Enterprise

Combines self-hosting with enterprise features:

- **RBAC**: Role-based access control
- **SSO**: SAML/OAuth integration
- **Audit logs**: Compliance tracking
- **Professional support**: SLA-backed
- **License-based pricing**: Not usage-based

### Airbyte Enterprise Flex (Oct 2025)

Hybrid deployment model with **Airbyte-managed control plane** and **self-hosted data planes**:

- **Data stays in your infrastructure** (data plane runs in your VPC)
- **Control plane managed by Airbyte** (scheduling, UI, API, metadata)
- Best of both worlds: managed convenience + data sovereignty
- Same enterprise features (RBAC, SSO, audit logs)

**Use when:** Regulatory requirements demand data stays on-premises, but you want managed infrastructure for the control plane.

### Airbyte Plus (Oct 2025)

Mid-tier pricing between Cloud and Enterprise:
- Priority support, advanced RBAC/SSO
- Credit-based pricing with higher limits
- No self-hosting required

## Pricing

### Cloud Pricing

```
Credits consumed = Data volume × Sync frequency × Connector complexity

Example:
- 1GB synced = ~10 credits
- 1000 credits = $15
- Syncing 100GB/month = ~1000 credits = $15/month
- Syncing 10TB/month = ~100,000 credits = $1,500/month
```

**Factors:**
- Data volume (bytes transferred)
- Sync frequency (hourly vs daily)
- Connector type (certified vs custom)

### OSS Pricing

```
Total cost = Infrastructure + Personnel

Infrastructure:
- AWS t3.xlarge (4 vCPU, 16GB RAM): ~$120/month
- RDS Postgres (db.t3.medium): ~$60/month
- EBS storage: ~$20/month
Total: ~$200/month

Personnel:
- DevOps engineer (20% FTE): ~$30K/year
- Total annual cost: ~$32,400
```

## Common Mistakes

### Wrong

```yaml
# Anti-pattern: Cloud for massive data volumes
deployment: airbyte_cloud
data_volume: 50TB/month
sync_frequency: hourly
# Cost: ~$75,000/month in credits!
```

### Correct

```yaml
# Correct: OSS for high-volume workloads
deployment: airbyte_oss
infrastructure: kubernetes
data_volume: 50TB/month
sync_frequency: hourly
# Cost: ~$3,000/month (infra + personnel)
```

## Self-Hosting OSS

### Docker Compose (Development)

```bash
git clone https://github.com/airbytehq/airbyte.git
cd airbyte
./run-ab-platform.sh

# Access UI at http://localhost:8000
```

### Kubernetes (Production)

```bash
# Using Helm
helm repo add airbyte https://airbytehq.github.io/helm-charts
helm install airbyte airbyte/airbyte --namespace airbyte --create-namespace

# Configure persistent storage
values.yaml:
  postgresql:
    persistence:
      enabled: true
      size: 100Gi
  minio:
    persistence:
      size: 500Gi
```

## Migration Path

**Cloud → OSS:**
1. Export connection configurations via API
2. Deploy OSS infrastructure
3. Re-create sources, destinations, connections
4. Test in dev environment
5. Cutover with minimal downtime

**OSS → Cloud:**
1. Sign up for Airbyte Cloud
2. Use Terraform to recreate configs
3. Disable OSS connections
4. Enable Cloud connections
5. Decommission OSS infrastructure

## Security Considerations

| Aspect | Cloud | OSS |
|--------|-------|-----|
| Credentials | Encrypted, Airbyte-managed | Self-managed (Secrets Manager) |
| Network | VPC peering available | Full control |
| Compliance | SOC 2, GDPR, HIPAA | Self-certified |
| Data visibility | Metadata visible to Airbyte | Fully private |

## Related

- [connections](../concepts/connections.md)
- [multi-environment-setup](../patterns/multi-environment-setup.md)
- [monitoring-observability](../patterns/monitoring-observability.md)
