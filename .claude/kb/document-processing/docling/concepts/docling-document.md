# DoclingDocument

> **Purpose**: Unified document representation preserving structure, layout, tables, and metadata for downstream GenAI workflows
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

`DoclingDocument` is Docling's core data structure that represents parsed documents in a rich, structured format. It preserves page layout, reading order, table structure, images, and metadata while providing multiple export options for integration with GenAI tools.

## The Pattern

```python
from docling.document_converter import DocumentConverter

converter = DocumentConverter()
result = converter.convert("document.pdf")

# Access the document
doc = result.document

# Document structure
print(f"Pages: {len(doc.pages)}")
print(f"Tables: {len(doc.tables)}")
print(f"Images: {len(doc.pictures)}")

# Metadata
print(f"Title: {doc.name}")
print(f"Origin: {doc.origin}")
```

## Document Structure

```python
# Iterate through pages
for page in doc.pages:
    print(f"Page {page.page_no}:")
    # Access page elements
    for element in page.elements:
        print(f"  Type: {element.label}")
        print(f"  Text: {element.text}")
        print(f"  Bbox: {element.bbox}")

# Access specific element types
for table in doc.tables:
    print(f"Table with {table.num_rows} rows, {table.num_cols} cols")
    # Access table data
    table_data = table.export_to_dataframe()  # Pandas DataFrame
```

## Export Formats

```python
# Markdown export (for RAG/LLM prompts)
markdown = doc.export_to_markdown()

# HTML export (for web display)
html = doc.export_to_html()

# JSON export (lossless, structured)
json_dict = doc.export_to_dict()

# DocTags export (custom formatting)
doctags = doc.export_to_doctags()
```

## Quick Reference

| Property | Type | Description |
|----------|------|-------------|
| `doc.pages` | List[Page] | All pages in document |
| `doc.tables` | List[Table] | Extracted tables |
| `doc.pictures` | List[Picture] | Images and figures |
| `doc.name` | str | Document name/title |
| `doc.origin` | str | Source path or URL |

## Element Types

| Label | Description |
|-------|-------------|
| `title` | Document or section title |
| `paragraph` | Body text paragraph |
| `section_header` | Section heading |
| `table` | Table structure |
| `list_item` | Bulleted/numbered list |
| `figure` | Image or diagram |
| `formula` | Mathematical formula |
| `code` | Code block |

## Common Mistakes

### Wrong

```python
# Don't concatenate all text without structure
all_text = ""
for page in doc.pages:
    for element in page.elements:
        all_text += element.text  # Loses structure
```

### Correct

```python
# Preserve structure with Markdown
markdown = doc.export_to_markdown()  # Maintains headers, tables, lists

# Or use structured JSON
json_data = doc.export_to_dict()
# Process with structure preserved
for page in json_data["pages"]:
    for element in page["elements"]:
        process_element(element["label"], element["text"])
```

## RAG Integration Example

```python
from docling.document_converter import DocumentConverter

converter = DocumentConverter()
result = converter.convert("knowledge_base.pdf")

# Export to Markdown for chunking
markdown = result.document.export_to_markdown()

# Split into chunks (preserving structure)
chunks = markdown.split("## ")  # Split by headers

# Each chunk retains context
for chunk in chunks:
    # Add to vector store with preserved structure
    vector_store.add(chunk)
```

## Related

- [concepts/document-converter.md](document-converter.md) - Creating documents
- [concepts/export-formats.md](export-formats.md) - Export options
- [patterns/langchain-integration.md](../patterns/langchain-integration.md) - RAG workflows
