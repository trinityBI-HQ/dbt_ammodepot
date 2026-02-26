# Custom Pipeline Configuration

> **Purpose**: Advanced pipeline configuration for optimizing performance, quality, and resource usage based on document types
> **MCP Validated**: 2026-02-06

## When to Use

- Fine-tuning performance for specific document types
- Optimizing resource usage (CPU, GPU, memory)
- Handling mixed document batches efficiently
- Custom OCR or VLM requirements
- Production deployment optimization

## Implementation

```python
from docling.document_converter import DocumentConverter, PdfPipelineOptions
from docling.datamodel.base_models import PipelineType
from typing import Optional, Dict
from enum import Enum


class DocumentProfile(Enum):
    """Predefined document profiles."""
    FAST = "fast"  # Speed priority
    BALANCED = "balanced"  # Speed/quality balance
    QUALITY = "quality"  # Quality priority
    SCANNED = "scanned"  # Scanned documents
    SCIENTIFIC = "scientific"  # Research papers
    FINANCIAL = "financial"  # Financial reports


class PipelineConfigFactory:
    """Factory for creating optimized pipeline configurations."""

    @staticmethod
    def create_options(profile: DocumentProfile) -> PdfPipelineOptions:
        """
        Create pipeline options for document profile.

        Args:
            profile: Document profile enum

        Returns:
            Configured PdfPipelineOptions
        """
        options = PdfPipelineOptions()

        if profile == DocumentProfile.FAST:
            # Standard pipeline, minimal processing
            options.do_table_structure = False
            options.generate_page_images = False
            options.generate_table_images = False

        elif profile == DocumentProfile.BALANCED:
            # Standard pipeline with table extraction
            options.do_table_structure = True
            options.generate_page_images = False

        elif profile == DocumentProfile.QUALITY:
            # VLM pipeline for best quality
            options.pipeline_type = PipelineType.VLM
            options.vlm_model = "granite_docling"
            options.do_table_structure = True

        elif profile == DocumentProfile.SCANNED:
            # OCR-enabled pipeline
            options.do_ocr = True
            options.ocr_engine = "easyocr"
            options.do_table_structure = True

        elif profile == DocumentProfile.SCIENTIFIC:
            # VLM with formula and table extraction
            options.pipeline_type = PipelineType.VLM
            options.vlm_model = "granite_docling"
            options.do_table_structure = True

        elif profile == DocumentProfile.FINANCIAL:
            # VLM for complex table structures
            options.pipeline_type = PipelineType.VLM
            options.vlm_model = "granite_docling"
            options.do_table_structure = True

        return options


class MultiProfileConverter:
    """Converter that routes documents to optimal pipeline."""

    def __init__(self):
        """Initialize converters for each profile."""
        self.converters: Dict[DocumentProfile, DocumentConverter] = {}

        # Pre-create converters for common profiles
        for profile in [
            DocumentProfile.FAST,
            DocumentProfile.BALANCED,
            DocumentProfile.QUALITY,
            DocumentProfile.SCANNED
        ]:
            options = PipelineConfigFactory.create_options(profile)
            self.converters[profile] = DocumentConverter(pipeline_options=options)

    def convert(
        self,
        file_path: str,
        profile: DocumentProfile = DocumentProfile.BALANCED
    ):
        """
        Convert document with specified profile.

        Args:
            file_path: Path to document
            profile: Document processing profile

        Returns:
            Conversion result
        """
        if profile not in self.converters:
            options = PipelineConfigFactory.create_options(profile)
            self.converters[profile] = DocumentConverter(pipeline_options=options)

        converter = self.converters[profile]
        return converter.convert(file_path)


def create_custom_pipeline(
    enable_ocr: bool = False, use_vlm: bool = False, extract_tables: bool = True
) -> DocumentConverter:
    """Create customized pipeline."""
    options = PdfPipelineOptions()
    if use_vlm:
        options.pipeline_type = PipelineType.VLM
        options.vlm_model = "granite_docling"
    if enable_ocr:
        options.do_ocr = True
    options.do_table_structure = extract_tables
    return DocumentConverter(pipeline_options=options)


class AdaptiveConverter:
    """Automatically selects optimal pipeline."""

    def __init__(self):
        self.standard = DocumentConverter()
        self.ocr = DocumentConverter(pipeline_options=PdfPipelineOptions(do_ocr=True))
        self.vlm = DocumentConverter(
            pipeline_options=PdfPipelineOptions(
                pipeline_type=PipelineType.VLM, vlm_model="granite_docling"
            )
        )

    def convert(self, file_path: str):
        """Convert with automatic profile selection."""
        result = self.standard.convert(file_path)
        if result.status != "success":
            return self.ocr.convert(file_path)
        elif len(result.document.tables) > 3:
            return self.vlm.convert(file_path)
        return result
```

## Configuration

| Option | Values | Impact |
|--------|--------|--------|
| `pipeline_type` | `STANDARD`, `VLM` | Quality vs Speed |
| `do_ocr` | `True`, `False` | Scanned doc support |
| `do_table_structure` | `True`, `False` | Table extraction quality |
| `vlm_model` | `"granite_docling"` | VLM model selection |
| `generate_page_images` | `True`, `False` | Memory usage |

## Example Usage

```python
# Use predefined profiles
converter = MultiProfileConverter()
result = converter.convert("simple.pdf", DocumentProfile.FAST)

# Custom configuration
converter = create_custom_pipeline(
    enable_ocr=True, use_vlm=True, page_range=(1, 10)
)
result = converter.convert("large_document.pdf")

# Adaptive conversion
adaptive = AdaptiveConverter()
result = adaptive.convert("unknown_type.pdf")
```

## See Also

- [concepts/pipeline-architecture.md](../concepts/pipeline-architecture.md) - Pipeline details
- [concepts/ocr-vlm-support.md](../concepts/ocr-vlm-support.md) - OCR and VLM options
- [patterns/batch-processing.md](batch-processing.md) - Batch optimization
