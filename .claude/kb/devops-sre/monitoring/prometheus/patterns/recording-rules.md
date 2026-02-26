# Recording Rules Patterns

> **Purpose**: Pre-computed queries, naming conventions, aggregation hierarchies, and performance optimization
> **MCP Validated**: 2026-02-20

## When to Use

- Expensive PromQL queries used in dashboards or alerts (reduce query latency)
- Aggregation hierarchies (e.g., per-pod -> per-service -> per-cluster)
- SLO/SLI computation requiring consistent pre-computed metrics
- Queries that span large numbers of series or long time ranges

## How Recording Rules Work

Recording rules evaluate PromQL expressions at regular intervals and store the result as new time series. This turns expensive queries into simple metric lookups.

```
Expensive query (evaluated every interval)
  -> New time series (stored in TSDB)
    -> Fast lookup in dashboards/alerts
```

## Rule File Structure

```yaml
# rules/recording-rules.yml
groups:
  - name: http_request_rates
    interval: 1m                      # Evaluation interval (default: global)
    rules:
      - record: job:http_requests:rate5m
        expr: sum by (job) (rate(http_requests_total[5m]))

      - record: job:http_errors:rate5m
        expr: sum by (job) (rate(http_requests_total{status=~"5.."}[5m]))

      - record: job:http_error_ratio:rate5m
        expr: |
          job:http_errors:rate5m
          / job:http_error_ratio:rate5m
```

Reference in `prometheus.yml`:

```yaml
rule_files:
  - "rules/recording-rules.yml"
  - "rules/alerts.yml"
```

## Naming Convention

The standard naming convention is `level:metric:operations`:

```
<aggregation_level>:<metric_name>:<operations>
```

| Part | Meaning | Example |
|------|---------|---------|
| `level` | Labels remaining after aggregation | `job`, `namespace:service` |
| `metric` | Original metric name | `http_requests`, `cpu_usage` |
| `operations` | Applied functions | `rate5m`, `sum`, `rate5m_avg` |

### Examples

```yaml
# Per-job request rate
job:http_requests_total:rate5m

# Per-namespace, per-service error ratio
namespace_service:http_errors:ratio_rate5m

# Cluster-wide CPU usage
cluster:node_cpu:ratio_rate5m

# Per-instance disk prediction
instance:node_filesystem_avail:predict_linear_4h
```

## Aggregation Hierarchy Pattern

Build metrics from fine-grained to coarse, reusing intermediate results:

```yaml
groups:
  - name: request_rate_hierarchy
    rules:
      # Level 1: Per pod (finest granularity)
      - record: namespace_pod:http_requests:rate5m
        expr: sum by (namespace, pod) (rate(http_requests_total[5m]))

      # Level 2: Per service (aggregate pods)
      - record: namespace_service:http_requests:rate5m
        expr: sum by (namespace, service) (namespace_pod:http_requests:rate5m)

      # Level 3: Per namespace (aggregate services)
      - record: namespace:http_requests:rate5m
        expr: sum by (namespace) (namespace_service:http_requests:rate5m)

      # Level 4: Cluster total (aggregate namespaces)
      - record: cluster:http_requests:rate5m
        expr: sum(namespace:http_requests:rate5m)
```

Each level reuses the previous level's recording rule, reducing computation.

## SLO/SLI Recording Rules

```yaml
groups:
  - name: slo_rules
    interval: 30s
    rules:
      # Error ratio (SLI)
      - record: service:http_error_ratio:rate5m
        expr: |
          sum by (service) (rate(http_requests_total{status=~"5.."}[5m]))
          / sum by (service) (rate(http_requests_total[5m]))

      # Availability (1 - error ratio)
      - record: service:http_availability:rate5m
        expr: 1 - service:http_error_ratio:rate5m

      # Latency SLI (% of requests under threshold)
      - record: service:http_latency_sli:rate5m
        expr: |
          sum by (service) (rate(http_request_duration_seconds_bucket{le="0.5"}[5m]))
          / sum by (service) (rate(http_request_duration_seconds_count[5m]))

      # Error budget remaining (monthly, target 99.9%)
      - record: service:error_budget_remaining:ratio
        expr: |
          1 - (
            service:http_error_ratio:rate5m
            / (1 - 0.999)
          )
```

## Infrastructure Recording Rules

```yaml
groups:
  - name: node_rules
    rules:
      # CPU utilization per node
      - record: instance:node_cpu:ratio_rate5m
        expr: |
          1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m]))

      # Memory utilization per node
      - record: instance:node_memory:ratio
        expr: |
          1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes

      # Disk utilization per mountpoint
      - record: instance_mountpoint:node_disk:ratio
        expr: |
          1 - node_filesystem_avail_bytes{fstype=~"ext4|xfs"}
              / node_filesystem_size_bytes{fstype=~"ext4|xfs"}

      # Network throughput per node
      - record: instance:node_network_receive:rate5m
        expr: sum by (instance) (rate(node_network_receive_bytes_total{device!="lo"}[5m]))
```

## Validation

```bash
promtool check rules rules/recording-rules.yml       # Syntax check
promtool test rules tests/recording-rules-test.yml    # Unit test with input_series + expected output
```

Test files define `input_series` (synthetic data), `eval_time`, and `exp_samples` to verify recording rule output matches expectations.

## Best Practices

- **Name consistently**: Follow `level:metric:operations` convention
- **Build hierarchies**: Reuse recording rules in subsequent levels
- **Set appropriate intervals**: Use shorter intervals (30s) for SLO rules, 1m for general
- **Avoid recording everything**: Only pre-compute queries used in dashboards or alerts
- **Test with promtool**: Validate syntax and expected output before deployment
- **Document the chain**: Comment which recording rules feed which dashboards/alerts
- **Monitor rule evaluation**: Watch `prometheus_rule_evaluation_duration_seconds` for slow rules

## Related

- [PromQL](../concepts/promql.md) - Query language fundamentals
- [Alerting Patterns](alerting-patterns.md) - Using recording rules in alerts
- [Storage](../concepts/storage.md) - Impact on TSDB storage
