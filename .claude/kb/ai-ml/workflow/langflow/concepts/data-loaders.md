# Data Loaders

> **Purpose**: Document ingestion, text splitting, and chunking for RAG pipelines
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-06

## Overview

Data loaders in Langflow extract text from various sources (files, web, APIs) and prepare it for vector storage. The loading process includes reading documents, extracting text, splitting into chunks, and optionally adding metadata. Proper chunking strategy is critical for RAG quality.

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
# PDF loader
pdf_loader = {
    "type": "PyPDFLoader",
    "file_path": "documents/manual.pdf",
    "extract_images": False,  # Skip images for text-only
    "password": None  # For encrypted PDFs
}

# Text file loader
text_loader = {
    "type": "TextLoader",
    "file_path": "data/notes.txt",
    "encoding": "utf-8"
}

# Directory loader (multiple files)
directory_loader = {
    "type": "DirectoryLoader",
    "path": "documents/",
    "glob": "**/*.pdf",  # Load all PDFs recursively
    "loader_cls": "PyPDFLoader"
}
```

## Web Scraping

```python
# Single URL
web_loader = {
    "type": "WebBaseLoader",
    "urls": ["https://docs.example.com"],
    "verify_ssl": True
}

# Sitemap (multiple pages)
sitemap_loader = {
    "type": "SitemapLoader",
    "url": "https://docs.example.com/sitemap.xml",
    "filter_urls": ["https://docs.example.com/api/.*"]  # Regex filter
}

# Beautiful Soup (custom parsing)
bs_loader = {
    "type": "BeautifulSoupLoader",
    "url": "https://example.com",
    "css_selector": ".content"  # Extract specific elements
}
```

## Text Splitting

| Strategy | Chunk Size | Overlap | Best For |
|----------|------------|---------|----------|
| **Character** | Fixed chars | 10-20% | General text |
| **Token** | Fixed tokens | 10-20% | LLM context |
| **Recursive** | Adaptive | Variable | Structured docs |
| **Semantic** | Meaning-based | Context-aware | Coherent passages |

## Text Splitter Configuration

```python
# Character splitter (simple)
char_splitter = {
    "type": "CharacterTextSplitter",
    "chunk_size": 1000,  # Characters
    "chunk_overlap": 200,  # Maintain context
    "separator": "\n\n"  # Split on paragraphs
}

# Recursive splitter (smart)
recursive_splitter = {
    "type": "RecursiveCharacterTextSplitter",
    "chunk_size": 1000,
    "chunk_overlap": 200,
    "separators": ["\n\n", "\n", ". ", " ", ""]  # Try in order
}

# Token-based (for LLM context)
token_splitter = {
    "type": "TokenTextSplitter",
    "chunk_size": 500,  # Tokens, not chars
    "chunk_overlap": 50,
    "encoding_name": "cl100k_base"  # GPT-4 tokenizer
}
```

## Chunking Best Practices

```python
# Quality > Quantity
# Clean, well-structured chunks produce better results

# Good chunking
good_chunk = """
# Section Title

This is a complete paragraph that discusses a single topic.
It provides context and examples. The chunk size is appropriate
for the use case, maintaining semantic coherence.
"""

# Bad chunking
bad_chunk = """
...end of one topic.

# New Topic
This starts a completely different...
"""  # Fragments from different contexts
```

## Metadata Extraction

```python
# Add metadata to chunks
metadata = {
    "source": "user_manual.pdf",
    "page": 5,
    "chapter": "Installation",
    "date": "2026-02-06",
    "version": "2.0"
}

# Enables filtering during retrieval
# Example: "Find in Installation chapter only"
```

## Common Mistakes

### Wrong

```python
# Too large chunks (exceed context window)
splitter.chunk_size = 10000  # May not fit in retrieval

# No overlap (loses context)
splitter.chunk_overlap = 0

# Wrong separator (breaks meaning)
splitter.separator = " "  # Splits mid-sentence
```

### Correct

```python
# Appropriate size for use case
splitter.chunk_size = 1000  # Fits well in context

# Overlap maintains context
splitter.chunk_overlap = 200  # ~20%

# Smart separators
splitter.separators = ["\n\n", "\n", ". "]  # Semantic boundaries
```

## Chunk Size Selection

| Document Type | Recommended Size | Reasoning |
|---------------|------------------|-----------|
| **Code** | 500-800 | Preserve function context |
| **Legal** | 1200-1500 | Long sentences, definitions |
| **Technical docs** | 1000-1200 | Balanced context |
| **Chat logs** | 300-500 | Short messages |
| **Books** | 1500-2000 | Narrative flow |

## Loading Pipeline

```text
┌──────────────┐
│   Loader     │ → Read file/URL
└──────┬───────┘
       ↓
┌──────────────┐
│  Extractor   │ → Extract text
└──────┬───────┘
       ↓
┌──────────────┐
│   Splitter   │ → Chunk into passages
└──────┬───────┘
       ↓
┌──────────────┐
│  Metadata    │ → Add context
└──────┬───────┘
       ↓
┌──────────────┐
│ Embeddings   │ → Convert to vectors
└──────────────┘
```

## Performance Optimization

```python
# Batch processing
batch_size = 10
for i in range(0, len(files), batch_size):
    batch = files[i:i+batch_size]
    documents = loader.load_batch(batch)
    process_documents(documents)

# Parallel loading
from concurrent.futures import ThreadPoolExecutor

with ThreadPoolExecutor(max_workers=5) as executor:
    documents = executor.map(load_document, file_list)
```

## Document Preprocessing

```python
# Clean text before chunking
def preprocess(text):
    # Remove extra whitespace
    text = re.sub(r'\s+', ' ', text)

    # Remove special characters
    text = re.sub(r'[^\w\s.,!?-]', '', text)

    # Normalize line breaks
    text = text.replace('\r\n', '\n')

    return text.strip()

# Better chunking quality
```

## Related

- [vector-stores.md](../concepts/vector-stores.md) - Storing loaded documents
- [language-models.md](../concepts/language-models.md) - Using context in prompts
- [vector-rag-chatbot.md](../patterns/vector-rag-chatbot.md) - Complete loading pipeline
