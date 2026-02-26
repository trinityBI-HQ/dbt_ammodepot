# Langflow Quick Reference

> Fast lookup tables. For code examples, see linked files.

## Component Types

| Category | Components | Purpose |
|----------|-----------|---------|
| **Models** | OpenAI, Anthropic, Google, Ollama | LLM text generation |
| **Vector Stores** | Pinecone, Weaviate, Chroma, FAISS | Embedding storage/retrieval |
| **Agents** | OpenAI Agent, Tool Calling Agent | Autonomous task execution |
| **Data Loaders** | File, Web, PDF, API | Document ingestion |
| **Text Processing** | Text Splitter, Embeddings | Chunking and vectorization |
| **Tools** | Calculator, Search, API Call, Python | Agent capabilities |
| **Chains** | LLMChain, ConversationalChain | Multi-step workflows |

## Common Flow Patterns

| Pattern | Components Needed | Use Case |
|---------|-------------------|----------|
| **Simple Chatbot** | LLM + Prompt Template | Basic Q&A |
| **RAG Chatbot** | LLM + Vector Store + Embeddings + Loader | Context-aware chat |
| **Multi-Query RAG** | Multiple LLMs + Vector Store + Reranker | Advanced retrieval |
| **Agent with Tools** | Agent + Tools + LLM | Task automation |
| **Multi-Agent** | Multiple Agents + Coordinator | Complex workflows |

## Installation & Setup

| Method | Command | Use Case |
|--------|---------|----------|
| **pip** | `pip install langflow` | Quick local setup |
| **Docker** | `docker run -p 7860:7860 langflowai/langflow` | Isolated environment |
| **From source** | `git clone && cd langflow && make install` | Development |

## API Usage

| Operation | Endpoint | Method |
|-----------|----------|--------|
| Run flow | `/api/v1/run/{flow_id}` | POST |
| Get flow | `/api/v1/flows/{flow_id}` | GET |
| List flows | `/api/v1/flows` | GET |
| MCP server | `/api/v1/mcp/sse` | SSE |

## Deployment Options

| Platform | Method | Best For |
|----------|--------|----------|
| **Local** | `langflow run` | Development/prototyping |
| **Docker** | Docker Compose | Single-server deployment |
| **Kubernetes** | Helm charts | Production/scaling |
| **Cloud** | Langflow Cloud | Managed service |

## Vector Store Configuration

| Store | Key Parameters | Notes |
|-------|----------------|-------|
| **Pinecone** | `api_key`, `index_name`, `environment` | Managed, scalable |
| **Weaviate** | `url`, `api_key`, `index_name` | Open source option |
| **Chroma** | `persist_directory` | Local, no API key |
| **FAISS** | `index_path` | Local, fast similarity |

## Decision Matrix

| Use Case | Choose |
|----------|--------|
| Build RAG chatbot quickly | Use Vector RAG template |
| Need custom logic | Create custom components |
| Production API | Deploy with Docker + API auth |
| Multi-agent coordination | Use agent-as-tool pattern |
| Local LLMs | Use Ollama integration |

## Common Pitfalls

| Don't | Do |
|-------|-----|
| Hardcode API keys in flows | Use environment variables |
| Skip chunking strategy | Test chunk size/overlap for your data |
| Ignore error handling | Add fallback components |
| Deploy without rate limits | Configure API throttling |
| Use large docs without splitting | Use Text Splitter component |

## Related Documentation

| Topic | Path |
|-------|------|
| Getting Started | `concepts/flows-components.md` |
| RAG Patterns | `patterns/vector-rag-chatbot.md` |
| Agent Design | `concepts/agents-tools.md` |
| Full Index | `index.md` |
