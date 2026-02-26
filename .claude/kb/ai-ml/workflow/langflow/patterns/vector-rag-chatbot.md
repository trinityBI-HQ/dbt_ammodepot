# Vector RAG Chatbot

> **Purpose**: Build production-ready RAG chatbot with vector store retrieval for context-aware responses
> **MCP Validated**: 2026-02-06

## When to Use

- Need chatbot to answer questions using custom documents
- Want accurate, context-aware responses grounded in your data
- Building documentation assistant, customer support, or knowledge base QA
- Require citation/source tracking for answers

## Implementation

```python
# Complete RAG chatbot flow in Langflow

# 1. INDEXING SUB-FLOW (populate vector store)

# Load documents
document_loader = {
    "type": "DirectoryLoader",
    "path": "docs/",
    "glob": "**/*.{md,txt,pdf}",
    "show_progress": True
}

# Split into chunks
text_splitter = {
    "type": "RecursiveCharacterTextSplitter",
    "chunk_size": 1000,
    "chunk_overlap": 200,
    "separators": ["\n\n", "\n", ". ", " "]
}

# Generate embeddings
embeddings = {
    "type": "OpenAIEmbeddings",
    "model": "text-embedding-ada-002",
    "api_key": "${OPENAI_API_KEY}"
}

# Store in vector database
vector_store = {
    "type": "Pinecone",
    "api_key": "${PINECONE_API_KEY}",
    "environment": "us-west1-gcp",
    "index_name": "langflow-docs",
    "namespace": "production"
}

# Connect components
# document_loader → text_splitter → embeddings → vector_store


# 2. QUERY SUB-FLOW (answer questions)

# User question input
user_input = {
    "type": "TextInput",
    "name": "question",
    "placeholder": "Ask a question about the documentation..."
}

# Generate query embedding
query_embedding = {
    "type": "OpenAIEmbeddings",
    "model": "text-embedding-ada-002",
    "api_key": "${OPENAI_API_KEY}"
}

# Retrieve relevant chunks
retriever = {
    "type": "VectorStoreRetriever",
    "vector_store": vector_store,
    "search_type": "similarity",
    "k": 5,  # Top 5 most relevant chunks
    "score_threshold": 0.7  # Minimum relevance
}

# Format context for LLM
context_formatter = {
    "type": "PromptTemplate",
    "template": """
Use the following documentation excerpts to answer the question.
If the answer is not in the context, say "I don't have enough information to answer that question."

Context:
{context}

Question: {question}

Instructions:
1. Provide a clear, accurate answer based on the context
2. Cite which document section you used
3. Be concise but complete

Answer:""",
    "input_variables": ["context", "question"]
}

# Generate answer
llm = {
    "type": "ChatOpenAI",
    "model": "gpt-4",
    "temperature": 0.3,  # Lower for factual responses
    "max_tokens": 500,
    "api_key": "${OPENAI_API_KEY}"
}

# Output to user
output = {
    "type": "TextOutput",
    "name": "answer"
}

# Connect query components
# user_input → query_embedding → retriever → context_formatter → llm → output


# 3. COMPLETE FLOW CONNECTIONS

# Indexing (run once or periodically)
# document_loader.output → text_splitter.input
# text_splitter.output → embeddings.input
# embeddings.output → vector_store.documents

# Query (run on each user question)
# user_input.output → query_embedding.input
# query_embedding.output → retriever.query
# retriever.output → context_formatter.context
# user_input.output → context_formatter.question
# context_formatter.output → llm.prompt
# llm.output → output.text
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `chunk_size` | 1000 | Characters per chunk (adjust based on doc type) |
| `chunk_overlap` | 200 | Overlap between chunks (maintains context) |
| `k` | 5 | Number of chunks to retrieve |
| `score_threshold` | 0.7 | Minimum similarity score (0.0-1.0) |
| `temperature` | 0.3 | LLM creativity (lower for factual) |
| `max_tokens` | 500 | Maximum response length |

## Example Usage

```python
# Using the RAG chatbot via API
import requests

url = "https://api.langflow.app/api/v1/run/rag-chatbot"
headers = {"Authorization": f"Bearer {LANGFLOW_API_KEY}"}

payload = {
    "inputs": {
        "question": "How do I deploy a Langflow app to production?"
    }
}

response = requests.post(url, json=payload, headers=headers)
result = response.json()

print(result["outputs"]["answer"])
# Output: "To deploy a Langflow app to production, you can use Docker
# or Kubernetes. According to the deployment documentation, the recommended
# approach is... [citation: deployment.md, section 3.2]"
```

## Multi-Query RAG (Advanced)

```python
# Generate multiple query variations for better retrieval
query_rewriter = {
    "type": "ChatOpenAI",
    "model": "gpt-3.5-turbo",
    "temperature": 0.5,
    "prompt": """
Generate 3 variations of this question to improve document retrieval:

Original: {question}

Variations (one per line):"""
}

# Retrieve for each variation
retriever_multi = {
    "search_type": "mmr",  # Maximum Marginal Relevance
    "k": 3,  # 3 results per query
    "fetch_k": 15  # Fetch 15, rerank to 3
}

# Combine and deduplicate results
# Improves recall for ambiguous questions
```

## Hybrid Search

```python
# Combine semantic (vector) and keyword (BM25) search
hybrid_retriever = {
    "type": "WeaviateHybridRetriever",
    "vector_store": weaviate_store,
    "alpha": 0.5,  # 0=keyword, 1=semantic, 0.5=balanced
    "k": 10
}

# Best of both approaches
# Semantic: finds conceptually similar content
# Keyword: finds exact matches
```

## Reranking

```python
# Add reranker to improve result quality
reranker = {
    "type": "CohereRerank",
    "api_key": "${COHERE_API_KEY}",
    "model": "rerank-english-v2.0",
    "top_n": 5  # Select top 5 after reranking
}

# Flow: retriever → reranker → context_formatter
# Reranking improves precision by 15-30%
```

## Citation Tracking

```python
# Add source tracking to responses
citation_template = """
Answer: {answer}

Sources:
{sources}
"""

# Extract sources from retrieved chunks
sources = [
    f"- {chunk.metadata['source']}, page {chunk.metadata['page']}"
    for chunk in retrieved_chunks
]

# Users can verify information
```

## Quality Monitoring

```python
# Track RAG quality metrics
metrics = {
    "retrieval_latency_ms": 150,
    "generation_latency_ms": 800,
    "total_latency_ms": 950,
    "chunks_retrieved": 5,
    "avg_relevance_score": 0.82,
    "answer_length_chars": 450,
    "sources_cited": 2
}

# Monitor for degradation
# Alert if latency > 2s or relevance < 0.7
```

## Common Pitfalls

```python
# ❌ Don't: Too many chunks (context overflow)
retriever.k = 20  # Too much noise

# ✓ Do: Focused retrieval
retriever.k = 5
retriever.score_threshold = 0.7

# ❌ Don't: High temperature for factual queries
llm.temperature = 1.0  # Too creative, may hallucinate

# ✓ Do: Low temperature for accuracy
llm.temperature = 0.3

# ❌ Don't: Poor chunk boundaries
splitter.separator = " "  # Breaks mid-sentence

# ✓ Do: Semantic boundaries
splitter.separators = ["\n\n", "\n", ". "]
```

## See Also

- [vector-stores.md](../concepts/vector-stores.md) - Vector store configuration
- [data-loaders.md](../concepts/data-loaders.md) - Document loading and chunking
- [language-models.md](../concepts/language-models.md) - LLM optimization
- [production-deployment.md](../patterns/production-deployment.md) - Deployment strategies
