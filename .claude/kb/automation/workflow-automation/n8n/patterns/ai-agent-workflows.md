# AI Agent Workflow Patterns

> **Purpose**: AI agent orchestration, MCP integration, RAG pipelines, and human-in-the-loop patterns
> **MCP Validated**: 2026-02-19

## When to Use

- Building AI-powered chatbots or assistants
- Orchestrating multi-tool AI agents
- Integrating n8n with MCP-compatible AI systems
- Implementing RAG (retrieval-augmented generation) pipelines
- Adding human review gates to AI workflows

## Pattern 1: Chat-Based AI Assistant

```javascript
Chat Trigger: /ai-assistant
  → AI Agent
    └── LLM: Anthropic Chat Model (Claude 3.5 Sonnet)
    └── Memory: Postgres Chat Memory (session-based)
    └── Tool: Workflow Tool ("Search Knowledge Base")
    └── Tool: Workflow Tool ("Create Ticket")
    └── Tool: Code Tool ("Format Response")
  → Respond to Chat

// Chat Trigger provides a hosted chat interface
// Memory persists across messages in same session
```

## Pattern 2: RAG Pipeline

```javascript
// Step 1: Ingest documents into vector store
Manual Trigger
  → Google Drive: List new files
  → Loop: For each file
    → Download file
    → Default Data Loader (PDF/CSV/JSON)
    → Recursive Text Splitter (chunk_size: 1000, overlap: 200)
    → OpenAI Embeddings
    → Pinecone Vector Store: Insert

// Step 2: Query with AI Agent
Chat Trigger
  → AI Agent
    └── LLM: OpenAI Chat Model (GPT-4o)
    └── Tool: Vector Store Tool (Pinecone)
    └── Memory: Window Buffer Memory
  → Respond to Chat
```

## Pattern 3: MCP Server (Expose n8n as Tools)

```javascript
// Expose n8n workflow as MCP tool for external AI agents
MCP Server Trigger
  Tool Name: "lookup_customer"
  Description: "Look up customer by email"
  Input Schema: { "email": "string" }
  → Database: Query customers WHERE email = {{ $json.email }}
  → Return customer data

// Claude Desktop / other MCP clients can now call this tool
// Multiple MCP Server Trigger workflows = multiple tools
```

## Pattern 4: MCP Client (Consume External Tools)

```javascript
// AI Agent uses external MCP servers as tools
AI Agent
  └── LLM: Anthropic Chat Model
  └── Tool: MCP Client Tool
       Server URL: "https://github-mcp.example.com/sse"
       // Exposes all tools from the MCP server
  └── Tool: MCP Client Tool
       Server URL: "https://db-mcp.example.com/sse"
  └── Memory: Redis Chat Memory
```

## Pattern 5: Human-in-the-Loop Review

```javascript
// AI processes data, human reviews before action
Webhook: /process-invoice
  → Information Extractor
    └── LLM: Google Gemini Chat Model
    Schema: { vendor, amount, date, line_items }
  → IF: amount > 10000
    → [YES] → Chat: "Review high-value invoice"
      // Human reviews, approves or rejects
      → IF: approved → Database: Insert
      → ELSE: → Slack: "Invoice rejected"
    → [NO] → Database: Insert (auto-approve)
```

## Pattern 6: Multi-Agent Orchestration

```javascript
// Coordinator agent delegates to specialist sub-workflows
Chat Trigger
  → AI Agent (Coordinator)
    └── LLM: Anthropic Chat Model
    └── Tool: Workflow Tool ("Research Agent")
    └── Tool: Workflow Tool ("Writing Agent")
    └── Tool: Workflow Tool ("Code Agent")
    └── Memory: Postgres Chat Memory

// Research Agent (sub-workflow)
Execute Workflow Trigger
  → AI Agent
    └── LLM: OpenAI Chat Model
    └── Tool: Wikipedia
    └── Tool: Code Tool (web scraper)
  → Return results

// Each specialist has its own LLM, tools, and context
```

## Pattern 7: Structured Extraction Pipeline

```javascript
Webhook: /extract-data
  → Information Extractor
    └── LLM: Google Gemini Chat Model
    Output Schema:
      company_name: string
      invoice_number: string
      total_amount: number
      line_items: array
  → Code: Validate extraction
    if (!$json.output.invoice_number) throw new Error('Missing invoice');
  → Database: Upsert extracted data
  → Respond: 200 OK
```

## Best Practices

1. **Choose the right root node** — AI Agent for multi-step, Basic LLM Chain for single-shot
2. **Use Workflow Tool** — Expose existing workflows as agent tools for modularity
3. **Add memory for conversations** — Redis/Postgres for production, Window Buffer for dev
4. **Set token limits** — Prevent runaway costs with max token settings
5. **Gate destructive tools** — Use HITL approval for delete/send/payment tools
6. **Monitor with Insights** — Track execution count, success rate, token usage
7. **Use Think Tool** — Add chain-of-thought reasoning steps for complex decisions
8. **Version workflows** — Use Save/Publish to test AI workflows before going live

## AI Workflow Builder

n8n includes an AI-powered workflow builder (v2.9+) that generates entire workflow graphs from natural language. Use it for rapid prototyping, then refine manually.

## See Also

- [AI Agents Concept](../concepts/ai-agents.md)
- [Common Workflows Pattern](common-workflows.md)
- [Error Recovery Pattern](error-recovery.md)
