# Pipeline Architecture

> **Purpose**: Modular processing system with pluggable backends for different document types and quality requirements
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Docling uses a modular pipeline architecture with interchangeable backends. Four pipelines: Standard (Heron layout model, fast), VLM (GraniteDocling for complex layouts), OCR (scanned documents), and ASR (audio via Whisper). v2.73+ uses pluggable VLM presets; v2.74+ uses docling-parse v5 (new PDF engine).

## The Pattern

```python
from docling.document_converter import DocumentConverter, PdfPipelineOptions
from docling.datamodel.base_models import PipelineType

# Standard pipeline (default, fastest)
converter = DocumentConverter()

# VLM pipeline (best quality, slower)
pipeline_options = PdfPipelineOptions()
pipeline_options.pipeline_type = PipelineType.VLM
converter = DocumentConverter(pipeline_options=pipeline_options)

# OCR-enabled pipeline
pipeline_options = PdfPipelineOptions()
pipeline_options.do_ocr = True
converter = DocumentConverter(pipeline_options=pipeline_options)
```

## Pipeline Selection Guide

```python
from docling.document_converter import DocumentConverter, PdfPipelineOptions
from docling.datamodel.base_models import PipelineType

def get_converter_for_document_type(doc_type: str) -> DocumentConverter:
    """Select optimal pipeline based on document type."""

    if doc_type == "scanned_pdf":
        # OCR pipeline for scanned documents
        options = PdfPipelineOptions()
        options.do_ocr = True
        return DocumentConverter(pipeline_options=options)

    elif doc_type == "complex_layout":
        # VLM pipeline for complex tables, multi-column
        options = PdfPipelineOptions()
        options.pipeline_type = PipelineType.VLM
        options.vlm_model = "granite_docling"
        return DocumentConverter(pipeline_options=options)

    else:
        # Standard pipeline for born-digital PDFs
        return DocumentConverter()
```

## Quick Reference

| Pipeline | Speed | Quality | Best For |
|----------|-------|---------|----------|
| Standard (Heron) | Fast (28ms/page) | Good | Born-digital PDFs, simple layouts |
| VLM | Slow | Excellent | Complex tables, charts, multi-column |
| OCR | Medium | Variable | Scanned documents, images |
| ASR (Whisper) | Medium | Good | Audio files (WAV, MP3) |

## Pipeline Components

| Component | Purpose | Configurable |
|-----------|---------|--------------|
| Format Detector | Identifies input format | No |
| PDF Parser | Extracts text and layout | Yes (backend selection) |
| OCR Engine | Processes scanned content | Yes (enable/disable) |
| Table Detector | Identifies table structure | Yes |
| Reading Order | Determines text flow | Yes |
| Layout Classifier | Categorizes elements | Yes |

## Common Mistakes

### Wrong

```python
# Using VLM pipeline for all documents (too slow)
options = PdfPipelineOptions()
options.pipeline_type = PipelineType.VLM
converter = DocumentConverter(pipeline_options=options)

for doc in thousands_of_docs:
    result = converter.convert(doc)  # Very slow!
```

### Correct

```python
# Use appropriate pipeline per document type
standard_converter = DocumentConverter()
vlm_converter = DocumentConverter(
    pipeline_options=PdfPipelineOptions(pipeline_type=PipelineType.VLM)
)

for doc in documents:
    if is_complex_layout(doc):
        result = vlm_converter.convert(doc)
    else:
        result = standard_converter.convert(doc)
```

## Advanced Configuration

```python
from docling.document_converter import DocumentConverter, PdfPipelineOptions
from docling.datamodel.base_models import PipelineType

# Full configuration example
options = PdfPipelineOptions()

# Pipeline type
options.pipeline_type = PipelineType.VLM

# VLM model selection
options.vlm_model = "granite_docling"

# OCR settings
options.do_ocr = True
options.ocr_engine = "easyocr"

# Table extraction
options.do_table_structure = True
options.table_structure_options.do_cell_matching = True

# Reading order
options.generate_page_images = False
options.generate_table_images = False

converter = DocumentConverter(pipeline_options=options)
```

## Related

- [concepts/document-converter.md](document-converter.md) - Main API
- [concepts/ocr-vlm-support.md](ocr-vlm-support.md) - OCR and VLM details
- [patterns/custom-pipeline-config.md](../patterns/custom-pipeline-config.md) - Advanced config
