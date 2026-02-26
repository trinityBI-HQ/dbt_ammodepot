# CloudWatch Synthetics

> **Purpose**: Proactive endpoint and workflow monitoring using configurable canary scripts
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

CloudWatch Synthetics creates canaries -- configurable scripts that run on a schedule to monitor endpoints, APIs, and workflows. Canaries are Lambda functions written in Node.js, Python, or Java that simulate user behavior and report availability and latency metrics. They detect issues before real users are affected.

## Key Concepts

| Term | Description |
|------|-------------|
| **Canary** | A script that runs on schedule to test an endpoint or workflow |
| **Blueprint** | Pre-built canary template (heartbeat, API, visual, step) |
| **Runtime** | Language runtime: `syn-nodejs-puppeteer-*`, `syn-python-selenium-*` |
| **Artifact** | Screenshots, HAR files, logs stored in S3 per run |
| **Group** | Logical grouping of related canaries |

## Blueprint Types

| Blueprint | Use Case | Runtime |
|-----------|----------|---------|
| **Heartbeat** | Simple URL availability check | Node.js |
| **API Canary** | REST API endpoint testing | Node.js / Python |
| **Broken Link Checker** | Crawl page for broken links | Node.js |
| **Visual Monitoring** | Screenshot comparison for UI regression | Node.js |
| **GUI Workflow** | Multi-step user flow (login, checkout) | Node.js |
| **Canary Recorder** | Record browser interactions to generate scripts | Node.js |

## Creating a Canary

### Heartbeat Canary (CLI)

```bash
aws synthetics create-canary \
  --name api-health-check \
  --artifact-s3-location "s3://my-canary-artifacts/api-health/" \
  --execution-role-arn arn:aws:iam::123456789:role/canary-role \
  --schedule "Expression=rate(5 minutes)" \
  --runtime-version syn-python-selenium-4.0 \
  --code '{"Handler":"canary.handler","ZipFile":"..."}' \
  --run-config TimeoutInSeconds=60
```

### Python API Canary

```python
# canary.py -- deployed as Lambda
import json
import http.client
from aws_synthetics.selenium import synthetics_webdriver as syn_webdriver
from aws_synthetics.common import synthetics_logger as logger

def api_canary():
    url = "https://api.example.com/health"
    conn = http.client.HTTPSConnection("api.example.com")
    conn.request("GET", "/health")
    response = conn.getresponse()

    if response.status != 200:
        raise Exception(f"Health check failed: {response.status}")

    body = json.loads(response.read())
    if body.get("status") != "healthy":
        raise Exception(f"Service unhealthy: {body}")

    logger.info(f"Health check passed: {body}")

def handler(event, context):
    return api_canary()
```

### Multi-Step Canary

```python
from aws_synthetics.selenium import synthetics_webdriver as syn_webdriver
from aws_synthetics.common import synthetics_logger as logger

def login_workflow():
    browser = syn_webdriver.Chrome()

    # Step 1: Navigate to login page
    syn_webdriver.execute_step("navigate_to_login", lambda: (
        browser.get("https://app.example.com/login")
    ))

    # Step 2: Submit credentials
    syn_webdriver.execute_step("submit_login", lambda: (
        browser.find_element_by_id("username").send_keys("test@example.com"),
        browser.find_element_by_id("password").send_keys("testpass"),
        browser.find_element_by_id("submit").click()
    ))

    # Step 3: Verify dashboard loads
    syn_webdriver.execute_step("verify_dashboard", lambda: (
        browser.find_element_by_id("dashboard-title")
    ))

def handler(event, context):
    return login_workflow()
```

## Published Metrics

| Metric | Description |
|--------|-------------|
| `SuccessPercent` | Percentage of successful runs |
| `Duration` | Canary execution time (ms) |
| `Failed` | Number of failed runs |
| `2xx`, `4xx`, `5xx` | HTTP status code counts |

Dimensions: `CanaryName` and optionally `StepName` for multi-step canaries.

## Artifacts and Layers

Each run stores **screenshots**, **HAR files**, and **logs** in S3. Canaries support custom Lambda layers for dependencies, shared libraries, or custom SSL certificates.

## Pricing

| Component | Cost |
|-----------|------|
| Per canary run | $0.0012 |
| Example: 5-min interval, 1 month | ~$10.37/canary |

## AI-Powered Synthetics Debugging (Nov 2025)

Natural language canary failure diagnosis powered by an MCP server integration.

| Feature | Description |
|---------|-------------|
| **MCP Server** | Exposes canary data to AI assistants for natural language debugging |
| **GitHub Action** | `@awsapm` in GitHub Issues triggers automated diagnosis |
| **Root Cause Analysis** | AI pinpoints the specific file, function, and line causing failures |
| **Failure Correlation** | Correlates canary failures with recent deployments and changes |

**Workflow**: Canary fails -> GitHub Issue created -> `@awsapm` mentioned -> MCP server queries canary logs, screenshots, HAR files -> AI returns diagnosis with file/function/line reference.

## Common Mistakes

Use 5-15 minute intervals (not every minute) for most endpoints. Set S3 lifecycle policies on artifact buckets. Use canary groups to organize by service or team.

## Related

- [Metrics](metrics.md) - Canary metrics in CloudWatch
- [Alarms](alarms.md) - Alert on canary failures
- [Events/EventBridge](events-eventbridge.md) - Canary state change events
