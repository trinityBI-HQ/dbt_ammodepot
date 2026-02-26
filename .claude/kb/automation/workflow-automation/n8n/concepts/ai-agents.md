# AI Agents and LangChain Integration

> **Purpose**: AI Agent nodes, LLM backends, vector stores, memory, and tool nodes
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

n8n includes 70+ LangChain-backed AI nodes for building agent workflows. The AI Agent node orchestrates LLM calls with tools, memory, and retrieval in a ReAct pattern. Nodes connect as sub-nodes (LLM, memory, tools) attached to root agent nodes.

## Core AI Nodes

| Node | Purpose |
|------|---------|
| **AI Agent** | ReAct agent with tool-calling loop, memory, LLM backbone |
| **Basic LLM Chain** | Single-shot LLM call without tools |
| **Information Extractor** | Structured extraction from text |
| **Text Classifier** | Label classification |
| **Summarization Chain** | Document summarization |
| **Question and Answer Chain** | RAG-based Q&A |

## LLM Backend Sub-Nodes

| Model | Provider |
|-------|----------|
| OpenAI Chat Model | GPT-4o, GPT-4 |
| Anthropic Chat Model | Claude 3.5/3.7/4 series |
| Google Gemini Chat Model | Gemini 1.5, 2.0, 2.5 |
| Ollama Chat Model | Local models (Llama, Mistral) |
| AWS Bedrock Chat Model | Multiple providers via AWS |
| Groq / Mistral / OpenRouter | Alternative providers |

## Memory Sub-Nodes

```javascript
// Memory persists conversation context across executions
AI Agent
  └── Memory: Window Buffer Memory    // In-process, last N messages
  └── Memory: Redis Chat Memory       // Persistent, cross-execution
  └── Memory: Postgres Chat Memory    // Database-backed
  └── Memory: MongoDB Chat Memory     // Document store
```

## Vector Store Nodes (RAG)

| Store | Use Case |
|-------|----------|
| Pinecone | Managed vector DB |
| Qdrant | Self-hosted, high performance |
| Supabase | Postgres-based vectors |
| PGVector | Self-hosted Postgres |
| In-Memory | Development/testing |

## Tool Sub-Nodes

```javascript
// Tools give AI Agent capabilities
AI Agent
  └── Tool: Code Tool          // Run JS/Python as tool
  └── Tool: Workflow Tool      // Expose n8n workflow as tool
  └── Tool: MCP Client Tool   // Connect to external MCP server
  └── Tool: Wikipedia          // Knowledge lookup
  └── Tool: Calculator         // Math operations
  └── Tool: Think Tool         // Extended reasoning step
  └── Tool: Vector Store Tool  // RAG via tool interface
```

## Embedding Sub-Nodes

| Node | Provider |
|------|----------|
| OpenAI Embeddings | text-embedding-3-small/large |
| Google Gemini Embeddings | Gemini embedding models |
| Ollama Embeddings | Local embedding models |
| AWS Bedrock Embeddings | Titan, Cohere via AWS |

## Document Loaders (RAG Pipeline)

Load documents for vector store ingestion: PDF, CSV, JSON, binary files, GitHub repos, web scraper. Combined with text splitters and embeddings to build RAG pipelines.

## MCP Integration

```javascript
// n8n as MCP Client (consume external MCP tools)
AI Agent
  └── Tool: MCP Client Tool
       Server URL: "https://mcp-server.example.com/sse"
       Auth: Bearer token

// n8n as MCP Server (expose workflows as tools)
MCP Server Trigger → workflow logic → response
// External agents (Claude Desktop, etc.) call n8n tools via MCP
```

## Human-in-the-Loop (v2.5+)

```javascript
// Chat node with HITL actions
AI Agent
  → Chat: "Send message and wait for response"
  // Pauses execution, waits for human input

// Tool-level approval gates (v2.6+)
AI Agent
  └── Tool: "Delete Record" [requires_approval: true]
  // Routes approval via Slack/email before tool executes
```

## Common Mistakes

### Wrong
```javascript
// Using Basic LLM Chain for multi-step tasks
Basic LLM Chain → no tools, no memory
// Single-shot only, no agentic behavior
```

### Correct
```javascript
// Use AI Agent for multi-step reasoning
AI Agent
  └── LLM: Anthropic (Claude)
  └── Memory: Window Buffer (last 10 messages)
  └── Tool: Workflow Tool (search database)
  └── Tool: Code Tool (calculate pricing)
// Agent decides which tools to use
```

## Related

- [AI Agent Workflow Patterns](../patterns/ai-agent-workflows.md)
- [Nodes and Workflows](nodes-workflows.md)
- [Webhooks and Triggers](webhooks-triggers.md) (Chat Trigger, MCP Server Trigger)
