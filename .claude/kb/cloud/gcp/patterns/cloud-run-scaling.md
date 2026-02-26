# Cloud Run Scaling Configuration

> **Purpose**: Optimize Cloud Run autoscaling for invoice processing workloads
> **MCP Validated**: 2026-02-19

## When to Use

- LLM calls require low concurrency (1 request per instance)
- GPU workloads need dedicated accelerator instances
- Cold starts affect user experience
- Cost optimization for variable traffic
- Background processing with worker pools
- Need to protect downstream systems from overload

## Implementation

```bash
# Deploy with optimized scaling for LLM workloads
gcloud run deploy invoice-extractor \
  --image gcr.io/my-project/invoice-extractor:latest \
  --region us-central1 \
  --service-account invoice-extractor@my-project.iam.gserviceaccount.com \
  --min-instances 1 \
  --max-instances 50 \
  --concurrency 1 \
  --memory 2Gi \
  --cpu 2 \
  --timeout 300 \
  --set-env-vars "GCP_PROJECT=my-project"
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `min-instances` | 0 | Keep warm instances to avoid cold start |
| `max-instances` | 100 | Limit scaling to protect downstream |
| `concurrency` | 80 | Requests per instance (1 for LLM) |
| `memory` | 512Mi | Container memory allocation |
| `cpu` | 1 | vCPUs allocated |
| `timeout` | 300s | Request timeout |

## Example Usage

```hcl
# Terraform: Cloud Run service with scaling
resource "google_cloud_run_service" "invoice_extractor" {
  name     = "invoice-extractor"
  location = "us-central1"

  template {
    spec {
      containers {
        image = "gcr.io/${var.project_id}/invoice-extractor:latest"

        resources {
          limits = {
            memory = "2Gi"
            cpu    = "2"
          }
        }

        env {
          name  = "GCP_PROJECT"
          value = var.project_id
        }
      }

      container_concurrency = 1  # One request at a time for LLM
      timeout_seconds       = 300
      service_account_name  = google_service_account.extractor.email
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/minScale" = "1"   # Avoid cold starts
        "autoscaling.knative.dev/maxScale" = "50"  # Cost control
        "run.googleapis.com/cpu-throttling" = "false"  # Always-on CPU
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}
```

## Scaling Profiles by Function

| Function | Min | Max | Concurrency | Memory | GPU | Why |
|----------|-----|-----|-------------|--------|-----|-----|
| TIFF Converter | 0 | 100 | 10 | 1Gi | -- | CPU-bound, fast |
| Classifier | 0 | 50 | 5 | 1Gi | -- | Light LLM call |
| Extractor | 1 | 30 | 1 | 2Gi | -- | Heavy LLM, keep warm |
| ML Inference | 1 | 10 | 1 | 16Gi | L4 | GPU-bound, keep warm |
| BQ Writer | 0 | 100 | 50 | 512Mi | -- | I/O bound, fast |

## Cold Start Mitigation

```hcl
# Strategy 1: Minimum instances (cost: ~$10/month per instance)
metadata {
  annotations = {
    "autoscaling.knative.dev/minScale" = "1"
  }
}

# Strategy 2: Cloud Scheduler warmup (cheaper but less responsive)
resource "google_cloud_scheduler_job" "warmup" {
  name     = "warmup-extractor"
  schedule = "*/5 * * * *"  # Every 5 minutes

  http_target {
    http_method = "GET"
    uri         = "${google_cloud_run_service.extractor.status[0].url}/health"
    oidc_token {
      service_account_email = google_service_account.scheduler.email
    }
  }
}
```

## CPU Allocation Strategy

```hcl
# Always-on CPU: Better for consistent performance
metadata {
  annotations = {
    "run.googleapis.com/cpu-throttling" = "false"
  }
}

# Throttled CPU (default): Cheaper, CPU only during request
metadata {
  annotations = {
    "run.googleapis.com/cpu-throttling" = "true"
  }
}
```

## Monitoring Scaling Behavior

```sql
-- BigQuery: Query Cloud Run logs for scaling insights
SELECT timestamp, jsonPayload.message, resource.labels.revision_name
FROM `project.global._Default._AllLogs`
WHERE resource.type = 'cloud_run_revision'
  AND resource.labels.service_name = 'invoice-extractor'
  AND timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
ORDER BY timestamp DESC LIMIT 100;
```

## GPU Scaling (GA June 2025)

```bash
# Deploy with NVIDIA L4 GPU for inference
gcloud run deploy ml-inference \
  --image gcr.io/project/model:latest \
  --gpu 1 --gpu-type nvidia-l4 \
  --cpu 4 --memory 16Gi \
  --no-cpu-throttling \
  --min-instances 1 \
  --max-instances 10 \
  --concurrency 1
```

**GPU scaling constraints:**
- Always-on CPU required (`--no-cpu-throttling`)
- Min instances recommended (GPU cold starts are slow)
- Concurrency 1 for most inference workloads
- L4: 24 GB VRAM (GA), RTX PRO 6000 Blackwell: 96 GB VRAM (Preview Feb 2026)

## Worker Pools (Preview June 2025)

Worker pools are a third Cloud Run resource type for continuous background processing. Unlike services, they do not autoscale and have no HTTP endpoint.

```bash
# Create a worker pool for background processing
gcloud run worker-pools create background-processor \
  --image gcr.io/project/worker:latest \
  --instances 3 \
  --cpu 2 --memory 4Gi \
  --vpc-connector my-connector
```

| Property | Services | Jobs | Worker Pools |
|----------|----------|------|--------------|
| Trigger | HTTP/events | Manual/scheduled | Continuous |
| Autoscaling | Yes | Fixed tasks | No (fixed count) |
| GPU support | L4 GA | L4 GA | Yes (Preview) |
| VPC ingress | Standard | N/A | Direct (Feb 2026) |

## See Also

- [Cloud Run](../concepts/cloud-run.md)
- [Event-Driven Pipeline](../patterns/event-driven-pipeline.md)
- [IAM](../concepts/iam.md)
