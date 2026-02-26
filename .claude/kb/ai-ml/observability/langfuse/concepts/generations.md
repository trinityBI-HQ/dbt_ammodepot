# Generations

> **Purpose**: Specialized observation type for tracking LLM calls with token usage and costs
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

A generation is a specialized observation type designed for LLM calls. It extends the basic span with additional fields for model name, parameters, token counts (input/output/cached), and cost calculations. Langfuse v3 automatically tracks tokens and costs for supported models, with data stored in ClickHouse for fast analytics queries.

## The Pattern

```python
from langfuse import get_client

langfuse = get_client()

with langfuse.start_as_current_observation(
    as_type="generation",
    name="invoice-extraction",
    model="gemini-1.5-pro",
    model_parameters={
        "temperature": 0.1,
        "max_tokens": 1024
    },
    input=[
        {"role": "system", "content": "Extract invoice fields..."},
        {"role": "user", "content": "Invoice image attached"}
    ]
) as generation:

    # Call your LLM
    response = call_gemini_api(prompt)

    # Update with output and usage
    generation.update(
        output=response.text,
        usage_details={
            "input": response.usage.prompt_tokens,
            "output": response.usage.completion_tokens,
            "total": response.usage.total_tokens
        }
    )
```

## Quick Reference

| Field | Type | Description |
|-------|------|-------------|
| `model` | string | Model identifier (e.g., "gemini-1.5-pro") |
| `model_parameters` | dict | Temperature, max_tokens, reasoning_effort, service_tier |
| `input` | list/string | Prompt or message array |
| `output` | string/dict | Model response |
| `usage_details` | dict | Token counts by type |
| `cost_details` | dict | Calculated costs |

## Token Usage Types

| Type | Description |
|------|-------------|
| `input` | Prompt/input tokens |
| `output` | Completion/output tokens |
| `total` | Sum of all tokens |
| `cache_read_input_tokens` | Cached prompt tokens |
| `audio_tokens` | Audio input tokens |
| `image_tokens` | Image input tokens |
| `reasoning_tokens` | Reasoning/thinking tokens (o1, o3 models) |

## Common Mistakes

### Wrong

```python
# Missing model name - no auto cost calculation
with langfuse.start_as_current_observation(
    as_type="generation",
    name="llm-call"
) as gen:
    gen.update(output="response")
```

### Correct

```python
# Include model for automatic cost tracking
with langfuse.start_as_current_observation(
    as_type="generation",
    name="llm-call",
    model="gemini-1.5-pro"  # Required for auto-cost
) as gen:
    gen.update(
        output="response",
        usage_details={"input": 100, "output": 50}
    )
```

## Auto-Supported Models

| Provider | Models | Tokenizer |
|----------|--------|-----------|
| OpenAI | gpt-4o, o1, o3-mini | o200k_base |
| Anthropic | claude-3.5-sonnet, claude-3-opus | Anthropic tokenizer |
| Google | gemini-2.0-flash, gemini-1.5-pro | Google tokenizer |

## v3 Playground Parameters

Langfuse v3 playground supports `reasoning_effort` and `service_tier` parameters for compatible models, enabling experimentation with reasoning-heavy workloads directly from the UI.

## Related

- [Cost Tracking](../concepts/cost-tracking.md)
- [Traces and Spans](../concepts/traces-spans.md)
- [Python SDK Integration](../patterns/python-sdk-integration.md)
