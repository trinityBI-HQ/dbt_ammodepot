# CLI Usage

> **Purpose**: Command-line interface patterns for document conversion, batch processing, and pipeline configuration
> **MCP Validated**: 2026-02-06

## When to Use

- Quick document conversions without Python code
- Shell scripts and automation workflows
- CI/CD pipeline integration
- Batch processing from terminal
- Testing and prototyping

## Implementation

```bash
#!/bin/bash
# Docling CLI usage patterns

# Basic conversion
docling input.pdf

# Specify output directory
docling input.pdf --output ./results

# Batch conversion
docling *.pdf --output ./markdown

# Convert to specific format
docling input.pdf --to markdown
docling input.pdf --to html
docling input.pdf --to json

# Use VLM pipeline
docling input.pdf --pipeline vlm --vlm-model granite_docling

# Enable OCR
docling scanned.pdf --ocr

# Process from URL
docling https://arxiv.org/pdf/2408.09869

# Page range
docling large.pdf --pages 1-10

# Verbose output
docling input.pdf --verbose

# Multiple files with pattern
docling documents/*.pdf --output ./converted

# Custom configuration file
docling input.pdf --config docling.yaml
```

## Shell Script Examples

```bash
#!/bin/bash
# Batch conversion with progress
INPUT_DIR="${1:-./pdfs}"
OUTPUT_DIR="${2:-./markdown}"
mkdir -p "$OUTPUT_DIR"

for pdf in "$INPUT_DIR"/*.pdf; do
    echo "Processing: $(basename "$pdf")"
    docling "$pdf" --output "$OUTPUT_DIR"
done
```

## Python Subprocess Integration

```python
import subprocess

def run_docling_cli(input_path: str, output_dir: str = "./output") -> dict:
    """Run Docling CLI from Python."""
    cmd = ["docling", input_path, "--output", output_dir]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return {"status": "success", "output": result.stdout}
    except subprocess.CalledProcessError as e:
        return {"status": "error", "error": e.stderr}
```

## Make Integration

```makefile
# Makefile
convert-pdfs:
	@for pdf in ./documents/*.pdf; do docling "$$pdf" --output ./output; done
```

## Docker Integration

```bash
# Run in container
docker run --rm -v "$(pwd)/documents:/input" \
    ghcr.io/docling-project/docling:latest docling /input/*.pdf
```

## Configuration File

```yaml
# docling.yaml
pipeline:
  type: vlm
ocr:
  enabled: true
output:
  format: markdown
```

## Example Usage

```bash
# Basic conversion
docling document.pdf

# Batch with VLM
docling papers/*.pdf --pipeline vlm --output ./markdown

# OCR for scanned docs
docling scanned/*.pdf --ocr --output ./text

# URL conversion
docling https://arxiv.org/pdf/2408.09869 --output ./papers
```

## See Also

- [patterns/basic-conversion.md](basic-conversion.md) - Python API
- [patterns/batch-processing.md](batch-processing.md) - Batch patterns
- [concepts/document-converter.md](../concepts/document-converter.md) - API reference
