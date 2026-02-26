# DocumentConverter

> **Purpose**: Main API entry point for converting documents from various formats into structured DoclingDocument
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

`DocumentConverter` is the primary interface in Docling for processing documents. It handles format detection, pipeline selection, and orchestrates the conversion of PDFs, Office documents, images, and audio into a unified `DoclingDocument` representation.

## The Pattern

```python
from docling.document_converter import DocumentConverter

# Basic initialization
converter = DocumentConverter()

# Convert from local path
result = converter.convert("document.pdf")

# Convert from URL
result = converter.convert("https://arxiv.org/pdf/2408.09869")

# Access the document
doc = result.document

# Export to various formats
markdown_text = doc.export_to_markdown()
html_text = doc.export_to_html()
json_data = doc.export_to_dict()
```

## Configuration Options

```python
from docling.document_converter import DocumentConverter, PdfPipelineOptions
from docling.datamodel.pipeline_options import PdfPipelineOptions

# Configure pipeline
pipeline_options = PdfPipelineOptions()
pipeline_options.do_ocr = True  # Enable OCR for scanned docs
pipeline_options.do_table_structure = True  # Extract table structure

converter = DocumentConverter(
    pipeline_options=pipeline_options
)
```

## Quick Reference

| Input | Output | Notes |
|-------|--------|-------|
| `.pdf` file | `ConversionResult` | Auto-detects PDF type (digital/scanned) |
| `.docx` file | `ConversionResult` | Preserves native structure |
| URL string | `ConversionResult` | Downloads and processes |
| Multiple files | Iterator of results | Use batch processing |

## Common Mistakes

### Wrong

```python
# Don't create converter per document
for doc in documents:
    converter = DocumentConverter()  # Wasteful
    result = converter.convert(doc)
```

### Correct

```python
# Reuse converter instance
converter = DocumentConverter()
for doc in documents:
    result = converter.convert(doc)
```

## Batch Processing

```python
from pathlib import Path

converter = DocumentConverter()
pdf_files = Path("./documents").glob("*.pdf")

for pdf_path in pdf_files:
    result = converter.convert(str(pdf_path))
    # Process result
    output_path = pdf_path.with_suffix(".md")
    output_path.write_text(result.document.export_to_markdown())
```

## Error Handling

```python
from docling.document_converter import DocumentConverter

converter = DocumentConverter()

try:
    result = converter.convert("document.pdf")
    if result.status == "success":
        doc = result.document
    else:
        print(f"Conversion failed: {result.errors}")
except Exception as e:
    print(f"Error processing document: {e}")
```

## Related

- [concepts/docling-document.md](docling-document.md) - Output format structure
- [concepts/pipeline-architecture.md](pipeline-architecture.md) - Backend selection
- [patterns/batch-processing.md](../patterns/batch-processing.md) - Process multiple docs
