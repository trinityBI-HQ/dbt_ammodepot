# GCP Serverless Quick Reference

> Fast lookup tables. For code examples, see linked files.
> **MCP Validated**: 2026-02-19

## Service Selection

| Use Case | Choose | Why |
|----------|--------|-----|
| Run containers on events | Cloud Run service | Serverless, scales to zero |
| GPU inference (L4/Blackwell) | Cloud Run + GPU | NVIDIA L4 GA, RTX PRO 6000 Preview |
| Background processing | Cloud Run worker pool | Continuous, no autoscaling (Preview) |
| Async message passing | Pub/Sub | Decouples producers/consumers |
| Store files with triggers | GCS + Eventarc | Object events to Cloud Run |
| Analytics warehouse + AI | BigQuery | SQL + AI.GENERATE, AI.CLASSIFY |
| Store API keys | Secret Manager | Versioned, encrypted |

## Cloud Run Limits

| Setting | Default | Max |
|---------|---------|-----|
| Request timeout | 5 min | 60 min |
| Max instances | 100 | 1000+ (quota) |
| Min instances | 0 | configurable |
| Concurrency | 80 | 1000 |
| Memory | 512 MB | 32 GB |
| vCPUs | 1 | 8 |
| GPU | none | 1x L4 (24 GB) or 1x RTX PRO 6000 (96 GB) |

## Cloud Run Resource Types (2025+)

| Type | Purpose | Autoscaling | GPU Support |
|------|---------|-------------|-------------|
| **Services** | Request-driven | Yes (0 to N) | Yes (L4 GA) |
| **Jobs** | Batch tasks | Fixed task count | Yes (L4 GA) |
| **Worker Pools** | Background processing | No (fixed) | Yes (Preview) |

## Pub/Sub Defaults

| Setting | Value | Notes |
|---------|-------|-------|
| Message retention | 7 days | Configurable up to 31 days |
| Ack deadline | 10 sec | Max 600 sec |
| Max message size | 10 MB | Per message |
| Delivery | At-least-once | Exactly-once available (GA April 2025) |
| SMTs | Preview | Inline message transforms in subscriptions |

## BigQuery Features (2025-2026)

| Feature | Status | Notes |
|---------|--------|-------|
| AI.GENERATE / AI.GENERATE_TABLE | GA (Feb 2026) | LLM calls from SQL |
| AI.CLASSIFY, AI.SCORE | GA | Managed AI functions |
| Continuous queries | GA (2025) | Real-time SQL to Pub/Sub/Bigtable |
| Vector search | Production-ready | Native VECTOR_SEARCH |
| Global queries | Preview (Feb 2026) | Query across regions |
| Dataset insights | Preview (Feb 2026) | Auto relationship graphs |

## GCS Features (2025-2026)

| Feature | Status | Notes |
|---------|--------|-------|
| Soft delete | Default on new buckets | Recoverable deletes |
| Anywhere Cache | GA | SSD zonal read cache |
| Autoclass | Mature | Auto storage class transitions |
| Object change notifications | Deprecated Jan 2026 | Use Pub/Sub notifications |

## IAM Roles (Least Privilege)

| Task | Role |
|------|------|
| Invoke Cloud Run | `roles/run.invoker` |
| Publish to Pub/Sub | `roles/pubsub.publisher` |
| Subscribe to Pub/Sub | `roles/pubsub.subscriber` |
| Read GCS | `roles/storage.objectViewer` |
| Write GCS | `roles/storage.objectCreator` |
| Insert to BigQuery | `roles/bigquery.dataEditor` |
| Access secrets | `roles/secretmanager.secretAccessor` |

## Common Pitfalls

| Avoid | Do Instead |
|-------|------------|
| Using default service account | Create dedicated service accounts |
| `SELECT *` on BigQuery | Select specific columns |
| Hardcoding secrets | Use Secret Manager |
| Single bucket for all stages | Bucket-per-stage pattern |
| No dead-letter queue | Configure DLQ on subscriptions |
| Cloud Functions 1st gen | Use Cloud Run functions (deprecated) |
| GCS object change notifications | Use Pub/Sub notifications (deprecated Jan 2026) |

## Related Documentation

| Topic | Path |
|-------|------|
| Cloud Run concepts | `concepts/cloud-run.md` |
| Event-driven pattern | `patterns/event-driven-pipeline.md` |
| Full Index | `index.md` |
