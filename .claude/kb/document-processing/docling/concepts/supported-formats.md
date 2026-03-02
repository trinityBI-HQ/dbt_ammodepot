# Supported Formats

> **Purpose**: Comprehensive list of input formats and their processing capabilities
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Docling supports a wide range of input formats including PDFs, Microsoft Office documents, images, audio files, and web content. Each format has specific processing capabilities and optimal configuration options.

## The Pattern

```python
from docling.document_converter import DocumentConverter

converter = DocumentConverter()

# PDF documents
pdf_result = converter.convert("document.pdf")

# Office documents
docx_result = converter.convert("report.docx")
pptx_result = converter.convert("presentation.pptx")
xlsx_result = converter.convert("spreadsheet.xlsx")

# Images
img_result = converter.convert("scan.png")

# Audio
audio_result = converter.convert("meeting.mp3")

# Web content
html_result = converter.convert("page.html")

# URLs
url_result = converter.convert("https://example.com/doc.pdf")
```

## Format Capabilities

```python
# PDF - Most advanced support
# - Layout analysis
# - Reading order detection
# - Table structure extraction
# - Formula recognition
# - Image classification
# - OCR for scanned content

# Office Documents - Native structure
# - DOCX: Paragraphs, tables, images, comments (v2.71+)
# - PPTX: Slides, text, shapes, external images
# - XLSX: Sheets, cells, merged cells (v2.72+)

# LaTeX/AsciiDoc - Technical documents (v2.73+)
# - .tex: Mathematical formulas, bibliographies
# - .adoc: Technical documentation

# CSV - Tabular data (v2.22+)
# - Direct structured parsing

# Images - OCR processing
# - PNG, JPEG, TIFF, BMP, WEBP
# - Automatic OCR application

# Audio - ASR transcription (Whisper)
# - WAV, MP3
# - MLX Whisper on Apple Silicon

# XML - Domain-specific
# - USPTO XML: Patent documents
# - JATS XML: Journal articles

# Web - DOM parsing
# - HTML/XHTML: Structure preservation
# - WebVTT: Caption extraction
```

## Quick Reference

| Format | Extensions | Key Features | Auto-detection |
|--------|------------|--------------|----------------|
| PDF | `.pdf` | Heron layout, tables, OCR | Yes |
| Word | `.docx` | Native structure, comments | Yes |
| PowerPoint | `.pptx` | Slides, layout | Yes |
| Excel | `.xlsx` | Sheets, merged cells | Yes |
| LaTeX | `.tex` | Formulas (v2.73+) | Yes |
| AsciiDoc | `.adoc` | Technical docs | Yes |
| CSV | `.csv` | Tabular data | Yes |
| Images | `.png, .jpg, .tiff, .bmp, .webp` | OCR | Yes |
| Audio | `.wav, .mp3` | ASR (Whisper) | Yes |
| Web | `.html` | DOM parsing | Yes |
| Captions | `.vtt` | WebVTT | Yes |
| XML | `.xml` | USPTO, JATS | Yes |

## Format-Specific Options

```python
from docling.document_converter import DocumentConverter, PdfPipelineOptions

# PDF-specific options
pdf_options = PdfPipelineOptions()
pdf_options.do_ocr = True
pdf_options.do_table_structure = True
pdf_converter = DocumentConverter(pipeline_options=pdf_options)

# Other formats use default converter
office_converter = DocumentConverter()
```

## Common Mistakes

### Wrong

```python
# Trying to configure non-PDF formats with PDF options
from docling.datamodel.base_models import PipelineType

options = PdfPipelineOptions()
options.pipeline_type = PipelineType.VLM

converter = DocumentConverter(pipeline_options=options)
result = converter.convert("document.docx")  # VLM ignored for DOCX
```

### Correct

```python
# Use appropriate converter per format
pdf_converter = DocumentConverter(
    pipeline_options=PdfPipelineOptions(do_table_structure=True)
)
office_converter = DocumentConverter()

if file.endswith(".pdf"):
    result = pdf_converter.convert(file)
else:
    result = office_converter.convert(file)
```

## Related

- [concepts/document-converter.md](document-converter.md) - Main API
- [concepts/pipeline-architecture.md](pipeline-architecture.md) - Format-specific pipelines
- [patterns/batch-processing.md](../patterns/batch-processing.md) - Multi-format batches
