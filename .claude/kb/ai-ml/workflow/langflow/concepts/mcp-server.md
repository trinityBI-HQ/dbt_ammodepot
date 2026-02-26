# MCP Server

> **Purpose**: Model Context Protocol integration for connecting AI apps to external tools and data sources
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

MCP is a first-class citizen in Langflow v1.6+. Langflow functions as both MCP client and server. v1.6 added OAuth authentication for MCP server endpoints. v1.7 replaced SSE transport with **Streamable HTTP** for MCP client and server — connect to any remote MCP server regardless of transport. Flows are exposed as tools callable by external AI applications.

## MCP Architecture

```text
┌─────────────────┐
│   AI Agent      │
│  (Claude, etc)  │
└────────┬────────┘
         │ MCP Client
         ↓
┌─────────────────┐
│ Langflow MCP    │ ← /api/v1/mcp/sse
│     Server      │
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│  Langflow Flow  │ → Execute as tool
└─────────────────┘
```

## MCP Server Configuration

```python
# Enable MCP server in Langflow
mcp_config = {
    "enabled": True,
    "endpoint": "/api/v1/mcp/sse",
    "transport": "sse",  # Server-Sent Events
    "authentication": "api_key",
    "expose_flows": True  # Make all flows available as tools
}

# Each flow automatically becomes an MCP tool
# Tool name: flow_name
# Tool description: flow_description
# Tool parameters: flow_inputs
```

## Flow as MCP Tool

```python
# Langflow flow configuration
flow_config = {
    "name": "document_qa",
    "description": "Answer questions about uploaded documents using RAG",
    "inputs": {
        "document_url": {
            "type": "string",
            "description": "URL of the document to analyze"
        },
        "question": {
            "type": "string",
            "description": "Question to answer about the document"
        }
    },
    "outputs": {
        "answer": {
            "type": "string",
            "description": "Answer to the question"
        }
    }
}

# Exposed as MCP tool:
# Tool: document_qa
# Parameters: document_url (string), question (string)
# Returns: answer (string)
```

## MCP Client Usage

```python
# Connect to Langflow MCP server
from mcp import MCPClient

client = MCPClient(
    url="https://langflow.example.com/api/v1/mcp/sse",
    api_key="your-api-key"
)

# Discover available tools
tools = client.list_tools()
# Returns: [document_qa, summarize_text, analyze_sentiment, ...]

# Call a Langflow flow as a tool
result = client.call_tool(
    tool_name="document_qa",
    parameters={
        "document_url": "https://example.com/doc.pdf",
        "question": "What is the main topic?"
    }
)

print(result["answer"])
```

## MCP Tool Definition

```json
{
  "name": "document_qa",
  "description": "Answer questions about uploaded documents using RAG",
  "inputSchema": {
    "type": "object",
    "properties": {
      "document_url": {
        "type": "string",
        "description": "URL of the document to analyze"
      },
      "question": {
        "type": "string",
        "description": "Question to answer about the document"
      }
    },
    "required": ["document_url", "question"]
  }
}
```

## Server-Sent Events (SSE)

```python
# SSE transport for streaming responses
# Client maintains persistent connection
# Server pushes updates in real-time

# Example SSE response
event: tool_result
data: {"status": "processing", "progress": 0.3}

event: tool_result
data: {"status": "processing", "progress": 0.7}

event: tool_result
data: {"status": "complete", "answer": "The main topic is..."}
```

## Use Cases

| Use Case | Description |
|----------|-------------|
| **AI Agent Tools** | Expose Langflow flows as tools for Claude/GPT agents |
| **Cross-App Integration** | Connect multiple AI apps via MCP |
| **Workflow Orchestration** | Chain Langflow flows with other MCP services |
| **Custom Functions** | Provide domain-specific capabilities to LLMs |

## MCP with Claude Desktop

```json
// claude_desktop_config.json
{
  "mcpServers": {
    "langflow": {
      "command": "npx",
      "args": [
        "-y",
        "@anthropic/mcp-server-langflow",
        "--url",
        "https://langflow.example.com/api/v1/mcp/sse",
        "--api-key",
        "your-api-key"
      ]
    }
  }
}

// Claude can now use Langflow flows as tools
```

## Authentication

```python
# API key authentication for MCP
headers = {
    "Authorization": f"Bearer {LANGFLOW_API_KEY}"
}

# Connect to MCP endpoint
client = MCPClient(
    url="https://langflow.example.com/api/v1/mcp/sse",
    headers=headers
)
```

## Common Mistakes

### Wrong

```python
# No tool descriptions
flow.description = ""  # Agent won't know when to use it

# Vague parameter names
flow.inputs = {"input1": str}  # Unclear purpose

# No error handling
# Flow crashes without returning error to MCP client
```

### Correct

```python
# Clear descriptions
flow.description = "Analyze customer feedback sentiment and extract key themes"

# Descriptive parameters
flow.inputs = {
    "feedback_text": "Customer feedback to analyze",
    "language": "Language code (en, es, fr, etc.)"
}

# Proper error handling
try:
    result = execute_flow(inputs)
    return {"status": "success", "result": result}
except Exception as e:
    return {"status": "error", "error": str(e)}
```

## Tool Discovery

```python
# List all available Langflow tools
tools = client.list_tools()

for tool in tools:
    print(f"Tool: {tool['name']}")
    print(f"Description: {tool['description']}")
    print(f"Parameters: {tool['inputSchema']}")
    print("---")

# Example output:
# Tool: document_qa
# Description: Answer questions about uploaded documents using RAG
# Parameters: {"document_url": "string", "question": "string"}
```

## Performance Considerations

```python
# SSE connection pooling
max_connections = 100
timeout = 300  # 5 minutes

# Async execution for multiple tools
import asyncio

async def call_multiple_tools():
    results = await asyncio.gather(
        client.call_tool("tool1", params1),
        client.call_tool("tool2", params2),
        client.call_tool("tool3", params3)
    )
    return results
```

## Related

- [api-deployment.md](../concepts/api-deployment.md) - API fundamentals
- [agents-tools.md](../concepts/agents-tools.md) - Tool usage in agents
- [multi-agent-workflow.md](../patterns/multi-agent-workflow.md) - Multi-agent coordination
