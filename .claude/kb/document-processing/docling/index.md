# Docling Knowledge Base

> **Purpose**: Document processing framework for parsing PDFs, Office docs, LaTeX, images, and audio into structured formats for GenAI workflows
> **Version**: 2.74.x (Heron layout model, VLM presets, ASR, MCP server)
> **MCP Validated**: 2026-02-19

## Quick Navigation

### Concepts (< 150 lines each)

| File | Purpose |
|------|---------|
| [concepts/document-converter.md](concepts/document-converter.md) | Main API entry point for document conversion |
| [concepts/docling-document.md](concepts/docling-document.md) | Unified document representation format |
| [concepts/pipeline-architecture.md](concepts/pipeline-architecture.md) | Processing pipeline and backend selection |
| [concepts/export-formats.md](concepts/export-formats.md) | Markdown, HTML, JSON, DocTags output |
| [concepts/ocr-vlm-support.md](concepts/ocr-vlm-support.md) | OCR and Visual Language Model integration |
| [concepts/supported-formats.md](concepts/supported-formats.md) | Input format support and capabilities |

### Patterns (< 200 lines each)

| File | Purpose |
|------|---------|
| [patterns/basic-conversion.md](patterns/basic-conversion.md) | Simple document conversion workflow |
| [patterns/batch-processing.md](patterns/batch-processing.md) | Process multiple documents efficiently |
| [patterns/advanced-pdf-parsing.md](patterns/advanced-pdf-parsing.md) | Layout analysis, tables, reading order |
| [patterns/langchain-integration.md](patterns/langchain-integration.md) | RAG pipeline with LangChain |
| [patterns/custom-pipeline-config.md](patterns/custom-pipeline-config.md) | Configure backends and OCR options |
| [patterns/cli-usage.md](patterns/cli-usage.md) | Command-line interface patterns |

---

## Quick Reference

- [quick-reference.md](quick-reference.md) - Fast lookup tables

---

## Key Concepts

| Concept | Description |
|---------|-------------|
| **DocumentConverter** | Main entry point accepting paths/URLs, handles format detection |
| **DoclingDocument** | Rich unified representation preserving layout, tables, metadata |
| **Heron Model** | Default PDF layout model (RT-DETRv2, 20%+ mAP improvement) |
| **Pipeline Backends** | Standard, VLM (GraniteDocling), OCR (EasyOCR), ASR (Whisper) |
| **Export Formats** | Markdown, HTML, JSON, DocTags, plain text |
| **docling-serve** | REST API server with MCP endpoint for agentic integration |

---

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/document-converter.md, patterns/basic-conversion.md |
| **Intermediate** | concepts/pipeline-architecture.md, patterns/advanced-pdf-parsing.md |
| **Advanced** | patterns/custom-pipeline-config.md, patterns/batch-processing.md |

---

## Agent Usage

| Agent | Primary Files | Use Case |
|-------|---------------|----------|
| extraction-specialist | patterns/advanced-pdf-parsing.md | Invoice/document extraction |
| ai-data-engineer | patterns/langchain-integration.md | RAG pipeline integration |
| python-developer | concepts/document-converter.md | SDK integration |
