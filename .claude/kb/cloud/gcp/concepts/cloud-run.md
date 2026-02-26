# Cloud Run

> **Purpose**: Fully managed serverless platform for containerized applications
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Cloud Run is a managed compute platform that runs stateless containers invocable via HTTP requests or events. It abstracts infrastructure, auto-scales from zero to thousands of instances, and charges only for resources used during request processing. As of 2025-2026, Cloud Run supports three resource types: **services** (request-driven), **jobs** (batch), and **worker pools** (continuous background processing, Preview).

## Resource Types

| Type | Purpose | Autoscaling | GPU | Status |
|------|---------|-------------|-----|--------|
| **Services** | HTTP request/event processing | Yes (0 to N) | L4 GA | GA |
| **Jobs** | Batch tasks with finite execution | Fixed task count | L4 GA | GA |
| **Worker Pools** | Continuous background processing | No (fixed size) | Yes | Preview (June 2025) |

## The Pattern

```python
# Cloud Run function triggered by Pub/Sub
import functions_framework
from cloudevents.http import CloudEvent

@functions_framework.cloud_event
def process_invoice(cloud_event: CloudEvent):
    """Triggered by Pub/Sub message."""
    import base64
    import json

    data = base64.b64decode(cloud_event.data["message"]["data"])
    message = json.loads(data)

    bucket = message["bucket"]
    file_name = message["name"]
    result = extract_invoice_data(bucket, file_name)
    return result
```

## Key Configuration

| Setting | Purpose | Invoice Pipeline |
|---------|---------|------------------|
| `--min-instances` | Cold start prevention | 1 for critical functions |
| `--max-instances` | Cost control | 10-100 based on load |
| `--concurrency` | Requests per instance | 1 for CPU-heavy LLM calls |
| `--memory` | Container memory | 1Gi for image processing |
| `--timeout` | Max request duration | 300s for LLM extraction |
| `--gpu` | GPU accelerator type | `nvidia-l4` for inference |
| `--gpu-count` | Number of GPUs | 1 (max per instance) |

## GPU Support (GA June 2025)

| GPU | VRAM | Status | Use Case |
|-----|------|--------|----------|
| NVIDIA L4 | 24 GB | GA | Inference, fine-tuning, media |
| NVIDIA RTX PRO 6000 Blackwell | 96 GB | Preview (Feb 2026) | Large models, high-VRAM workloads |

```bash
# Deploy with GPU
gcloud run deploy ml-inference \
  --image gcr.io/project/ml-model:latest \
  --gpu 1 --gpu-type nvidia-l4 \
  --memory 16Gi --cpu 4 \
  --no-cpu-throttling \
  --service-account ml-sa@project.iam.gserviceaccount.com
```

## Sidecar Containers (GA)

Multiple containers per instance for logging agents, proxies, or data collectors.

```yaml
# service.yaml - sidecar example
spec:
  containers:
    - image: gcr.io/project/app:latest   # main
      ports:
        - containerPort: 8080
    - image: gcr.io/project/otel:latest   # sidecar
```

## Networking (2025-2026)

| Feature | Status | Notes |
|---------|--------|-------|
| Direct VPC egress (2nd gen functions) | Preview (Jan 2026) | Replaces Serverless VPC Connector |
| Direct VPC ingress (worker pools) | GA (Feb 2026) | Private IP on VPC |

## Deployment Options

| Method | Use Case |
|--------|----------|
| Source-based | Python (3.14 GA, uses uv), Node.js 24, Go, Java 25, Dart |
| OS-only runtime | Go/Dart without Dockerfile (GA Feb 2026) |
| Container-based | Custom runtimes, specific dependencies |
| Terraform | Infrastructure as code deployment |

## Scaling Behavior

1. **Scale to zero**: No cost when idle (cold start on first request)
2. **Rapid scale-out**: New instances spawn in seconds
3. **Concurrency**: Multiple requests per instance (set to 1 for LLM)
4. **Min instances**: Keep warm for latency-sensitive workloads
5. **GPU instances**: Always-on CPU required, min 1 instance recommended

## Deprecation Notice

**Cloud Functions 1st gen is deprecated.** Migrate to Cloud Run functions (2nd gen). Cloud Run functions use the same `functions-framework` SDK and Eventarc triggers.

## Common Mistakes

### Wrong
```bash
# Using 1st gen Cloud Functions (deprecated)
gcloud functions deploy my-func --runtime python312 --gen1
```

### Correct
```bash
# Using Cloud Run functions (2nd gen / Cloud Run native)
gcloud run deploy my-func \
  --source . --function my_handler \
  --service-account my-func@project.iam.gserviceaccount.com
```

## Related

- [Event-Driven Pipeline](../patterns/event-driven-pipeline.md)
- [Cloud Run Scaling](../patterns/cloud-run-scaling.md)
- [Pub/Sub](../concepts/pubsub.md)
