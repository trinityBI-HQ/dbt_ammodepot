# Prometheus Storage

> **Purpose**: Local TSDB internals, remote write/read, retention policies, compaction, and backups
> **MCP Validated**: 2026-02-20

## Overview

Prometheus stores time series data in a local on-disk TSDB (Time Series Database) optimized for append-heavy workloads. For long-term retention and horizontal scaling, Prometheus supports remote write and remote read protocols to offload data to external storage systems.

## Local TSDB Architecture

```
data/
├── chunks_head/          # In-memory + memory-mapped active chunks
├── wal/                  # Write-Ahead Log for crash recovery
│   ├── 00000001
│   └── 00000002
├── 01BKGV7JBM69T2G1BGBGM6KB12/   # Compacted block
│   ├── chunks/           # Compressed chunk files
│   ├── index             # Inverted index for label lookups
│   ├── meta.json         # Block metadata (time range, stats)
│   └── tombstones        # Deleted series markers
└── 01BKGTZQ1SYQJTR4PB43C8PD98/   # Another compacted block
```

### Data Flow

```
Incoming samples -> Head Block (in-memory, 2h default)
                      -> WAL (crash recovery)
                      -> Compaction -> Persistent Blocks (on disk)
                                        -> Further compaction (merge blocks)
```

### Head Block

The head block holds the last 2 hours (minimum) of data in memory. Samples are first written to the WAL for durability, then appended to in-memory chunks. When the head block's range expires, it is flushed ("cut") to a persistent block on disk.

### Compaction

Prometheus merges smaller blocks into larger ones to improve query performance and reduce file count. The compaction process also applies tombstones (deletes) and drops out-of-range data.

Default compaction levels: 2h -> 6h -> 18h -> 54h (3x factor).

## Retention Configuration

```bash
# Time-based retention (default: 15 days)
prometheus --storage.tsdb.retention.time=30d

# Size-based retention (keeps removing oldest blocks until under limit)
prometheus --storage.tsdb.retention.size=50GB

# Both (whichever triggers first)
prometheus --storage.tsdb.retention.time=30d --storage.tsdb.retention.size=50GB
```

### Storage Sizing

Rule of thumb: **1-2 bytes per sample** after compression.

```
Storage = samples_per_second * bytes_per_sample * retention_seconds
Example: 100,000 series * 15s interval * 2 bytes * 30 days
       = 100,000 / 15 * 2 * 30 * 86400 = ~34 GB
```

## Remote Write

Prometheus forwards samples in real-time to external storage backends for long-term retention and global querying.

```yaml
remote_write:
  - url: "https://thanos-receive.example.com/api/v1/receive"
    write_relabel_configs:
      - source_labels: [__name__]
        regex: "go_.*"
        action: drop                    # Don't forward Go runtime metrics
    queue_config:
      capacity: 10000
      max_shards: 30
      max_samples_per_send: 5000
    metadata_config:
      send: true
      send_interval: 1m
```

### Remote Write 2.0 (Experimental)

Adds native support for metadata, exemplars, created timestamps, and native histograms within the protocol. Uses content negotiation for backwards compatibility.

### Compatible Backends

| Backend | Protocol | Notes |
|---------|----------|-------|
| **Thanos Receive** | Remote Write 1.0/2.0 | S3/GCS object storage |
| **Grafana Mimir** | Remote Write 1.0/2.0 | Multi-tenant, horizontally scalable |
| **VictoriaMetrics** | Remote Write 1.0 | High compression, simple deployment |
| **Cortex** | Remote Write 1.0 | Predecessor to Mimir |
| **InfluxDB** | Remote Write adapter | InfluxDB as time series backend |
| **Google Cloud Managed Prometheus** | Remote Write | GCP-native managed service |
| **Amazon Managed Prometheus** | Remote Write | AWS-native managed service |

## Remote Read

Allows Prometheus to query data from external storage backends transparently:

```yaml
remote_read:
  - url: "https://thanos-store.example.com/api/v1/read"
    read_recent: false               # Don't read recent data from remote (use local)
```

Remote read is less commonly used -- most setups use Thanos Query or Grafana to query long-term storage directly.

## WAL and Backups

The WAL ensures no data loss on crash (compression enabled by default in 3.x). For backups, create TSDB snapshots via `curl -XPOST http://localhost:9090/api/v1/admin/tsnapshot` and copy the snapshot directory. Restore by copying blocks to the `data/` directory before starting Prometheus.

## Performance Tuning

| Flag | Default | Purpose |
|------|---------|---------|
| `--storage.tsdb.min-block-duration` | 2h | Minimum block duration before compaction |
| `--storage.tsdb.max-block-duration` | 36h (27% of retention) | Maximum block size |
| `--storage.tsdb.wal-compression` | true (3.x) | Compress WAL segments |
| `--query.max-samples` | 50M | Max samples per query |
| `--query.timeout` | 2m | Query timeout |
| `--query.max-concurrency` | 20 | Max concurrent queries |

## Out-of-Order Ingestion (Prometheus 3.x)

Prometheus 3.x accepts out-of-order samples by default, useful for delayed metrics from batch jobs or intermittent network connectivity:

```yaml
# Enabled by default in 3.x; configurable window
storage:
  tsdb:
    out_of_order_time_window: 30m
```

## Related

- [Architecture](architecture.md) - System topology and component roles
- [Federation & Scaling](../patterns/federation-scaling.md) - Long-term storage backends
- [Recording Rules](../patterns/recording-rules.md) - Reduce query load via pre-computation
