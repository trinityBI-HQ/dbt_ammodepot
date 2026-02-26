# Vector Stores

> **Purpose**: Embedding storage and similarity search for RAG applications
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-06

## Overview

Vector stores in Langflow store embeddings (numerical representations of text) and enable similarity search for Retrieval-Augmented Generation (RAG). Langflow integrates with multiple vector databases through LangChain's vector store interfaces, supporting both managed services like Pinecone and self-hosted options like Chroma.

## Supported Vector Stores

| Store | Type | Best For | Scaling |
|-------|------|----------|---------|
| **Pinecone** | Managed | Production, high scale | Automatic |
| **Weaviate** | Self-hosted/Cloud | Hybrid search, GraphQL | Horizontal |
| **Chroma** | Local | Development, testing | Single node |
| **FAISS** | Local | Fast similarity, CPU | Single node |
| **Qdrant** | Self-hosted/Cloud | Production, filtering | Horizontal |

## Vector Store Component

```python
# Pinecone configuration
pinecone_component = {
    "type": "Pinecone",
    "api_key": "${PINECONE_API_KEY}",
    "environment": "us-west1-gcp",
    "index_name": "langflow-docs",
    "namespace": "production",  # Optional isolation
    "dimension": 1536,  # Must match embedding model
    "metric": "cosine"  # Or dot_product, euclidean
}

# Weaviate configuration
weaviate_component = {
    "type": "Weaviate",
    "url": "https://cluster.weaviate.network",
    "api_key": "${WEAVIATE_API_KEY}",
    "index_name": "LangflowDocs",
    "text_key": "content",
    "attributes": ["source", "timestamp"]  # Metadata
}
```

## Operations

| Operation | Purpose | Example |
|-----------|---------|---------|
| **Add** | Store embeddings | `add_documents(docs, embeddings)` |
| **Search** | Find similar vectors | `similarity_search(query, k=5)` |
| **Delete** | Remove embeddings | `delete(ids=[...])` |
| **Update** | Modify metadata | `update_document(id, metadata)` |

## RAG Flow Structure

```text
┌─────────────────┐
│ Document Loader │ → Load PDF/text/web
└────────┬────────┘
         ↓
┌─────────────────┐
│  Text Splitter  │ → Chunk into passages
└────────┬────────┘
         ↓
┌─────────────────┐
│   Embeddings    │ → Convert to vectors
└────────┬────────┘
         ↓
┌─────────────────┐
│  Vector Store   │ → Store for retrieval
└────────┬────────┘
         ↓
┌─────────────────┐
│   Retriever     │ ← User query
└────────┬────────┘
         ↓
┌─────────────────┐
│      LLM        │ → Generate answer with context
└─────────────────┘
```

## Retrieval Configuration

```python
# Basic retrieval
retriever = {
    "vector_store": pinecone,
    "search_type": "similarity",  # Or mmr, similarity_score_threshold
    "k": 5,  # Top k results
    "score_threshold": 0.7  # Minimum similarity
}

# Maximum Marginal Relevance (MMR)
# Balances relevance and diversity
mmr_retriever = {
    "search_type": "mmr",
    "k": 5,
    "fetch_k": 20,  # Fetch 20, rerank to 5
    "lambda_mult": 0.5  # 0=diversity, 1=relevance
}
```

## Metadata Filtering

```python
# Filter by metadata during search
filter_query = {
    "source": "documentation",
    "date": {"$gte": "2026-01-01"},
    "category": {"$in": ["tutorial", "guide"]}
}

# Pinecone filter syntax
results = vector_store.similarity_search(
    query="What is Langflow?",
    k=5,
    filter=filter_query
)

# Returns only matching documents
```

## Common Mistakes

### Wrong

```python
# Dimension mismatch
embeddings_model.dimension = 1536
vector_store.dimension = 768  # Will fail

# No chunking (too large docs)
documents = [entire_pdf_content]  # Context window overflow

# Hardcoded keys
api_key = "pk_abc123..."  # Security risk
```

### Correct

```python
# Matching dimensions
embeddings_model = "text-embedding-ada-002"  # 1536d
vector_store.dimension = 1536

# Proper chunking
text_splitter = {
    "chunk_size": 1000,
    "chunk_overlap": 200
}

# Environment variables
api_key = "${PINECONE_API_KEY}"
```

## Chunking Strategies

| Strategy | Chunk Size | Overlap | Use Case |
|----------|------------|---------|----------|
| **Small** | 200-400 | 50 | Precise retrieval, short answers |
| **Medium** | 800-1200 | 200 | Balanced, most use cases |
| **Large** | 2000-4000 | 400 | Complex context, long answers |

## Performance Optimization

```python
# Batch inserts for efficiency
batch_size = 100
for i in range(0, len(documents), batch_size):
    batch = documents[i:i+batch_size]
    vector_store.add_documents(batch)

# Use namespace for isolation
vector_store.namespace = f"user_{user_id}"

# Enable caching for repeated queries
cache_config = {
    "enable": True,
    "ttl": 3600  # 1 hour
}
```

## Hybrid Search

```python
# Combine vector similarity with keyword search
hybrid_retriever = {
    "vector_store": weaviate,
    "search_type": "hybrid",
    "alpha": 0.5,  # 0=keyword, 1=vector, 0.5=balanced
    "k": 10
}

# Best of both approaches
# Semantic similarity + exact matches
```

## Related

- [data-loaders.md](../concepts/data-loaders.md) - Loading documents
- [language-models.md](../concepts/language-models.md) - LLM for generation
- [vector-rag-chatbot.md](../patterns/vector-rag-chatbot.md) - Complete RAG pattern
