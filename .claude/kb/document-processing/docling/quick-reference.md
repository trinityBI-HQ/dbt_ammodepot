# Docling Quick Reference

> Fast lookup tables. For code examples, see linked files.

## Installation

| Method | Command | Requirements |
|--------|---------|--------------|
| Standard | `pip install docling` | Python 3.10+ |
| Container | `docker pull ghcr.io/docling-project/docling:latest` | Docker/Podman |

## Supported Input Formats

| Format | Extension | Advanced Features |
|--------|-----------|-------------------|
| PDF | `.pdf` | Heron layout, tables, reading order, formulas |
| Office | `.docx, .pptx, .xlsx` | Native structure, comments (docx) |
| LaTeX | `.tex` | Mathematical formulas (v2.73+) |
| AsciiDoc | `.adoc` | Technical documentation |
| CSV | `.csv` | Tabular data (v2.22+) |
| Web | `.html` | DOM parsing |
| Images | `.png, .jpg, .tiff, .bmp, .webp` | OCR support |
| Audio | `.wav, .mp3` | ASR via Whisper |
| Captions | `.vtt` | WebVTT parsing |
| XML | `.xml` | USPTO patents, JATS journal articles |

## Export Formats

| Format | Method | Use Case |
|--------|--------|----------|
| Markdown | `export_to_markdown()` | RAG, LLM prompts |
| HTML | `export_to_html()` | Web display |
| JSON | `export_to_dict()` | Lossless structured data |
| DocTags | `export_to_doctags()` | Custom formatting |

## Pipeline Backends

| Backend | Best For | Command Flag |
|---------|----------|--------------|
| Standard | Fast PDF parsing (Heron layout model) | Default |
| VLM | Complex layouts, chart extraction | `--pipeline vlm` |
| OCR | Scanned documents | Auto-detected or `--ocr` |
| ASR | Audio transcription (Whisper) | Auto for .wav/.mp3 |

## Common CLI Commands

| Task | Command |
|------|---------|
| Basic conversion | `docling input.pdf` |
| Batch processing | `docling *.pdf --output ./results` |
| VLM pipeline | `docling input.pdf --pipeline vlm` |
| Export to Markdown | `docling input.pdf --to markdown` |

## Decision Matrix

| Use Case | Choose |
|----------|--------|
| Born-digital PDFs | Standard pipeline |
| Scanned PDFs | OCR backend (auto-enabled) |
| Complex tables/layouts | VLM pipeline (GraniteDocling) |
| RAG workflows | Markdown export + LangChain |
| Structured extraction | JSON export + Pydantic |

## Common Pitfalls

| Don't | Do |
|-------|-----|
| Process scanned PDFs without OCR | Enable OCR or use VLM pipeline |
| Ignore pipeline configuration | Customize for your document types |
| Parse all pages when not needed | Use page range options |
| Export large docs to single string | Use structured JSON for processing |

## Framework Integrations

| Framework | Package | Loader Class |
|-----------|---------|--------------|
| LangChain | `langchain-docling` (v2.0) | `DoclingLoader` |
| LlamaIndex | `llama-index-readers-docling` | `DoclingReader` |
| Haystack | `docling-haystack` | `DoclingConverter` |
| CrewAI | Native support | — |
| MCP | `docling-serve` (v1.10+) | REST API + MCP endpoint |

## Related Documentation

| Topic | Path |
|-------|------|
| Getting Started | `concepts/document-converter.md` |
| Full Index | `index.md` |
