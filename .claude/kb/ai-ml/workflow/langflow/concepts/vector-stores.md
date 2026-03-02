# Vector Stores

> **Purpose**: Embedding storage and similarity search for RAG applications
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-06

## Overview

Vector stores in Langflow store embeddings and enable similarity search for RAG. Langflow integrates with multiple vector databases through LangChain's interfaces, supporting managed services (Pinecone) and self-hosted options (Chroma).

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
pinecone_component = {
    "type": "Pinecone", "api_key": "${PINECONE_API_KEY}",
    "environment": "us-west1-gcp", "index_name": "langflow-docs",
    "namespace": "production", "dimension": 1536, "metric": "cosine"
}

weaviate_component = {
    "type": "Weaviate", "url": "https://cluster.weaviate.network",
    "api_key": "${WEAVIATE_API_KEY}", "index_name": "LangflowDocs",
    "text_key": "content", "attributes": ["source", "timestamp"]
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
Document Loader → Text Splitter → Embeddings → Vector Store → Retriever ← Query → LLM → Answer
```

## Retrieval Configuration

```python
# Basic similarity retrieval
retriever = {"vector_store": pinecone, "search_type": "similarity", "k": 5, "score_threshold": 0.7}

# MMR: balances relevance and diversity
mmr_retriever = {"search_type": "mmr", "k": 5, "fetch_k": 20, "lambda_mult": 0.5}
```

## Metadata Filtering

```python
filter_query = {"source": "documentation", "date": {"$gte": "2026-01-01"}, "category": {"$in": ["tutorial", "guide"]}}
results = vector_store.similarity_search(query="What is Langflow?", k=5, filter=filter_query)
```

## Common Mistakes

```python
# Wrong: dimension mismatch, no chunking, hardcoded keys
embeddings_model.dimension = 1536
vector_store.dimension = 768  # Will fail

# Correct: matching dimensions, proper chunking, env vars
vector_store.dimension = 1536  # Match embedding model
text_splitter = {"chunk_size": 1000, "chunk_overlap": 200}
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
# Batch inserts
for i in range(0, len(documents), 100):
    vector_store.add_documents(documents[i:i+100])

# Namespace isolation
vector_store.namespace = f"user_{user_id}"

# Caching
cache_config = {"enable": True, "ttl": 3600}
```

## Hybrid Search

```python
hybrid_retriever = {
    "vector_store": weaviate, "search_type": "hybrid",
    "alpha": 0.5, "k": 10  # 0=keyword, 1=vector, 0.5=balanced
}
```

## Related

- [data-loaders.md](../concepts/data-loaders.md) - Loading documents
- [language-models.md](../concepts/language-models.md) - LLM for generation
- [vector-rag-chatbot.md](../patterns/vector-rag-chatbot.md) - Complete RAG pattern
