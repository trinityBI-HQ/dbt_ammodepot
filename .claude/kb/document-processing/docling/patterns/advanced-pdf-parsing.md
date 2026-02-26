# Advanced PDF Parsing

> **Purpose**: Extract complex PDF structures including tables, formulas, reading order, and visual elements with high accuracy
> **MCP Validated**: 2026-02-06

## When to Use

- Processing scientific papers with complex formulas
- Extracting tables from financial reports
- Handling multi-column layouts
- Processing documents with merged table cells
- Documents requiring precise reading order

## Implementation

```python
from docling.document_converter import DocumentConverter, PdfPipelineOptions
from docling.datamodel.base_models import PipelineType
from typing import List, Dict
import pandas as pd


class AdvancedPdfParser:
    """Parse PDFs with advanced structure extraction."""

    def __init__(self, use_vlm: bool = False):
        """
        Initialize parser.

        Args:
            use_vlm: Use Visual Language Model for best quality
        """
        options = PdfPipelineOptions()

        if use_vlm:
            # VLM pipeline for complex layouts
            options.pipeline_type = PipelineType.VLM
            options.vlm_model = "granite_docling"
        else:
            # Standard pipeline with all features
            options.do_table_structure = True
            options.do_ocr = False  # Enable if scanned

        self.converter = DocumentConverter(pipeline_options=options)

    def extract_tables(self, pdf_path: str) -> List[pd.DataFrame]:
        """
        Extract all tables as DataFrames.

        Args:
            pdf_path: Path to PDF file

        Returns:
            List of pandas DataFrames, one per table
        """
        result = self.converter.convert(pdf_path)
        doc = result.document

        tables = []
        for table in doc.tables:
            # Convert to DataFrame
            df = table.export_to_dataframe()
            tables.append(df)

        return tables

    def extract_structured_content(self, pdf_path: str) -> Dict:
        """Extract document with structure."""
        result = self.converter.convert(pdf_path)
        doc = result.document
        content = {"title": None, "sections": [], "tables": [], "formulas": []}

        for page in doc.pages:
            for element in page.elements:
                if element.label == "title" and content["title"] is None:
                    content["title"] = element.text
                elif element.label == "formula":
                    content["formulas"].append(element.text)

        return content

    def extract_with_reading_order(self, pdf_path: str) -> str:
        """
        Extract text in correct reading order.

        Critical for multi-column layouts.
        """
        result = self.converter.convert(pdf_path)

        # Markdown export preserves reading order
        markdown = result.document.export_to_markdown()

        return markdown

    def extract_table_with_metadata(
        self,
        pdf_path: str,
        table_index: int = 0
    ) -> Dict:
        """
        Extract table with location and structure metadata.

        Args:
            pdf_path: Path to PDF
            table_index: Which table to extract (0-indexed)

        Returns:
            Dictionary with DataFrame and metadata
        """
        result = self.converter.convert(pdf_path)
        doc = result.document

        if table_index >= len(doc.tables):
            raise ValueError(f"Table {table_index} not found")

        table = doc.tables[table_index]

        return {
            "data": table.export_to_dataframe(),
            "num_rows": table.num_rows,
            "num_cols": table.num_cols,
            "bbox": table.bbox,  # Bounding box
            "page": table.page_no
        }


def parse_scientific_paper(pdf_path: str) -> Dict:
    """Parse scientific paper with VLM pipeline."""
    parser = AdvancedPdfParser(use_vlm=True)
    result = parser.converter.convert(pdf_path)
    doc = result.document

    paper = {"title": None, "sections": {}, "tables": [], "formulas": []}

    for page in doc.pages:
        for element in page.elements:
            if element.label == "title" and paper["title"] is None:
                paper["title"] = element.text
            elif element.label == "formula":
                paper["formulas"].append(element.text)
            elif element.label == "table":
                paper["tables"].append(element)

    return paper
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `use_vlm` | `False` | Enable VLM for complex layouts |
| `do_table_structure` | `True` | Extract table structure |
| `do_ocr` | Auto | Enable for scanned PDFs |
| `vlm_model` | `"granite_docling"` | VLM model selection |

## Example Usage

```python
# Extract all tables
parser = AdvancedPdfParser()
tables = parser.extract_tables("financial_report.pdf")
for i, df in enumerate(tables):
    df.to_csv(f"table_{i}.csv")

# Parse scientific paper
paper_data = parse_scientific_paper("research_paper.pdf")
print(f"Title: {paper_data['title']}, Tables: {len(paper_data['tables'])}")
```

## See Also

- [concepts/pipeline-architecture.md](../concepts/pipeline-architecture.md) - VLM pipeline
- [concepts/ocr-vlm-support.md](../concepts/ocr-vlm-support.md) - OCR and VLM details
- [patterns/batch-processing.md](batch-processing.md) - Process multiple PDFs
