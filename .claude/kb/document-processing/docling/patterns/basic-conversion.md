# Basic Conversion

> **Purpose**: Simple document conversion workflow for common use cases with minimal configuration
> **MCP Validated**: 2026-02-06

## When to Use

- Converting individual PDFs, Office documents, or images to text
- Quick prototyping and testing Docling capabilities
- Simple RAG ingestion pipelines
- Document preview generation
- Batch conversion with default settings

## Implementation

```python
from docling.document_converter import DocumentConverter
from pathlib import Path

def convert_document(input_path: str, output_format: str = "markdown") -> str:
    """
    Convert a document to specified output format.

    Args:
        input_path: Path to input document (PDF, DOCX, etc.)
        output_format: Output format (markdown, html, json)

    Returns:
        Converted document content as string
    """
    # Initialize converter (reuse for multiple conversions)
    converter = DocumentConverter()

    # Convert document
    result = converter.convert(input_path)

    # Check conversion status
    if result.status != "success":
        raise ValueError(f"Conversion failed: {result.errors}")

    # Export to desired format
    doc = result.document

    if output_format == "markdown":
        return doc.export_to_markdown()
    elif output_format == "html":
        return doc.export_to_html()
    elif output_format == "json":
        import json
        return json.dumps(doc.export_to_dict(), indent=2)
    else:
        raise ValueError(f"Unknown format: {output_format}")


def convert_and_save(input_path: str, output_dir: str = "./output"):
    """Convert document and save to file."""
    converter = DocumentConverter()
    result = converter.convert(input_path)

    # Create output directory
    output_path = Path(output_dir)
    output_path.mkdir(exist_ok=True)

    # Generate output filename
    input_file = Path(input_path)
    output_file = output_path / f"{input_file.stem}.md"

    # Export and save
    markdown = result.document.export_to_markdown()
    output_file.write_text(markdown, encoding="utf-8")

    return str(output_file)


def convert_from_url(url: str) -> str:
    """Convert document directly from URL."""
    converter = DocumentConverter()
    result = converter.convert(url)
    return result.document.export_to_markdown()


def batch_convert_directory(input_dir: str, output_dir: str = "./output"):
    """Convert all supported documents in directory."""
    converter = DocumentConverter()

    input_path = Path(input_dir)
    output_path = Path(output_dir)
    output_path.mkdir(exist_ok=True)

    # Supported extensions
    extensions = {".pdf", ".docx", ".pptx", ".xlsx", ".html", ".png", ".jpg"}

    results = []

    for file_path in input_path.iterdir():
        if file_path.suffix.lower() in extensions:
            try:
                result = converter.convert(str(file_path))
                output_file = output_path / f"{file_path.stem}.md"
                markdown = result.document.export_to_markdown()
                output_file.write_text(markdown, encoding="utf-8")

                results.append({
                    "input": str(file_path),
                    "output": str(output_file),
                    "status": "success"
                })
            except Exception as e:
                results.append({
                    "input": str(file_path),
                    "status": "failed",
                    "error": str(e)
                })

    return results
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `input_path` | Required | Path to document or URL |
| `output_format` | `"markdown"` | Export format (markdown/html/json) |
| `output_dir` | `"./output"` | Directory for output files |

## Example Usage

```python
from docling.document_converter import DocumentConverter

# Example 1: Single document conversion
converter = DocumentConverter()
result = converter.convert("document.pdf")
print(result.document.export_to_markdown())

# Example 2: Convert and save
output_path = convert_and_save("report.pdf", "./markdown_output")
print(f"Saved to: {output_path}")

# Example 3: Convert from URL
markdown = convert_from_url("https://arxiv.org/pdf/2408.09869")
print(markdown[:500])  # First 500 characters

# Example 4: Batch conversion
results = batch_convert_directory("./pdfs", "./markdown")
for r in results:
    print(f"{r['input']}: {r['status']}")

# Example 5: Error handling
try:
    result = converter.convert("document.pdf")
    if result.status == "success":
        doc = result.document
    else:
        print(f"Errors: {result.errors}")
except Exception as e:
    print(f"Conversion failed: {e}")
```

## See Also

- [patterns/batch-processing.md](batch-processing.md) - Advanced batch operations
- [concepts/document-converter.md](../concepts/document-converter.md) - API details
- [concepts/export-formats.md](../concepts/export-formats.md) - Output options
