# Gemini Quick Reference

> Fast lookup tables. For code examples, see linked files.
> **MCP Validated**: 2026-02-19

## Model Comparison (February 2026)

| Model | Input/1M | Output/1M | Context | Best For |
|-------|----------|-----------|---------|----------|
| gemini-2.5-flash-lite | $0.10 | $0.40 | 1M | High-volume, low-cost |
| gemini-2.5-flash | $0.15 | $0.60 | 1M | Balanced speed/quality |
| gemini-2.5-flash-image | $0.15 | $0.60 | 1M | Image generation + understanding |
| gemini-2.5-pro | $1.25 | $5.00 | 1M | Complex reasoning (GA) |
| gemini-3-flash-preview | TBD | TBD | 1M | Next-gen speed (preview) |
| gemini-3-pro-preview | $2.00 | $12.00 | 1M | Cutting-edge tasks (preview) |

## Key New Features (Gemini 3 / 2.5 GA)

| Feature | Details |
|---------|---------|
| `thinking_level` | "low" or "high" -- controls reasoning depth (Gemini 3+) |
| `media_resolution` | "low", "medium", "high" -- controls image/video/doc token cost |
| Implicit caching | Automatic, min 1024 tokens (Flash) / 4096 tokens (Pro) |
| Explicit caching | Set TTL for reusable context |
| Computer Use tool | Browser/desktop automation (gemini-3-pro/flash-preview) |
| Gemini Live API | Bidirectional streaming, real-time voice |
| GCS / pre-signed URLs | Direct GCS bucket inputs, 100MB file limit |

## SDK Quick Setup

| Step | Code |
|------|------|
| Install | `pip install google-genai` |
| Init Vertex | `client = genai.Client(vertexai=True, project="ID", location="us-central1")` |
| Init API Key | `client = genai.Client(api_key="KEY")` |

## Decision Matrix

| Use Case | Choose |
|----------|--------|
| Invoice extraction | gemini-2.5-flash + vision |
| Batch processing (1000+ docs) | gemini-2.5-flash-lite |
| Complex multi-step reasoning | gemini-2.5-pro |
| Deep reasoning / agentic tasks | gemini-3-pro-preview + thinking_level="high" |
| Cost-sensitive production | OpenRouter fallback chain |
| Image generation | gemini-2.5-flash-image |

## Deprecation Warnings

| Model / API | Shutdown Date | Replacement |
|-------------|---------------|-------------|
| gemini-2.0-flash | March 31, 2026 | gemini-2.5-flash |
| gemini-2.0-flash-lite | March 31, 2026 | gemini-2.5-flash-lite |
| text-embedding-004 | Shut down | text-embedding-005 |
| vertexai.generative_models | Deprecated June 2025 | google-genai SDK |

## Common Pitfalls

| Mistake | Fix |
|---------|-----|
| Using deprecated vertexai.generative_models | Use google-genai SDK |
| Using gemini-2.0-flash/lite model names | Migrate to gemini-2.5-flash/lite before March 31 |
| Ignoring responseSchema ordering | Match schema order in prompts |
| Not handling 429 rate limits | Implement exponential backoff |
| Skipping safety settings | Configure for document tasks |
| Manual image resizing without media_resolution | Use media_resolution="low" for cost savings |

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `GOOGLE_GENAI_USE_VERTEXAI` | Enable Vertex AI mode |
| `GOOGLE_CLOUD_PROJECT` | GCP project ID |
| `GOOGLE_CLOUD_LOCATION` | Region (us-central1) |
| `GOOGLE_APPLICATION_CREDENTIALS` | Service account JSON path |

## Related Documentation

| Topic | Path |
|-------|------|
| Model Capabilities | `concepts/model-capabilities.md` |
| Token Limits & Caching | `concepts/token-limits-pricing.md` |
| Full Index | `index.md` |
