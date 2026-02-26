# Gemini Knowledge Base

> **Purpose**: Google's multimodal LLM family -- Gemini 3 (preview) and 2.5 GA models
> **MCP Validated**: 2026-02-19

## Quick Navigation

### Concepts (< 150 lines each)

| File | Purpose |
|------|---------|
| [concepts/model-capabilities.md](concepts/model-capabilities.md) | Gemini 3/2.5 models, thinking_level, media_resolution, Computer Use |
| [concepts/vertex-ai-integration.md](concepts/vertex-ai-integration.md) | google-genai SDK and authentication |
| [concepts/multimodal-prompting.md](concepts/multimodal-prompting.md) | Text + image + GCS input patterns |
| [concepts/token-limits-pricing.md](concepts/token-limits-pricing.md) | Context windows, caching, and cost management |
| [concepts/structured-output.md](concepts/structured-output.md) | JSON schema and responseSchema |
| [concepts/safety-settings.md](concepts/safety-settings.md) | Harm categories and thresholds |

### Patterns (< 200 lines each)

| File | Purpose |
|------|---------|
| [patterns/invoice-extraction.md](patterns/invoice-extraction.md) | Extract structured data from invoices |
| [patterns/structured-json-output.md](patterns/structured-json-output.md) | Enforce JSON schema responses |
| [patterns/openrouter-fallback.md](patterns/openrouter-fallback.md) | Multi-provider resilience |
| [patterns/batch-processing.md](patterns/batch-processing.md) | High-volume document processing |
| [patterns/error-handling-retries.md](patterns/error-handling-retries.md) | Robust API error handling |
| [patterns/prompt-versioning.md](patterns/prompt-versioning.md) | Version control for prompts |

---

## Quick Reference

- [quick-reference.md](quick-reference.md) - Fast lookup tables

---

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Model Lineup** | Gemini 3 (preview), 2.5 Pro/Flash/Flash-Lite (GA), 2.5 Flash Image |
| **Thinking Control** | `thinking_level` param ("low", "high") for Gemini 3+; replaces raw token budget |
| **Implicit Caching** | Automatic cost savings on repeated prefixes (min 1024 tokens Flash, 4096 Pro) |
| **Explicit Caching** | TTL-based caching for reusable context |
| **Computer Use** | Browser/desktop automation tool for gemini-3-pro/flash-preview (Jan 2026) |
| **Multimodal Input** | Process text, images, PDFs, video, audio in single request |
| **Structured Output** | responseSchema guarantees JSON adherence |
| **Live API** | Bidirectional streaming for real-time voice interactions |
| **media_resolution** | Control image/video/document token cost (low/medium/high) |

---

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/model-capabilities.md, concepts/vertex-ai-integration.md |
| **Intermediate** | patterns/invoice-extraction.md, patterns/structured-json-output.md |
| **Advanced** | patterns/batch-processing.md, patterns/error-handling-retries.md |

---

## Agent Usage

| Agent | Primary Files | Use Case |
|-------|---------------|----------|
| python-developer | patterns/invoice-extraction.md | Implement extraction logic |
| test-generator | patterns/error-handling-retries.md | Test error scenarios |

---

## Important Notes

- **Gemini 3 Preview**: `gemini-3-pro-preview` and `gemini-3-flash-preview` available; `gemini-pro-latest` now points to `gemini-3-pro-preview`.
- **Gemini 2.5 GA**: `gemini-2.5-pro`, `gemini-2.5-flash`, `gemini-2.5-flash-lite`, `gemini-2.5-flash-image` are all GA.
- **Deprecations**: `gemini-2.0-flash` and `gemini-2.0-flash-lite` shut down March 31, 2026. `text-embedding-004` also shut down.
- **SDK**: Use `google-genai` SDK. The old `vertexai.generative_models` was deprecated June 2025 and should no longer be used.
- **Invoice Accuracy**: Gemini achieves 94% accuracy on scanned invoices.
