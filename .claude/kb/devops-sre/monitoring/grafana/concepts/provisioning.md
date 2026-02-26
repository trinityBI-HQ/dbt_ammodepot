# Provisioning (Dashboards-as-Code)

> **Purpose**: File-based provisioning, Terraform provider, Grafonnet, and API automation
> **MCP Validated**: 2026-02-19

## Overview

Grafana supports multiple approaches to manage dashboards, data sources, and alerting as code, enabling version control, peer review, and automated deployment.

## Provisioning Approaches

| Approach | Best For | Complexity |
|----------|----------|------------|
| **File provisioning** | Simple setups, Docker/K8s | Low |
| **Terraform provider** | Multi-resource, multi-env | Medium |
| **Grafonnet (Jsonnet)** | Complex, reusable dashboards | High |
| **HTTP API** | Dynamic/runtime management | Medium |

## File-Based Provisioning

Grafana loads YAML from `/etc/grafana/provisioning/` at startup.

### Dashboard Provider

```yaml
# provisioning/dashboards/default.yaml
apiVersion: 1
providers:
  - name: default
    orgId: 1
    folder: "Infrastructure"
    type: file
    disableDeletion: false
    updateIntervalSeconds: 30
    allowUiUpdates: false
    options:
      path: /var/lib/grafana/dashboards
      foldersFromFilesStructure: true
```

Place exported JSON files in the provider path. Remove the `id` field (auto-assigned), keep `uid` (stable reference).

## Terraform Provider

The `grafana/grafana` provider manages Grafana resources declaratively.

```hcl
terraform {
  required_providers {
    grafana = { source = "grafana/grafana", version = "~> 3.0" }
  }
}
provider "grafana" {
  url  = var.grafana_url
  auth = var.grafana_api_key
}
```

### Key Resources

```hcl
resource "grafana_data_source" "prometheus" {
  type = "prometheus"
  name = "Prometheus"
  url  = "http://prometheus:9090"
  json_data_encoded = jsonencode({ httpMethod = "POST", timeInterval = "15s" })
}

resource "grafana_folder" "infra" { title = "Infrastructure" }

resource "grafana_dashboard" "node" {
  folder      = grafana_folder.infra.id
  config_json = file("${path.module}/dashboards/node-overview.json")
}

resource "grafana_contact_point" "slack" {
  name = "Slack Platform"
  slack { url = var.slack_webhook_url }
}
```

## Grafonnet (Jsonnet Library)

Generates dashboard JSON programmatically.

```bash
# Install
go install github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@latest
jb init && jb install github.com/grafana/grafonnet/gen/grafonnet-latest@main
```

```jsonnet
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

g.dashboard.new('API Performance')
+ g.dashboard.withUid('api-perf')
+ g.dashboard.withPanels([
  g.panel.timeSeries.new('Request Rate')
  + g.panel.timeSeries.queryOptions.withTargets([
    g.query.prometheus.new('Prometheus',
      'sum(rate(http_requests_total[5m])) by (service)')
  ])
  + g.panel.timeSeries.gridPos.withW(12)
  + g.panel.timeSeries.gridPos.withH(8),
])
```

Build: `jsonnet -J vendor/ dashboard.jsonnet > dashboard.json`

## HTTP API

```bash
# Export dashboard
curl -H "Authorization: Bearer $KEY" "$URL/api/dashboards/uid/my-dash" \
  | jq '.dashboard' > dash.json

# Import dashboard
curl -X POST -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -d '{"dashboard":'"$(cat dash.json)"',"overwrite":true}' "$URL/api/dashboards/db"
```

## Best Practices

- **Version control dashboard JSON**: Treat dashboards like application code
- **Use `uid` not `id`**: UIDs are stable across environments
- **Disable UI edits in prod**: Set `allowUiUpdates: false`
- **Use Terraform for multi-resource**: Data sources, folders, alerts together
- **Use Grafonnet for complex dashboards**: When JSON becomes unmaintainable
- **Separate by environment**: Terraform workspaces or variables for dev/staging/prod

## Related

- [Dashboards and Panels](dashboards-panels.md) - Dashboard JSON structure
- [Dashboard-as-Code Pattern](../patterns/dashboard-as-code.md) - CI/CD pipelines
- [Terraform KB](../../../iac/terraform/) - Terraform fundamentals
