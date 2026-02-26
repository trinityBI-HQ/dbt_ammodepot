# Export Formats

> **Purpose**: Multiple output formats optimized for different use cases including RAG, web display, and structured processing
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Docling provides four primary export formats from the unified `DoclingDocument` representation: Markdown (for LLM prompts and RAG), HTML (for web display), JSON (lossless structured data), and DocTags (custom formatting). Each format preserves different aspects of document structure.

## The Pattern

```python
from docling.document_converter import DocumentConverter

converter = DocumentConverter()
result = converter.convert("document.pdf")
doc = result.document

# Markdown export (RAG/LLM workflows)
markdown = doc.export_to_markdown()

# HTML export (web rendering)
html = doc.export_to_html()

# JSON export (structured processing)
json_data = doc.export_to_dict()

# DocTags export (custom formatting)
doctags = doc.export_to_doctags()
```

## Markdown Export

```python
# Best for: RAG systems, LLM prompts, documentation
markdown = doc.export_to_markdown()

# Preserves:
# - Headings (# ## ###)
# - Tables (markdown tables)
# - Lists (- * 1.)
# - Code blocks (```)
# - Links and emphasis

# Use case: Vector database ingestion
with open("output.md", "w") as f:
    f.write(markdown)
```

## HTML Export

```python
# Best for: Web display, preview, formatted output
html = doc.export_to_html()

# Preserves:
# - Full styling information
# - Table formatting
# - Layout structure
# - Images (as embedded or referenced)

# Use case: Document preview in web app
from flask import render_template_string
return render_template_string(html)
```

## JSON Export

```python
# Best for: Structured processing, custom parsing, archives
json_data = doc.export_to_dict()

# Structure:
# {
#   "name": "document_name",
#   "pages": [
#     {
#       "page_no": 1,
#       "elements": [
#         {
#           "label": "title",
#           "text": "Document Title",
#           "bbox": {"x": 0, "y": 0, "w": 100, "h": 20}
#         }
#       ]
#     }
#   ],
#   "tables": [...],
#   "pictures": [...]
# }

# Use case: Custom element processing
for page in json_data["pages"]:
    for element in page["elements"]:
        if element["label"] == "table":
            process_table(element)
```

## Quick Reference

| Format | Method | Preserves | Best For |
|--------|--------|-----------|----------|
| Markdown | `export_to_markdown()` | Structure, text | RAG, LLM prompts |
| HTML | `export_to_html()` | Styling, layout | Web display |
| JSON | `export_to_dict()` | Everything | Processing, archives |
| DocTags | `export_to_doctags()` | Custom tags | Specialized formatting |

## Format Comparison

```python
from docling.document_converter import DocumentConverter

converter = DocumentConverter()
result = converter.convert("sample.pdf")
doc = result.document

# Markdown: Clean, readable
md = doc.export_to_markdown()
print(md)
# ## Introduction
# This is a paragraph.
# | Col1 | Col2 |
# |------|------|
# | A    | B    |

# HTML: Full styling
html = doc.export_to_html()
# <h2>Introduction</h2>
# <p>This is a paragraph.</p>
# <table><tr><th>Col1</th><th>Col2</th></tr>...</table>

# JSON: Structured
json_data = doc.export_to_dict()
# {"pages": [{"elements": [{"label": "section_header", ...}]}]}
```

## Common Mistakes

### Wrong

```python
# Don't manually parse HTML for structure
html = doc.export_to_html()
# Complex regex parsing of HTML...
tables = extract_tables_from_html(html)  # Error-prone
```

### Correct

```python
# Use JSON for structured access
json_data = doc.export_to_dict()
tables = [t for t in json_data["tables"]]  # Direct access

# Or access document objects directly
tables = doc.tables
for table in tables:
    df = table.export_to_dataframe()
```

## Use Case Examples

```python
# RAG System: Markdown export
def ingest_to_vectordb(pdf_path: str):
    converter = DocumentConverter()
    result = converter.convert(pdf_path)
    markdown = result.document.export_to_markdown()

    # Split into chunks
    chunks = markdown.split("\n\n")
    for chunk in chunks:
        vectordb.add(chunk)

# Document Archive: JSON export
def archive_document(pdf_path: str):
    converter = DocumentConverter()
    result = converter.convert(pdf_path)
    json_data = result.document.export_to_dict()

    # Store with full structure
    import json
    with open(f"{pdf_path}.json", "w") as f:
        json.dump(json_data, f, indent=2)

# Web Preview: HTML export
def generate_preview(pdf_path: str) -> str:
    converter = DocumentConverter()
    result = converter.convert(pdf_path)
    return result.document.export_to_html()
```

## Related

- [concepts/docling-document.md](docling-document.md) - Document structure
- [patterns/langchain-integration.md](../patterns/langchain-integration.md) - RAG with Markdown
- [patterns/batch-processing.md](../patterns/batch-processing.md) - Bulk export
