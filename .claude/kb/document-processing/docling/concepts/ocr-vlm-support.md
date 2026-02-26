# OCR and VLM Support

> **Purpose**: Optical Character Recognition and Visual Language Models for processing scanned documents and complex layouts
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Docling supports OCR for scanned documents, VLMs (GraniteDocling) for complex layouts, and the Heron layout model (default since v2.50+) for 20%+ improved layout detection. v2.73+ introduced pluggable VLM presets and chart extraction (v2.72+) via Granite Vision.

## The Pattern

```python
from docling.document_converter import DocumentConverter, PdfPipelineOptions
from docling.datamodel.base_models import PipelineType

# OCR for scanned PDFs
ocr_options = PdfPipelineOptions()
ocr_options.do_ocr = True
ocr_converter = DocumentConverter(pipeline_options=ocr_options)

# VLM for complex layouts
vlm_options = PdfPipelineOptions()
vlm_options.pipeline_type = PipelineType.VLM
vlm_options.vlm_model = "granite_docling"
vlm_converter = DocumentConverter(pipeline_options=vlm_options)

# Process scanned document
scanned_result = ocr_converter.convert("scanned.pdf")

# Process complex layout
complex_result = vlm_converter.convert("complex_tables.pdf")
```

## OCR Configuration

```python
from docling.document_converter import DocumentConverter, PdfPipelineOptions

# Enable OCR
options = PdfPipelineOptions()
options.do_ocr = True

# OCR engine selection (default: EasyOCR)
options.ocr_engine = "easyocr"

# Language support
options.ocr_lang = ["en", "es", "fr"]  # Multi-language

converter = DocumentConverter(pipeline_options=options)
```

## VLM Configuration

```python
from docling.document_converter import DocumentConverter, PdfPipelineOptions
from docling.datamodel.base_models import PipelineType

# Configure VLM pipeline
options = PdfPipelineOptions()
options.pipeline_type = PipelineType.VLM

# Model selection
options.vlm_model = "granite_docling"  # IBM Granite model

# VLM is best for:
# - Complex multi-column layouts
# - Scientific papers with formulas
# - Documents with mixed content types
# - Tables with merged cells

converter = DocumentConverter(pipeline_options=options)
```

## Heron Layout Model (Default)

The Heron model (RT-DETRv2 architecture, trained on 150K docs) is the default PDF layout model. Heron-101 processes pages in ~28ms on A100. Published as arXiv:2509.11720.

## Chart Extraction (v2.72+)

```python
# Granite Vision integration for chart understanding
# Automatically detects and extracts chart data
# Part of VLM pipeline
```

## Quick Reference

| Feature | OCR | VLM | Standard (Heron) |
|---------|-----|-----|----------|
| Scanned PDFs | Excellent | Good | Failed |
| Born-digital | Good | Excellent | Excellent |
| Complex tables | Fair | Excellent | Good |
| Chart extraction | No | Yes (v2.72+) | No |
| Speed | Medium | Slow | Fast (28ms/page) |
| Resource use | Medium | High | Low |

## Use Cases

| Document Type | Recommended | Why |
|---------------|-------------|-----|
| Scanned invoices | OCR | Text extraction from images |
| Scientific papers | VLM | Complex formulas, multi-column |
| Born-digital reports | Standard | Fast, accurate |
| Historical documents | OCR | Image-based content |
| Complex financial docs | VLM | Table structure understanding |

## Common Mistakes

### Wrong

```python
# Enabling both OCR and VLM unnecessarily
options = PdfPipelineOptions()
options.do_ocr = True  # Redundant with VLM
options.pipeline_type = PipelineType.VLM
converter = DocumentConverter(pipeline_options=options)
```

### Correct

```python
# Choose based on document type
def get_converter(is_scanned: bool, is_complex: bool):
    options = PdfPipelineOptions()

    if is_scanned:
        options.do_ocr = True
    elif is_complex:
        options.pipeline_type = PipelineType.VLM
    # else: use standard (default)

    return DocumentConverter(pipeline_options=options)
```

## Automatic OCR Detection

```python
# Docling can auto-detect scanned content
converter = DocumentConverter()

# If PDF contains scanned pages, OCR is triggered
result = converter.convert("mixed_content.pdf")

# Check if OCR was used
if result.document.metadata.get("ocr_used"):
    print("OCR was automatically applied")
```

## Performance Considerations

```python
from docling.document_converter import DocumentConverter, PdfPipelineOptions
from docling.datamodel.base_models import PipelineType

# For batch processing, separate by type
standard_converter = DocumentConverter()
ocr_converter = DocumentConverter(
    pipeline_options=PdfPipelineOptions(do_ocr=True)
)
vlm_converter = DocumentConverter(
    pipeline_options=PdfPipelineOptions(pipeline_type=PipelineType.VLM)
)

for doc in documents:
    if doc.is_scanned:
        result = ocr_converter.convert(doc.path)
    elif doc.has_complex_layout:
        result = vlm_converter.convert(doc.path)
    else:
        result = standard_converter.convert(doc.path)
```

## Related

- [concepts/pipeline-architecture.md](pipeline-architecture.md) - Pipeline selection
- [concepts/supported-formats.md](supported-formats.md) - Input formats
- [patterns/advanced-pdf-parsing.md](../patterns/advanced-pdf-parsing.md) - Complex PDFs
