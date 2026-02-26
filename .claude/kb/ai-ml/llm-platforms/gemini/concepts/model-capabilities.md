# Model Capabilities

> **Purpose**: Understand Gemini model variants and their capabilities
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Gemini is Google's multimodal LLM family capable of processing text, images, PDFs, video, and audio. The lineup spans Gemini 3 (preview) for cutting-edge tasks down to 2.5 Flash Lite for high-volume batch processing. Flash variants offer the best cost-performance ratio for document extraction with native vision.

## Model Hierarchy (February 2026)

```text
gemini-3-pro-preview       <- Cutting-edge reasoning (preview)
gemini-3-flash-preview     <- Next-gen speed (preview)
gemini-2.5-pro             <- Complex reasoning (GA)
gemini-2.5-flash           <- Balanced speed/quality (GA, recommended)
gemini-2.5-flash-image     <- Image generation + understanding (GA)
gemini-2.5-flash-lite      <- Highest throughput, lowest cost (GA)
```

**Note**: `gemini-pro-latest` now points to `gemini-3-pro-preview`.

## Quick Reference

| Model | Context | Output Max | Status | Use Case |
|-------|---------|------------|--------|----------|
| `gemini-3-pro-preview` | 1M | 64K | Preview | Agentic tasks, Computer Use |
| `gemini-3-flash-preview` | 1M | 64K | Preview | Fast next-gen inference |
| `gemini-2.5-pro` | 1M | 64K | GA | Complex document analysis |
| `gemini-2.5-flash` | 1M | 64K | GA | Invoice extraction (primary) |
| `gemini-2.5-flash-image` | 1M | 64K | GA | Image gen + multimodal |
| `gemini-2.5-flash-lite` | 1M | 64K | GA | High-volume batch processing |

## Thinking Control (Gemini 3+)

The `thinking_level` parameter replaces raw token budget for controlling reasoning depth.

```python
from google import genai
from google.genai import types

client = genai.Client(api_key="KEY")

response = client.models.generate_content(
    model="gemini-3-pro-preview",
    contents=["Analyze this complex contract for risks."],
    config=types.GenerateContentConfig(
        thinking_level="high",  # "low" or "high"
    )
)
```

| Level | Behavior | Use Case |
|-------|----------|----------|
| `"low"` | Minimal reasoning overhead | Simple extraction, classification |
| `"high"` | Deep multi-step reasoning | Complex analysis, agentic tasks |

## media_resolution Parameter

Controls token cost for image, video, and document inputs.

```python
response = client.models.generate_content(
    model="gemini-2.5-flash",
    contents=[image_content],
    config=types.GenerateContentConfig(
        media_resolution="low",  # "low", "medium", "high"
    )
)
```

| Resolution | Token Impact | Best For |
|------------|-------------|----------|
| `"low"` | Fewest tokens | Batch processing, cost optimization |
| `"medium"` | Balanced | General document extraction |
| `"high"` | Most tokens | Fine detail, small text recognition |

## Computer Use Tool (Gemini 3 Preview)

Available on `gemini-3-pro-preview` and `gemini-3-flash-preview` since January 2026. Enables browser and desktop automation.

```python
response = client.models.generate_content(
    model="gemini-3-pro-preview",
    contents=["Navigate to the invoice portal and download last month's invoices."],
    config=types.GenerateContentConfig(
        tools=[types.Tool(computer_use=types.ToolComputerUse(
            environment=types.Environment(
                display=types.Display(width=1920, height=1080)
            )
        ))]
    )
)
```

## Deprecation Schedule

| Model | Status | Shutdown |
|-------|--------|----------|
| gemini-2.0-flash | Deprecated | March 31, 2026 |
| gemini-2.0-flash-lite | Deprecated | March 31, 2026 |
| gemini-1.5-flash/pro | Retired | Already shut down |
| text-embedding-004 | Retired | Already shut down |

## Performance Benchmarks

| Task | Gemini 2.5 Flash | GPT-4V | Claude 3 |
|------|-------------------|--------|----------|
| Scanned invoice accuracy | 94% | 91% | 90% |
| Processing speed | Fast | Medium | Medium |
| Cost per 1K docs | $0.15 | $0.30 | $0.25 |

## Related

- [vertex-ai-integration.md](vertex-ai-integration.md)
- [multimodal-prompting.md](multimodal-prompting.md)
- [token-limits-pricing.md](token-limits-pricing.md)
