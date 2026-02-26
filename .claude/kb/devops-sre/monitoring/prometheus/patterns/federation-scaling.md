# Federation and Scaling Patterns

> **Purpose**: Hierarchical federation, Thanos, Mimir, VictoriaMetrics, and multi-cluster strategies
> **MCP Validated**: 2026-02-20

## When to Use

- Single Prometheus exceeds capacity (~10M active series or high query load)
- Need long-term retention beyond local TSDB (months/years)
- Multi-cluster or multi-region monitoring
- Global query view across multiple Prometheus instances

## Scaling Decision Tree

```
Single Prometheus sufficient?
├─ Yes: Keep it simple, tune retention/resources
└─ No: Why?
   ├─ Need long-term retention -> Remote write to Thanos/Mimir/VictoriaMetrics
   ├─ Need global query view -> Federation or Thanos Query
   ├─ Need >10M series -> Horizontal sharding
   └─ Need multi-tenancy -> Mimir or Cortex
```

## Hierarchical Federation

A global Prometheus scrapes selected metrics from regional Prometheus instances.

```yaml
# Global Prometheus scrape config
scrape_configs:
  - job_name: "federate-regional"
    scrape_interval: 30s
    honor_labels: true
    metrics_path: /federate
    params:
      "match[]":
        - '{__name__=~"job:.*"}'             # Recording rules only
        - '{__name__="up"}'                   # Target health
    static_configs:
      - targets:
          - "prometheus-us-east.internal:9090"
          - "prometheus-eu-west.internal:9090"
          - "prometheus-ap-south.internal:9090"
```

### Best Practices for Federation

- Only federate **recording rules** (pre-aggregated metrics), not raw series
- Use `honor_labels: true` to preserve original labels
- Set longer scrape intervals (30s-60s) for federated targets
- Keep federation tree shallow (2 levels maximum)

### Limitations

- Does not provide global query across all raw data
- Adds latency to metric availability at the global level
- Single point of failure at the global Prometheus

## Thanos

Extends Prometheus with global query, long-term storage in object storage, and deduplication.

### Architecture

```
┌─────────────┐    ┌─────────────┐
│ Prometheus A │    │ Prometheus B │   (HA pair or regional instances)
│ + Sidecar    │    │ + Sidecar    │
└──────┬───────┘    └──────┬───────┘
       │ gRPC StoreAPI     │
       └────────┬──────────┘
                v
       ┌────────────────┐        ┌──────────────┐
       │ Thanos Querier │<──────>│ Thanos Store  │
       │ (global query) │        │ Gateway       │
       └────────────────┘        │ (object store)│
                                 └──────────────┘
                                        │
                                 ┌──────────────┐
                                 │ S3 / GCS     │
                                 │ (long-term)  │
                                 └──────────────┘
```

### Key Components

| Component | Purpose |
|-----------|---------|
| **Sidecar** | Runs next to Prometheus, uploads blocks to object storage, serves StoreAPI |
| **Store Gateway** | Serves historical data from object storage |
| **Querier** | Aggregates and deduplicates data from Sidecars + Store Gateway |
| **Compactor** | Compacts, downsamples, and manages retention in object storage |
| **Ruler** | Evaluates recording/alert rules against global view |
| **Receive** | Alternative to Sidecar -- accepts remote write directly |

### Setup

Sidecar runs alongside Prometheus (set `--storage.tsdb.min-block-duration=2h` and `--storage.tsdb.max-block-duration=2h`). Configure object storage via `bucket.yml` with S3, GCS, or Azure Blob.

### When to Choose Thanos

- Existing Prometheus deployment that needs long-term storage
- Gradual migration (Sidecar runs alongside Prometheus)
- Need deduplication of HA Prometheus pairs
- S3/GCS-based cost-effective retention

## Grafana Mimir

Horizontally scalable, multi-tenant TSDB built for large-scale Prometheus deployments.

### Architecture

```
Prometheus ──remote_write──> Mimir Distributor -> Ingester -> Object Storage
                             Mimir Querier <──── Store Gateway
```

### Mimir vs Thanos

Mimir uses remote write (push), has native multi-tenancy with strong isolation, and horizontally scales all components. Configure with `remote_write` to `https://mimir/api/v1/push` and `X-Scope-OrgID` header for tenant isolation.

### When to Choose Mimir

- Greenfield deployment or large-scale environment
- Need strong multi-tenancy (per-team/per-org isolation)
- Grafana Cloud or Grafana ecosystem
- High write throughput (millions of series)

## VictoriaMetrics

High-performance, cost-efficient alternative with Prometheus-compatible APIs.

### Key Advantages

| Feature | Value |
|---------|-------|
| Compression | Up to 10x better than Prometheus |
| Resource usage | 2-5x less RAM and CPU than Thanos/Mimir |
| Query speed | Often faster for high-cardinality queries |
| Deployment | Single binary (simple) or cluster mode |
| Compatibility | Drop-in Prometheus remote write receiver |

### Setup

Single binary or cluster mode. Remote write to `http://victoriametrics:8428/api/v1/write`. Configure retention with `-retentionPeriod=12` (months).

### When to Choose VictoriaMetrics

- Cost optimization is a priority (storage and compute)
- Simpler operations preferred over distributed complexity
- High-cardinality workloads
- Need long retention with minimal infrastructure

## Comparison Summary

| Aspect | Thanos | Mimir | VictoriaMetrics |
|--------|--------|-------|-----------------|
| Complexity | Medium | High | Low |
| Multi-tenancy | Limited | Strong | Basic (Enterprise) |
| Compression | 2-4x | 2-4x | Up to 10x |
| Best for | Extending existing Prometheus | Enterprise multi-tenant | Cost-efficient simplicity |
| Object storage | Required | Required | Optional |
| License | Apache 2.0 | AGPL 3.0 | Apache 2.0 (OSS) |

## Horizontal Sharding

For extremely high cardinality, shard Prometheus by hash of target labels:

```yaml
# Prometheus Shard 0
scrape_configs:
  - job_name: myapp
    relabel_configs:
      - source_labels: [__address__]
        modulus: 2
        target_label: __tmp_hash
        action: hashmod
      - source_labels: [__tmp_hash]
        regex: "0"
        action: keep
```

Then use Thanos Querier or a similar aggregation layer to provide a unified query view across shards.

## Best Practices

- Start simple: single Prometheus with remote write for long-term storage
- Use recording rules to reduce what gets federated or remote-written
- Choose Thanos for gradual migration, Mimir for greenfield, VictoriaMetrics for cost
- Monitor the monitoring: track Prometheus resource usage, WAL size, and rule evaluation time
- Set up deduplication when running HA Prometheus pairs

## Related

- [Storage](../concepts/storage.md) - Local TSDB and remote write details
- [Recording Rules](recording-rules.md) - Pre-compute before federation
- [Kubernetes Monitoring](kubernetes-monitoring.md) - Multi-cluster patterns
- [Grafana KB](../../grafana/) - Visualization for scaled deployments
