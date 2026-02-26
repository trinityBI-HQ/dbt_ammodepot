# Prometheus Architecture

> **Purpose**: Pull-based monitoring model, server components, exporters, and deployment topology
> **MCP Validated**: 2026-02-20

## Overview

Prometheus uses a **pull-based** model: the server actively scrapes metrics from instrumented HTTP endpoints (`/metrics`) at configured intervals. This contrasts with push-based systems and provides advantages for reliability, service discovery, and debugging.

## Core Components

```
                    ┌─────────────────┐
                    │  Prometheus      │
                    │  Server          │
┌──────────┐       │  ┌────────────┐  │       ┌──────────────┐
│ Targets  │──scrape──>│ Retrieval  │  │       │ Alertmanager │
│ /metrics │       │  │ Engine     │  │──────> │ (routing,    │
└──────────┘       │  └─────┬──────┘  │ alerts │  silencing)  │
                    │       │          │       └──────────────┘
┌──────────┐       │  ┌────────────┐  │
│ Service  │──────>│  │ TSDB       │  │       ┌──────────────┐
│ Discovery│       │  │ (storage)  │  │       │ Grafana /    │
└──────────┘       │  └─────┬──────┘  │       │ API clients  │
                    │       │          │──────>│ (query)      │
                    │  ┌────────────┐  │ PromQL└──────────────┘
                    │  │ Rule Engine│  │
                    │  │ (alert +   │  │       ┌──────────────┐
                    │  │  recording)│  │       │ Remote       │
                    │  └────────────┘  │──────>│ Storage      │
                    └─────────────────┘ write  └──────────────┘
```

## Server Components

| Component | Role |
|-----------|------|
| **Retrieval** | Scrapes targets at configured intervals, handles service discovery |
| **TSDB** | Stores time series data locally with efficient compression |
| **HTTP Server** | Serves PromQL queries, federation, and web UI on port 9090 |
| **Rule Engine** | Evaluates recording rules and alert rules at regular intervals |
| **Notifier** | Sends firing/resolved alerts to Alertmanager instances |

## Pull vs Push Model

| Aspect | Pull (Prometheus) | Push (e.g., StatsD) |
|--------|-------------------|---------------------|
| Target health | Built-in (`up` metric) | Must infer from absence |
| Debugging | Curl target directly | Inspect collector logs |
| Short-lived jobs | Use Pushgateway | Native fit |
| Firewall-friendly | Needs target access | Needs collector access |
| Scaling | Federation, remote write | Load balancer |

## Exporters

Exporters bridge systems that do not natively expose Prometheus metrics:

| Exporter | Target System | Key Metrics |
|----------|---------------|-------------|
| **node_exporter** | Linux/Unix hosts | CPU, memory, disk, network, filesystem |
| **blackbox_exporter** | Endpoints (HTTP/TCP/DNS/ICMP) | Probe success, latency, SSL expiry |
| **mysqld_exporter** | MySQL | Queries, connections, replication lag |
| **postgres_exporter** | PostgreSQL | Transactions, locks, replication |
| **redis_exporter** | Redis | Memory, commands, keyspace |
| **snmp_exporter** | Network devices | Interface traffic, device status |
| **cadvisor** | Containers | CPU, memory, I/O per container |
| **kube-state-metrics** | Kubernetes API | Pod, deployment, node object states |

## Client Libraries

Instrument your application code directly:

| Language | Library | Example |
|----------|---------|---------|
| Go | `prometheus/client_golang` | `promauto.NewCounter(...)` |
| Python | `prometheus_client` | `Counter('requests', 'Total requests')` |
| Java | `micrometer` / `simpleclient` | `Counter.builder("requests").register()` |
| Node.js | `prom-client` | `new client.Counter({name: 'requests'})` |

## Deployment Topology

**Single instance**: One Prometheus server for small-to-medium environments (up to ~10M active series).

**High availability**: Two identical Prometheus servers scraping the same targets (dedup at query layer via Thanos/Mimir).

**Federation**: Hierarchical setup where a global Prometheus scrapes aggregated metrics from regional Prometheus instances.

**Remote write**: Forward samples to long-term storage backends (Thanos, Mimir, VictoriaMetrics, Cortex).

## Pushgateway

For short-lived jobs (batch processing, cron jobs) that cannot be scraped:

```bash
echo 'batch_job_duration_seconds 42.5' | curl --data-binary @- http://pushgateway:9091/metrics/job/etl_pipeline
```

Use sparingly -- the Pushgateway is not a general-purpose push receiver. It holds last-pushed values indefinitely unless explicitly deleted.

## OpenTelemetry Integration (Prometheus 3.x)

Prometheus 3.x supports OTLP ingestion natively:

```yaml
otlp:
  promote_resource_attributes:
    - service.instance.id
    - service.name
```

OTLP metrics are received on `/api/v1/otlp/v1/metrics`, enabling Prometheus as a direct backend for OpenTelemetry collectors without requiring a separate adapter.

## Related

- [Data Model](data-model.md) - Metric types and label semantics
- [Service Discovery](service-discovery.md) - Target discovery mechanisms
- [Storage](storage.md) - TSDB internals and remote storage
