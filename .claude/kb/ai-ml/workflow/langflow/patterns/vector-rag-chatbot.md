# Vector RAG Chatbot

> **Purpose**: Build production-ready RAG chatbot with vector store retrieval for context-aware responses
> **MCP Validated**: 2026-02-06

## When to Use

- Chatbot answering questions from custom documents
- Documentation assistant, customer support, knowledge base QA
- Need accurate, context-grounded responses with citation tracking

## Implementation

```python
# 1. INDEXING SUB-FLOW (populate vector store)
document_loader = {"type": "DirectoryLoader", "path": "docs/", "glob": "**/*.{md,txt,pdf}"}
text_splitter = {
    "type": "RecursiveCharacterTextSplitter", "chunk_size": 1000,
    "chunk_overlap": 200, "separators": ["\n\n", "\n", ". ", " "]
}
embeddings = {"type": "OpenAIEmbeddings", "model": "text-embedding-ada-002", "api_key": "${OPENAI_API_KEY}"}
vector_store = {
    "type": "Pinecone", "api_key": "${PINECONE_API_KEY}",
    "environment": "us-west1-gcp", "index_name": "langflow-docs", "namespace": "production"
}
# Flow: document_loader → text_splitter → embeddings → vector_store

# 2. QUERY SUB-FLOW (answer questions)
user_input = {"type": "TextInput", "name": "question"}
retriever = {"type": "VectorStoreRetriever", "vector_store": vector_store, "search_type": "similarity", "k": 5, "score_threshold": 0.7}

context_formatter = {
    "type": "PromptTemplate",
    "template": "Use the context to answer. If not in context, say so.\n\nContext:\n{context}\n\nQuestion: {question}\n\nAnswer:",
    "input_variables": ["context", "question"]
}
llm = {"type": "ChatOpenAI", "model": "gpt-4", "temperature": 0.3, "max_tokens": 500, "api_key": "${OPENAI_API_KEY}"}

# Flow: user_input → retriever → context_formatter → llm → output
# Also: user_input → context_formatter.question
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `chunk_size` | 1000 | Characters per chunk |
| `chunk_overlap` | 200 | Overlap between chunks |
| `k` | 5 | Number of chunks to retrieve |
| `score_threshold` | 0.7 | Minimum similarity score |
| `temperature` | 0.3 | LLM creativity (lower for factual) |
| `max_tokens` | 500 | Maximum response length |

## API Usage

```python
import requests
url = "https://api.langflow.app/api/v1/run/rag-chatbot"
headers = {"Authorization": f"Bearer {LANGFLOW_API_KEY}"}
payload = {"inputs": {"question": "How do I deploy a Langflow app to production?"}}
result = requests.post(url, json=payload, headers=headers, timeout=30).json()
```

## Multi-Query RAG (Advanced)

```python
# Generate query variations for better retrieval
query_rewriter = {
    "type": "ChatOpenAI", "model": "gpt-3.5-turbo", "temperature": 0.5,
    "prompt": "Generate 3 variations of: {question}"
}
retriever_multi = {"search_type": "mmr", "k": 3, "fetch_k": 15}
# Retrieve per variation, combine and deduplicate
```

## Hybrid Search

```python
hybrid_retriever = {
    "type": "WeaviateHybridRetriever", "vector_store": weaviate_store,
    "alpha": 0.5, "k": 10  # 0=keyword, 1=semantic
}
```

## Reranking

```python
reranker = {"type": "CohereRerank", "api_key": "${COHERE_API_KEY}", "model": "rerank-english-v2.0", "top_n": 5}
# Flow: retriever → reranker → context_formatter (improves precision 15-30%)
```

## Citation Tracking

```python
sources = [f"- {chunk.metadata['source']}, page {chunk.metadata['page']}" for chunk in retrieved_chunks]
# Append sources to answer for verifiability
```

## Quality Monitoring

```python
metrics = {
    "retrieval_latency_ms": 150, "generation_latency_ms": 800,
    "chunks_retrieved": 5, "avg_relevance_score": 0.82, "sources_cited": 2
}
# Alert if latency > 2s or relevance < 0.7
```

## Common Pitfalls

```python
# Wrong                          # Correct
retriever.k = 20                 # retriever.k = 5 (focused retrieval)
llm.temperature = 1.0            # llm.temperature = 0.3 (factual)
splitter.separator = " "         # splitter.separators = ["\n\n", "\n", ". "]
```

## See Also

- [vector-stores.md](../concepts/vector-stores.md) - Vector store configuration
- [data-loaders.md](../concepts/data-loaders.md) - Document loading and chunking
- [language-models.md](../concepts/language-models.md) - LLM optimization
- [production-deployment.md](../patterns/production-deployment.md) - Deployment strategies
