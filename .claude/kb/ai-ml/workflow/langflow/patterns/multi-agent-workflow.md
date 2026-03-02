# Multi-Agent Workflow

> **Purpose**: Coordinate multiple specialized agents for complex tasks using agent-as-tool pattern
> **MCP Validated**: 2026-02-06

## When to Use

- Complex tasks requiring multiple specialized capabilities
- Need coordination between research, analysis, and synthesis
- Building autonomous workflows with multiple decision points

## Implementation

```python
# 1. SPECIALIZED AGENTS
research_agent = {
    "type": "ToolCallingAgent", "name": "research_agent", "role": "Researcher",
    "llm": {"model": "gpt-4", "temperature": 0.5},
    "tools": [
        {"name": "web_search", "type": "GoogleSearch", "api_key": "${GOOGLE_API_KEY}"},
        {"name": "scrape_webpage", "type": "WebScraper"},
        {"name": "load_document", "type": "DocumentLoader"}
    ],
    "max_iterations": 5
}

analyst_agent = {
    "type": "ToolCallingAgent", "name": "analyst_agent", "role": "Data Analyst",
    "llm": {"model": "gpt-4", "temperature": 0.3},
    "tools": [
        {"name": "python_repl", "type": "PythonREPL"},
        {"name": "calculator", "type": "Calculator"},
        {"name": "extract_structured_data", "type": "StructuredOutputParser",
         "schema": {"key_findings": "list[str]", "metrics": "dict", "trends": "list[str]"}}
    ],
    "max_iterations": 5
}

writer_agent = {
    "type": "ToolCallingAgent", "name": "writer_agent", "role": "Technical Writer",
    "llm": {"model": "claude-3-5-sonnet-20241022", "temperature": 0.7},
    "tools": [{"name": "format_markdown", "type": "MarkdownFormatter"}, {"name": "generate_summary", "type": "SummarizationTool"}],
    "max_iterations": 3
}

# 2. COORDINATOR (orchestration via agent-as-tool)
coordinator = {
    "type": "ToolCallingAgent", "name": "coordinator", "role": "Project Coordinator",
    "llm": {"model": "gpt-4", "temperature": 0.4},
    "tools": [
        {"name": "research_agent", "agent": research_agent, "description": "Gathers information from web and documents"},
        {"name": "analyst_agent", "agent": analyst_agent, "description": "Analyzes data and extracts insights"},
        {"name": "writer_agent", "agent": writer_agent, "description": "Writes reports and documentation"}
    ],
    "workflow": "sequential", "max_iterations": 10
}

# Flow: user_query → coordinator → [research → analyst → writer] → final_output
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `workflow` | sequential | Execution order (sequential/parallel/hierarchical) |
| `max_iterations` | 10 | Maximum coordinator iterations |
| `early_stopping` | force | Stop behavior (force/partial_results/continue) |
| `agent_timeout` | 30 | Timeout per agent call (seconds) |
| `share_memory` | True | Agents share conversation history |

## Workflow Patterns

```text
SEQUENTIAL: Agent A → Agent B → Agent C (each uses previous output)
PARALLEL:   Agent A ┐
            Agent B ├→ Combine results (independent tasks)
            Agent C ┘
HIERARCHICAL: Coordinator → delegates to specialists → sub-agents
```

## Agent Communication

```python
# Shared memory for cross-agent context
memory = {"type": "ConversationBufferMemory", "shared": True, "return_messages": True}
# Agent A stores findings → Agent B retrieves and builds on them
```

## Error Handling

```python
error_handling = {
    "agent_timeout": {"action": "skip", "fallback": "partial_results"},
    "tool_failure": {"action": "retry", "max_retries": 3, "alternative_tool": "backup_search"},
    "invalid_output": {"action": "request_refinement", "max_attempts": 2}
}
```

## Agent Specialization Examples

```python
sql_agent = {"role": "Database Analyst", "tools": ["sql_executor", "schema_inspector"]}
python_agent = {"role": "Data Scientist", "tools": ["python_repl", "jupyter_notebook"]}
api_agent = {"role": "Integration Specialist", "tools": ["http_request", "auth_manager"]}
```

## Performance Optimization

```python
# Parallel execution for independent agents
import asyncio
async def run_agents_parallel():
    results = await asyncio.gather(
        research_agent.execute(query), analyst_agent.execute(data), writer_agent.execute(context)
    )
    return combine_results(results)
# 3 agents @ 30s each: 90s sequential → 30s parallel
```

## Quality Validation

```python
validator = {
    "role": "Quality Assurance",
    "checks": ["completeness", "accuracy", "coherence", "formatting"],
    "action_on_failure": "request_revision"
}
# Flow: coordinator → [agents] → validator → output
```

## Common Pitfalls

```python
# Wrong                                    # Correct
coordinator.tools = [a1, ..., a10]         # 3-5 specialized agents
agent.max_iterations = None                # agent.max_iterations = 5; agent.timeout = 30
error_handling.on_timeout = "fail"         # error_handling.on_timeout = "return_partial"
```

## See Also

- [agents-tools.md](../concepts/agents-tools.md) - Agent fundamentals
- [mcp-server.md](../concepts/mcp-server.md) - MCP for agent coordination
- [custom-components.md](../patterns/custom-components.md) - Custom agent components
