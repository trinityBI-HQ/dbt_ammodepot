# Batch Processing

> **Purpose**: Efficiently process large volumes of documents with parallel execution, error handling, and progress tracking
> **MCP Validated**: 2026-02-06

## When to Use

- Processing hundreds or thousands of documents
- Document migration projects (PDF to Markdown)
- Building document corpus for RAG systems
- Automated document pipeline workflows
- Archive conversion projects

## Implementation

```python
from docling.document_converter import DocumentConverter
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import List, Dict, Optional
import logging
from dataclasses import dataclass
from datetime import datetime

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@dataclass
class ConversionResult:
    """Result of document conversion."""
    input_path: str
    output_path: Optional[str]
    status: str
    duration_seconds: float
    error: Optional[str] = None
    pages: int = 0
    tables: int = 0


class BatchDocumentProcessor:
    """Process multiple documents efficiently."""

    def __init__(
        self,
        max_workers: int = 4,
        output_format: str = "markdown",
        skip_errors: bool = True
    ):
        """
        Initialize batch processor.

        Args:
            max_workers: Number of parallel workers
            output_format: Output format (markdown/html/json)
            skip_errors: Continue on errors or stop
        """
        self.converter = DocumentConverter()
        self.max_workers = max_workers
        self.output_format = output_format
        self.skip_errors = skip_errors

    def process_file(
        self,
        input_path: Path,
        output_dir: Path
    ) -> ConversionResult:
        """Process single file."""
        start_time = datetime.now()

        try:
            # Convert document
            result = self.converter.convert(str(input_path))

            if result.status != "success":
                return ConversionResult(
                    input_path=str(input_path),
                    output_path=None,
                    status="failed",
                    duration_seconds=(datetime.now() - start_time).total_seconds(),
                    error=str(result.errors)
                )

            # Export to desired format
            doc = result.document

            if self.output_format == "markdown":
                content = doc.export_to_markdown()
                extension = ".md"
            elif self.output_format == "html":
                content = doc.export_to_html()
                extension = ".html"
            else:  # json
                import json
                content = json.dumps(doc.export_to_dict(), indent=2)
                extension = ".json"

            # Save output
            output_path = output_dir / f"{input_path.stem}{extension}"
            output_path.write_text(content, encoding="utf-8")

            duration = (datetime.now() - start_time).total_seconds()

            return ConversionResult(
                input_path=str(input_path),
                output_path=str(output_path),
                status="success",
                duration_seconds=duration,
                pages=len(doc.pages),
                tables=len(doc.tables)
            )

        except Exception as e:
            duration = (datetime.now() - start_time).total_seconds()
            logger.error(f"Error processing {input_path}: {e}")

            return ConversionResult(
                input_path=str(input_path),
                output_path=None,
                status="error",
                duration_seconds=duration,
                error=str(e)
            )

    def process_directory(
        self, input_dir: str, output_dir: str, extensions: Optional[List[str]] = None
    ) -> List[ConversionResult]:
        """Process all documents in directory."""
        input_path = Path(input_dir)
        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)

        if extensions is None:
            extensions = [".pdf", ".docx", ".pptx", ".xlsx", ".html"]

        files = [f for f in input_path.iterdir() if f.suffix.lower() in extensions]
        results = []

        with ThreadPoolExecutor(max_workers=self.max_workers) as executor:
            futures = {executor.submit(self.process_file, f, output_path): f for f in files}
            for future in as_completed(futures):
                results.append(future.result())

        return results

    def generate_report(self, results: List[ConversionResult]) -> Dict:
        """Generate summary report."""
        total = len(results)
        successful = sum(1 for r in results if r.status == "success")
        return {
            "total_files": total,
            "successful": successful,
            "failed": total - successful,
            "success_rate": f"{(successful/total*100):.1f}%" if total > 0 else "0%"
        }
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `max_workers` | `4` | Parallel workers (adjust based on CPU) |
| `output_format` | `"markdown"` | Export format |
| `skip_errors` | `True` | Continue on errors |
| `extensions` | All supported | File types to process |

## Example Usage

```python
# Basic batch processing
processor = BatchDocumentProcessor(max_workers=4)
results = processor.process_directory("./pdfs", "./markdown")

# Generate report
report = processor.generate_report(results)
print(f"Processed: {report['total_files']}, Success: {report['success_rate']}")
```

## See Also

- [patterns/basic-conversion.md](basic-conversion.md) - Single document conversion
- [concepts/document-converter.md](../concepts/document-converter.md) - API reference
- [patterns/custom-pipeline-config.md](custom-pipeline-config.md) - Pipeline options
