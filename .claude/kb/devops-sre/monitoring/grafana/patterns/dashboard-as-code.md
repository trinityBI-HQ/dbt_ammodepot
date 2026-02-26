# Dashboard-as-Code Patterns

> **Purpose**: Provisioning workflows, Terraform patterns, CI/CD pipelines, multi-env deployment
> **MCP Validated**: 2026-02-19

## When to Use

- Version-controlling dashboard configurations
- Automating dashboard deployment across environments
- Standardizing monitoring across teams and services
- Integrating Grafana provisioning into CI/CD pipelines

## File Provisioning Setup

### Docker Compose Stack

```yaml
services:
  grafana:
    image: grafana/grafana-oss:11.5.0
    ports: ["3000:3000"]
    environment:
      GF_SECURITY_ADMIN_PASSWORD: "${GRAFANA_ADMIN_PASSWORD}"
    volumes:
      - ./grafana/provisioning:/etc/grafana/provisioning
      - ./grafana/dashboards:/var/lib/grafana/dashboards
  prometheus:
    image: prom/prometheus:v2.53.0
    ports: ["9090:9090"]
    volumes: ["./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml"]
  loki:
    image: grafana/loki:3.3.0
    ports: ["3100:3100"]
```

### Project Directory Structure

```
monitoring/
├── docker-compose.yaml
├── grafana/
│   ├── provisioning/
│   │   ├── dashboards/default.yaml
│   │   ├── datasources/datasources.yaml
│   │   └── alerting/alert-rules.yaml
│   └── dashboards/
│       ├── infrastructure/
│       │   └── node-overview.json
│       └── application/
│           └── api-red.json
└── prometheus/prometheus.yml
```

## Terraform Patterns

### Module Structure

```
terraform/
├── modules/grafana-stack/
│   ├── main.tf, datasources.tf, dashboards.tf, alerting.tf, variables.tf
├── environments/
│   ├── dev/main.tf + terraform.tfvars
│   ├── staging/main.tf + terraform.tfvars
│   └── prod/main.tf + terraform.tfvars
└── dashboards/              # Shared JSON files
```

### Environment-Specific Configuration

```hcl
module "grafana" {
  source          = "../../modules/grafana-stack"
  grafana_url     = "https://grafana.prod.example.com"
  grafana_api_key = var.grafana_api_key
  environment     = "production"
  cpu_alert_threshold   = 80
  error_rate_threshold  = 0.01
  pagerduty_key         = var.pagerduty_key
  slack_webhook_url     = var.slack_webhook_url
}
```

### Dashboard Resource with Templating

```hcl
resource "grafana_dashboard" "service_red" {
  for_each    = toset(var.services)
  folder      = grafana_folder.application.id
  config_json = templatefile("${path.module}/templates/red-dashboard.json.tftpl", {
    service_name = each.key
    environment  = var.environment
    datasource   = grafana_data_source.prometheus.uid
  })
}
```

## Grafonnet Library

### Reusable Panel Function

```jsonnet
// lib/panels.libsonnet
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
{
  requestRate(ds, svc)::
    g.panel.timeSeries.new('Request Rate')
    + g.panel.timeSeries.queryOptions.withTargets([
      g.query.prometheus.new(ds,
        'sum(rate(http_requests_total{service="%s"}[$__rate_interval]))' % svc)
    ]) + g.panel.timeSeries.standardOptions.withUnit('reqps'),
}
```

### Service Dashboard Generator

```jsonnet
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local panels = import '../lib/panels.libsonnet';
local service = std.extVar('service');

g.dashboard.new('%s - RED Dashboard' % service)
+ g.dashboard.withUid('%s-red' % std.asciiLower(service))
+ g.dashboard.withPanels(g.util.grid.makeGrid([
    panels.requestRate('Prometheus', service),
  ], panelWidth=12, panelHeight=8))
```

Build: `jsonnet -J vendor/ --ext-str service=api-gateway service.jsonnet > api-gateway.json`

## CI/CD Pipeline (GitHub Actions)

```yaml
name: Deploy Grafana Dashboards
on:
  push:
    branches: [main]
    paths: ['monitoring/**']
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Validate JSON
        run: for f in monitoring/grafana/dashboards/**/*.json; do jq empty "$f"; done
      - name: Terraform plan
        working-directory: monitoring/terraform/environments/prod
        run: terraform init && terraform plan
  deploy:
    needs: validate
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
      - name: Terraform apply
        working-directory: monitoring/terraform/environments/prod
        env: { TF_VAR_grafana_api_key: "${{ secrets.GRAFANA_API_KEY }}" }
        run: terraform init && terraform apply -auto-approve
```

## Version-Controlled Workflow

```
Edit UI -> Export JSON -> Remove "id" field -> git commit -> PR review
  -> merge to main -> CI validates JSON -> Terraform plan -> Terraform apply
```

## Best Practices

- **Export, then codify**: Build in UI, export JSON, manage as code
- **Remove `id`, keep `uid`**: `id` is instance-specific; `uid` is portable
- **Use `foldersFromFilesStructure`**: File system dirs become Grafana folders
- **Template dashboards**: Use Grafonnet or `templatefile` for service-specific dashboards
- **Validate in CI**: Check JSON syntax and Terraform plan before deploying
- **Separate state per env**: Each environment gets its own Terraform state
- **Pin versions**: Pin Grafana, Prometheus, and provider versions

## Related

- [Provisioning](../concepts/provisioning.md) - Provisioning fundamentals
- [Infrastructure Monitoring](infrastructure-monitoring.md) - Dashboard content patterns
- [Terraform KB](../../../iac/terraform/) - Terraform patterns
- [GitHub KB](../../../version-control/github/) - GitHub Actions CI/CD
