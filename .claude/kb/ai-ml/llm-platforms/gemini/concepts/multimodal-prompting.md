# Multimodal Prompting

> **Purpose**: Combine text and images in Gemini requests
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Gemini's native multimodal capabilities allow processing text and images simultaneously. For document extraction, this eliminates the need for separate OCR preprocessing. Each image consumes 258-1290 tokens depending on resolution.

## Basic Image + Text Request

```python
from google import genai
from google.genai import types
import base64

client = genai.Client(vertexai=True, project="my-project", location="us-central1")

# Load image
with open("invoice.png", "rb") as f:
    image_data = base64.b64encode(f.read()).decode("utf-8")

response = client.models.generate_content(
    model="gemini-2.5-flash",
    contents=[
        types.Content(
            parts=[
                types.Part(text="Extract all line items from this invoice as JSON."),
                types.Part(
                    inline_data=types.Blob(
                        mime_type="image/png",
                        data=image_data
                    )
                )
            ]
        )
    ]
)
print(response.text)
```

## Image from GCS / Pre-signed URL

Direct GCS bucket inputs and pre-signed URLs are supported (100MB file limit).

```python
# GCS URI input
response = client.models.generate_content(
    model="gemini-2.5-flash",
    contents=[
        types.Content(
            parts=[
                types.Part(text="Extract the invoice total."),
                types.Part(
                    file_data=types.FileData(
                        mime_type="image/tiff",
                        file_uri="gs://bucket/invoices/invoice-001.tiff"
                    )
                )
            ]
        )
    ],
    config=types.GenerateContentConfig(
        media_resolution="medium",  # Control token cost
    )
)
```

## media_resolution Parameter

Controls token consumption for image, video, and document inputs without manual resizing.

| Resolution | Effect | Best For |
|------------|--------|----------|
| `"low"` | Fewest tokens per image | Batch cost optimization |
| `"medium"` | Balanced (default) | General extraction |
| `"high"` | Maximum detail | Fine text, small print |

## Quick Reference

| Input Type | Tokens | Notes |
|------------|--------|-------|
| Image (any size) | 258-1290 | Varies by resolution and media_resolution setting |
| PDF page | ~258 per page | Native understanding |
| Video (per second) | 258 | 1 fps sample rate |
| GCS file limit | -- | 100MB per file |

## Best Practices for Documents

| Practice | Reason |
|----------|--------|
| Use PNG over JPEG | Better text clarity |
| Resize to 1024px max | Reduces token cost |
| Put text prompt first | Better instruction following |
| Be specific about output | "Extract as JSON with fields..." |

## Common Mistakes

### Wrong

```python
# Image after text without structure
contents = "Extract data" + image  # Won't work
```

### Correct

```python
# Properly structured multimodal content
contents = [
    types.Content(
        parts=[
            types.Part(text="Extract data as JSON."),
            types.Part(inline_data=types.Blob(mime_type="image/png", data=img))
        ]
    )
]
```

## Related

- [structured-output.md](structured-output.md)
- [../patterns/invoice-extraction.md](../patterns/invoice-extraction.md)
