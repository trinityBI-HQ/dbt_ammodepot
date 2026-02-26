# Tools

> **Purpose**: Capabilities for agents to interact with external systems
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Tools extend agent capabilities by providing functions to read files, call APIs, query databases, or interact with services like Slack. CrewAI v1.9.x supports two approaches: the `@tool` decorator for simple functions and `BaseTool` subclassing for complex implementations. The tool calling mechanism was overhauled in v1.9.0 for improved reliability and provider compatibility via LiteLLM.

## The Pattern

```python
from crewai.tools import tool, BaseTool
from pydantic import BaseModel, Field
from typing import Type

# Simple approach: @tool decorator
@tool("Read GCS Log File")
def read_gcs_logs(bucket: str, file_path: str) -> str:
    """Read log file from GCS bucket. Use for analyzing Cloud Logging exports."""
    from google.cloud import storage
    client = storage.Client()
    bucket_obj = client.bucket(bucket)
    blob = bucket_obj.blob(file_path)
    return blob.download_as_text()

# Advanced approach: BaseTool subclass
class SlackNotifyInput(BaseModel):
    channel: str = Field(description="Slack channel ID or name")
    message: str = Field(description="Alert message to send")
    severity: str = Field(description="CRITICAL, ERROR, WARNING")

class SlackNotifyTool(BaseTool):
    name: str = "Send Slack Alert"
    description: str = "Send alert notification to Slack channel"
    args_schema: Type[BaseModel] = SlackNotifyInput

    def _run(self, channel: str, message: str, severity: str) -> str:
        import requests
        webhook_url = os.environ["SLACK_WEBHOOK_URL"]
        emoji = {"CRITICAL": ":red_circle:", "ERROR": ":warning:"}
        payload = {
            "channel": channel,
            "text": f"{emoji.get(severity, ':info:')} {message}"
        }
        requests.post(webhook_url, json=payload)
        return f"Alert sent to {channel}"
```

## Quick Reference

| Approach | When to Use | Complexity |
|----------|-------------|------------|
| `@tool` decorator | Simple stateless functions | Low |
| `BaseTool` subclass | State, validation, async | High |

## Tool Parameters

| Parameter | Description |
|-----------|-------------|
| `name` | Tool name agents see |
| `description` | When/how to use (agents read this) |
| `args_schema` | Pydantic model for validation |
| `cache_function` | Custom caching logic |

## Tool Calling in v1.9.0

The v1.9.0 release overhauled tool calling mechanisms for improved reliability:
- Tools are dispatched via LiteLLM, ensuring consistent behavior across providers
- Better error handling when tools fail or return unexpected formats
- Improved retry logic for transient tool failures
- Function calling works consistently with OpenAI, Gemini, Anthropic, and open-source models

## Common Mistakes

### Wrong

```python
# Poor description - agent won't know when to use
@tool("log tool")
def read_logs(path):
    """Reads logs."""
    return open(path).read()
```

### Correct

```python
# Clear description helps agent decide when to use
@tool("Read Pipeline Logs")
def read_pipeline_logs(log_path: str) -> str:
    """Read Cloud Run or Pub/Sub logs from local path.
    Use when analyzing pipeline failures or errors.
    Input: Full path to log file (e.g., /tmp/logs/run_123.log)
    Returns: Raw log content as string."""
    with open(log_path) as f:
        return f.read()
```

## Built-in Tools

CrewAI provides 100+ tools. Install with: `pip install 'crewai[tools]'`

| Category | Examples |
|----------|----------|
| Web | SerperDevTool, ScrapeWebsiteTool |
| Files | FileReadTool, DirectoryReadTool |
| Code | CodeInterpreterTool |
| RAG | RagTool (vector search) |

## Related

- [Agents](../concepts/agents.md)
- [Log Analysis Pattern](../patterns/log-analysis-agent.md)
- [Slack Integration](../patterns/slack-integration.md)
