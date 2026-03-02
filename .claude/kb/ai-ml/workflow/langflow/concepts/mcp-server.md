# MCP Server

> **Purpose**: Model Context Protocol integration for connecting AI apps to external tools and data sources
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

MCP is a first-class citizen in Langflow v1.6+. Langflow functions as both MCP client and server. v1.6 added OAuth authentication for MCP server endpoints. v1.7 replaced SSE transport with **Streamable HTTP** for MCP client and server. Flows are exposed as tools callable by external AI applications.

## MCP Architecture

```text
AI Agent (Claude, etc) → MCP Client → Langflow MCP Server (/api/v1/mcp/sse) → Langflow Flow (execute as tool)
```

## MCP Server Configuration

```python
mcp_config = {
    "enabled": True, "endpoint": "/api/v1/mcp/sse", "transport": "sse",
    "authentication": "api_key", "expose_flows": True
}
# Each flow becomes an MCP tool: name=flow_name, description=flow_description, params=flow_inputs
```

## Flow as MCP Tool

```python
flow_config = {
    "name": "document_qa",
    "description": "Answer questions about uploaded documents using RAG",
    "inputs": {"document_url": {"type": "string"}, "question": {"type": "string"}},
    "outputs": {"answer": {"type": "string"}}
}
# Exposed as: Tool: document_qa(document_url, question) → answer
```

## MCP Client Usage

```python
from mcp import MCPClient
client = MCPClient(url="https://langflow.example.com/api/v1/mcp/sse", api_key="your-api-key")

tools = client.list_tools()  # Discover available tools
result = client.call_tool("document_qa", parameters={"document_url": "https://example.com/doc.pdf", "question": "What is the main topic?"})
```

## Use Cases

| Use Case | Description |
|----------|-------------|
| **AI Agent Tools** | Expose flows as tools for Claude/GPT agents |
| **Cross-App Integration** | Connect multiple AI apps via MCP |
| **Workflow Orchestration** | Chain flows with other MCP services |
| **Custom Functions** | Provide domain-specific capabilities to LLMs |

## MCP with Claude Desktop

```json
{
  "mcpServers": {
    "langflow": {
      "command": "npx",
      "args": ["-y", "@anthropic/mcp-server-langflow", "--url", "https://langflow.example.com/api/v1/mcp/sse", "--api-key", "your-api-key"]
    }
  }
}
```

## Authentication

```python
headers = {"Authorization": f"Bearer {LANGFLOW_API_KEY}"}
client = MCPClient(url="https://langflow.example.com/api/v1/mcp/sse", headers=headers)
```

## Common Mistakes

```python
# Wrong: no descriptions, vague params, no error handling
flow.description = ""
flow.inputs = {"input1": str}

# Correct: clear descriptions, descriptive params, error handling
flow.description = "Analyze customer feedback sentiment and extract key themes"
flow.inputs = {"feedback_text": "Customer feedback to analyze", "language": "Language code (en, es, fr)"}
try:
    result = execute_flow(inputs)
    return {"status": "success", "result": result}
except Exception as e:
    return {"status": "error", "error": str(e)}
```

## Performance Considerations

```python
# Async execution for multiple tools
import asyncio
async def call_multiple_tools():
    results = await asyncio.gather(
        client.call_tool("tool1", params1),
        client.call_tool("tool2", params2)
    )
    return results
```

## Related

- [api-deployment.md](../concepts/api-deployment.md) - API fundamentals
- [agents-tools.md](../concepts/agents-tools.md) - Tool usage in agents
- [multi-agent-workflow.md](../patterns/multi-agent-workflow.md) - Multi-agent coordination
