# Cloud vs OSS

> **Purpose**: Deployment options comparison - managed SaaS vs self-hosted open source
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Airbyte offers multiple deployment models: **Cloud** (managed SaaS), **OSS** (self-hosted open source), **Enterprise** (self-hosted with enterprise features), and **Enterprise Flex** (hybrid, Oct 2025). A mid-tier **Airbyte Plus** option was introduced Oct 2025.

## Quick Reference

| Feature | Cloud | Plus | OSS | Enterprise | Flex |
|---------|-------|------|-----|-----------|------|
| **Cost** | Credits | Credits | Free | License | License |
| **Control Plane** | Airbyte | Airbyte | Self | Self | Airbyte |
| **Data Plane** | Airbyte | Airbyte | Self | Self | Self |
| **Scaling** | Auto | Auto | Manual | Manual | Manual |
| **Updates** | Auto | Auto | Manual | Manual | Hybrid |
| **SSO/RBAC** | Basic | Yes | No | Advanced | Advanced |
| **Compliance** | SOC 2 | SOC 2 | Self | SOC 2 | SOC 2 |
| **Data Location** | Airbyte | Airbyte | Yours | Yours | Yours |

## Deployment Comparison

### Airbyte Cloud
**Use when**: Small-medium volumes (<10TB/mo), prefer simplicity, lack DevOps resources, need fast time-to-value.
**Pros**: Zero infra management, auto updates, elastic scaling, SOC 2, SLA support.
**Cons**: Credit-based pricing expensive at scale, limited customization, vendor lock-in.

### Airbyte OSS
**Use when**: Large volumes (>10TB/mo), need full customization, regulatory on-prem requirements, have DevOps team.
**Pros**: Free, full code customization, complete data control, no usage-based pricing.
**Cons**: Requires DevOps expertise, manual updates/scaling, community-only support.

### Airbyte Enterprise
Self-hosted with RBAC, SSO (SAML/OAuth), audit logs, SLA-backed support, license-based pricing.

### Enterprise Flex (Oct 2025)
Hybrid: Airbyte-managed control plane + self-hosted data plane. Data stays in your VPC. Best for regulatory requirements + managed convenience.

### Airbyte Plus (Oct 2025)
Mid-tier: priority support, advanced RBAC/SSO, credit-based pricing with higher limits.

## Pricing

**Cloud**: ~10 credits per 1GB synced, 1000 credits = $15. Example: 100GB/mo ~ $15/mo, 10TB/mo ~ $1,500/mo.

**OSS**: Infrastructure (~$200/mo for t3.xlarge + RDS + EBS) + personnel (~20% DevOps FTE).

## Self-Hosting

```bash
# Docker Compose (dev)
git clone https://github.com/airbytehq/airbyte.git && cd airbyte
./run-ab-platform.sh  # UI at http://localhost:8000

# Kubernetes (prod)
helm repo add airbyte https://airbytehq.github.io/helm-charts
helm install airbyte airbyte/airbyte --namespace airbyte --create-namespace
```

## Migration Path

**Cloud -> OSS**: Export configs via API, deploy OSS infra, re-create connections, test, cutover.
**OSS -> Cloud**: Sign up, use Terraform to recreate configs, disable OSS, enable Cloud, decommission.

## Security

| Aspect | Cloud | OSS |
|--------|-------|-----|
| Credentials | Encrypted, Airbyte-managed | Self-managed (Secrets Manager) |
| Network | VPC peering available | Full control |
| Compliance | SOC 2, GDPR, HIPAA | Self-certified |
| Data visibility | Metadata visible to Airbyte | Fully private |

## Common Mistakes

| Don't | Do |
|-------|-----|
| Cloud for 50TB/mo ($75K/mo!) | OSS/Enterprise for high-volume |
| Same workspace for all envs | Separate workspaces per env |
| Skip staging | Always test in staging first |

## Related

- [connections](../concepts/connections.md)
- [multi-environment-setup](../patterns/multi-environment-setup.md)
- [monitoring-observability](../patterns/monitoring-observability.md)
