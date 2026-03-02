# Data Loaders

> **Purpose**: Document ingestion, text splitting, and chunking for RAG pipelines
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-06

## Overview

Data loaders extract text from various sources (files, web, APIs) and prepare it for vector storage. The process includes reading documents, extracting text, splitting into chunks, and adding metadata. Proper chunking strategy is critical for RAG quality.

## Loader Types

| Type | Sources | Use Case |
|------|---------|----------|
| **File** | PDF, TXT, DOCX, MD | Static documents |
| **Web** | URLs, sitemaps | Web content, docs |
| **API** | REST, GraphQL | Dynamic data |
| **Database** | SQL, NoSQL | Structured data |
| **Cloud Storage** | S3, GCS, Azure | Large datasets |

## File Loader Configuration

```python
pdf_loader = {"type": "PyPDFLoader", "file_path": "documents/manual.pdf", "extract_images": False}
text_loader = {"type": "TextLoader", "file_path": "data/notes.txt", "encoding": "utf-8"}
directory_loader = {"type": "DirectoryLoader", "path": "documents/", "glob": "**/*.pdf", "loader_cls": "PyPDFLoader"}
```

## Web Scraping

```python
web_loader = {"type": "WebBaseLoader", "urls": ["https://docs.example.com"], "verify_ssl": True}
sitemap_loader = {"type": "SitemapLoader", "url": "https://docs.example.com/sitemap.xml", "filter_urls": [".*api.*"]}
bs_loader = {"type": "BeautifulSoupLoader", "url": "https://example.com", "css_selector": ".content"}
```

## Text Splitting Strategies

| Strategy | Chunk Size | Overlap | Best For |
|----------|------------|---------|----------|
| **Character** | Fixed chars | 10-20% | General text |
| **Token** | Fixed tokens | 10-20% | LLM context |
| **Recursive** | Adaptive | Variable | Structured docs |
| **Semantic** | Meaning-based | Context-aware | Coherent passages |

## Splitter Configuration

```python
char_splitter = {"type": "CharacterTextSplitter", "chunk_size": 1000, "chunk_overlap": 200, "separator": "\n\n"}

recursive_splitter = {
    "type": "RecursiveCharacterTextSplitter", "chunk_size": 1000,
    "chunk_overlap": 200, "separators": ["\n\n", "\n", ". ", " ", ""]
}

token_splitter = {"type": "TokenTextSplitter", "chunk_size": 500, "chunk_overlap": 50, "encoding_name": "cl100k_base"}
```

## Chunk Size Selection

| Document Type | Recommended Size | Reasoning |
|---------------|------------------|-----------|
| **Code** | 500-800 | Preserve function context |
| **Legal** | 1200-1500 | Long sentences, definitions |
| **Technical docs** | 1000-1200 | Balanced context |
| **Chat logs** | 300-500 | Short messages |
| **Books** | 1500-2000 | Narrative flow |

## Metadata Extraction

```python
metadata = {"source": "user_manual.pdf", "page": 5, "chapter": "Installation", "date": "2026-02-06"}
# Enables filtering during retrieval: "Find in Installation chapter only"
```

## Common Mistakes

```python
# Wrong: too large chunks, no overlap, bad separator
splitter.chunk_size = 10000
splitter.chunk_overlap = 0
splitter.separator = " "  # Splits mid-sentence

# Correct: appropriate size, overlap, smart separators
splitter.chunk_size = 1000
splitter.chunk_overlap = 200
splitter.separators = ["\n\n", "\n", ". "]
```

## Loading Pipeline

```text
Loader (read file/URL) → Extractor (extract text) → Splitter (chunk) → Metadata (add context) → Embeddings (vectorize)
```

## Performance Optimization

```python
# Batch processing
for i in range(0, len(files), 10):
    documents = loader.load_batch(files[i:i+10])

# Parallel loading
from concurrent.futures import ThreadPoolExecutor
with ThreadPoolExecutor(max_workers=5) as executor:
    documents = executor.map(load_document, file_list)
```

## Document Preprocessing

```python
import re
def preprocess(text):
    text = re.sub(r'\s+', ' ', text)        # Remove extra whitespace
    text = re.sub(r'[^\w\s.,!?-]', '', text) # Remove special chars
    return text.replace('\r\n', '\n').strip()
```

## Related

- [vector-stores.md](../concepts/vector-stores.md) - Storing loaded documents
- [language-models.md](../concepts/language-models.md) - Using context in prompts
- [vector-rag-chatbot.md](../patterns/vector-rag-chatbot.md) - Complete loading pipeline
