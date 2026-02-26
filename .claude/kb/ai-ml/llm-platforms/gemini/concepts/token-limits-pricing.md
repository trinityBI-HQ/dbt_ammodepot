# Token Limits and Pricing

> **Purpose**: Understand context windows, caching, and cost management
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Gemini models offer 1M token context windows with competitive pricing. Implicit and explicit caching provide automatic cost savings. Understanding token consumption and caching thresholds helps optimize costs for high-volume document processing.

## Pricing Table (February 2026)

| Model | Input/1M | Output/1M | Cached Input/1M | Context |
|-------|----------|-----------|-----------------|---------|
| gemini-2.5-flash-lite | $0.10 | $0.40 | -- | 1M |
| gemini-2.5-flash | $0.15 | $0.60 | $0.0375 | 1M |
| gemini-2.5-flash-image | $0.15 | $0.60 | $0.0375 | 1M |
| gemini-2.5-pro | $1.25 | $5.00 | $0.3125 | 1M |
| gemini-3-pro-preview | $2.00 | $12.00 | $0.50 | 1M |

## Token Limits

| Model | Max Input | Max Output |
|-------|-----------|------------|
| All 2.5+ and 3.x models | 1,000,000 | 64,000 |

## Implicit Caching (Automatic)

Gemini automatically caches repeated input prefixes at no extra configuration. Cached tokens are billed at 75% discount.

| Model Family | Min Tokens to Trigger | Discount |
|--------------|----------------------|----------|
| Flash models | 1,024 tokens | 75% off input price |
| Pro models | 4,096 tokens | 75% off input price |

Implicit caching activates automatically when the same prefix appears across requests. No code changes needed -- just send requests with shared prefixes (e.g., system instructions, few-shot examples).

## Explicit Caching (TTL-Based)

For predictable caching, set a TTL on reusable context.

```python
from google import genai
from google.genai import types

client = genai.Client(api_key="KEY")

# Create a cached content object
cached = client.caches.create(
    model="gemini-2.5-flash",
    config=types.CreateCachedContentConfig(
        display_name="invoice-system-prompt",
        contents=[types.Content(parts=[
            types.Part(text="You are an invoice extraction system. Extract...")
        ])],
        ttl="3600s",  # 1 hour
    )
)

# Use cached content in requests
response = client.models.generate_content(
    model="gemini-2.5-flash",
    contents=[image_content],
    config=types.GenerateContentConfig(
        cached_content=cached.name,
    )
)
```

## Token Consumption by Content Type

```python
# Approximate token counts
token_estimates = {
    "text_1k_chars": 250,        # ~250 tokens per 1K characters
    "image_standard": 258,       # Base image cost
    "image_high_res": 1290,      # 1024x1024 image
    "pdf_per_page": 258,         # Per page estimate
    "video_per_second": 258,     # At 1 fps
}
# Use media_resolution="low" to reduce image/video tokens
```

## Cost Calculator Example

```python
def estimate_cost(num_invoices: int, avg_pages: int = 2, cached: bool = False) -> dict:
    """Estimate cost for invoice processing batch."""
    INPUT_COST_PER_M = 0.15  # gemini-2.5-flash
    OUTPUT_COST_PER_M = 0.60
    CACHE_DISCOUNT = 0.25 if cached else 1.0  # 75% off if cached

    tokens_per_page = 258
    prompt_tokens = 500
    output_tokens = 1000

    total_input = num_invoices * (avg_pages * tokens_per_page + prompt_tokens)
    total_output = num_invoices * output_tokens

    input_cost = (total_input / 1_000_000) * INPUT_COST_PER_M * CACHE_DISCOUNT
    output_cost = (total_output / 1_000_000) * OUTPUT_COST_PER_M

    return {
        "invoices": num_invoices,
        "total_cost": f"${input_cost + output_cost:.4f}",
        "savings_from_cache": f"{(1 - CACHE_DISCOUNT) * 100:.0f}% on input"
    }
```

## Quick Reference

| Batch Size | Est. Cost (2.5-flash) | With Caching |
|------------|----------------------|--------------|
| 100 invoices | $0.08 | $0.06 |
| 1,000 invoices | $0.75 | $0.64 |
| 10,000 invoices | $7.50 | $6.38 |

## Common Mistakes

### Wrong

```python
# Sending full-resolution images without media_resolution
# 4K image = ~5000+ tokens = unnecessary cost
```

### Correct

```python
# Use media_resolution to control token cost
config = types.GenerateContentConfig(
    media_resolution="low",  # Reduces tokens automatically
)
# Or resize images before sending
from PIL import Image
img = Image.open("invoice.png")
img.thumbnail((1024, 1024))  # Reduces to ~1290 tokens max
```

## Related

- [model-capabilities.md](model-capabilities.md)
- [../patterns/batch-processing.md](../patterns/batch-processing.md)
