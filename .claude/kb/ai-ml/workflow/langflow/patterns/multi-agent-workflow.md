# Multi-Agent Workflow

> **Purpose**: Coordinate multiple specialized agents for complex tasks using agent-as-tool pattern
> **MCP Validated**: 2026-02-06

## When to Use

- Complex tasks requiring multiple specialized capabilities
- Need coordination between research, analysis, and synthesis
- Building autonomous workflows with multiple decision points
- Implementing expert systems with domain-specific agents

## Implementation

```python
# Multi-agent system for deep research

# 1. RESEARCH AGENT (information gathering)
research_agent = {
    "type": "ToolCallingAgent",
    "name": "research_agent",
    "role": "Researcher",
    "goal": "Gather comprehensive information on the topic",
    "llm": {
        "model": "gpt-4",
        "temperature": 0.5
    },
    "tools": [
        {
            "name": "web_search",
            "type": "GoogleSearch",
            "api_key": "${GOOGLE_API_KEY}"
        },
        {
            "name": "scrape_webpage",
            "type": "WebScraper",
            "css_selector": ".content"
        },
        {
            "name": "load_document",
            "type": "DocumentLoader",
            "supported_types": ["pdf", "docx", "txt"]
        }
    ],
    "max_iterations": 5,
    "output_format": "markdown"
}


# 2. ANALYST AGENT (data analysis)
analyst_agent = {
    "type": "ToolCallingAgent",
    "name": "analyst_agent",
    "role": "Data Analyst",
    "goal": "Analyze gathered information and extract key insights",
    "llm": {
        "model": "gpt-4",
        "temperature": 0.3  # More focused for analysis
    },
    "tools": [
        {
            "name": "python_repl",
            "type": "PythonREPL",
            "globals": {"pandas": "pd", "numpy": "np"}
        },
        {
            "name": "calculator",
            "type": "Calculator"
        },
        {
            "name": "extract_structured_data",
            "type": "StructuredOutputParser",
            "schema": {
                "key_findings": "list[str]",
                "metrics": "dict",
                "trends": "list[str]"
            }
        }
    ],
    "max_iterations": 5,
    "output_format": "json"
}


# 3. WRITER AGENT (content generation)
writer_agent = {
    "type": "ToolCallingAgent",
    "name": "writer_agent",
    "role": "Technical Writer",
    "goal": "Synthesize research and analysis into clear documentation",
    "llm": {
        "model": "claude-3-5-sonnet-20241022",
        "temperature": 0.7  # More creative for writing
    },
    "tools": [
        {
            "name": "format_markdown",
            "type": "MarkdownFormatter",
            "include_toc": True
        },
        {
            "name": "generate_summary",
            "type": "SummarizationTool",
            "max_length": 500
        },
        {
            "name": "create_visualizations",
            "type": "ChartGenerator",
            "output_format": "png"
        }
    ],
    "max_iterations": 3,
    "output_format": "markdown"
}


# 4. COORDINATOR AGENT (orchestration)
coordinator_agent = {
    "type": "ToolCallingAgent",
    "name": "coordinator",
    "role": "Project Coordinator",
    "goal": "Orchestrate agents to complete the research task",
    "llm": {
        "model": "gpt-4",
        "temperature": 0.4
    },
    "tools": [
        {
            "name": "research_agent",
            "agent": research_agent,
            "description": "Gathers information from web, documents, and databases"
        },
        {
            "name": "analyst_agent",
            "agent": analyst_agent,
            "description": "Analyzes data and extracts key insights"
        },
        {
            "name": "writer_agent",
            "agent": writer_agent,
            "description": "Writes comprehensive reports and documentation"
        }
    ],
    "workflow": "sequential",  # Or parallel, hierarchical
    "max_iterations": 10,
    "early_stopping": "partial_results"
}


# 5. WORKFLOW EXECUTION

# User input
user_query = {
    "type": "TextInput",
    "placeholder": "Enter your research topic..."
}

# Coordinator decides which agents to use and in what order
# Example execution:
# 1. Call research_agent to gather information
# 2. Call analyst_agent to analyze findings
# 3. Call writer_agent to create report
# 4. Return final output

# Output
final_output = {
    "type": "TextOutput",
    "format": "markdown"
}

# Flow: user_query → coordinator → [research, analyst, writer] → final_output
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `workflow` | sequential | Agent execution order (sequential/parallel/hierarchical) |
| `max_iterations` | 10 | Maximum coordinator iterations |
| `early_stopping` | force | Stop behavior (force/partial_results/continue) |
| `agent_timeout` | 30 | Timeout per agent call (seconds) |
| `share_memory` | True | Agents share conversation history |

## Example Usage

```python
# Execute multi-agent research workflow
import requests

url = "https://api.langflow.app/api/v1/run/multi-agent-research"
headers = {"Authorization": f"Bearer {LANGFLOW_API_KEY}"}

payload = {
    "inputs": {
        "topic": "Latest developments in LLM fine-tuning for code generation"
    },
    "tweaks": {
        "workflow": "sequential",
        "max_depth": 3  # Research depth
    }
}

response = requests.post(url, json=payload, headers=headers)
result = response.json()

print(result["outputs"]["report"])
# Output: Comprehensive research report with:
# - Executive summary
# - Key findings from web sources
# - Statistical analysis
# - Recommendations
# - Citations
```

## Workflow Patterns

```python
# SEQUENTIAL WORKFLOW
# Agent A → Agent B → Agent C
# Each agent uses previous output
# Good for: Linear processes (research → analyze → write)

# PARALLEL WORKFLOW
# Agent A ┐
# Agent B ├→ Combine results
# Agent C ┘
# Agents run simultaneously
# Good for: Independent tasks (fetch from multiple sources)

# HIERARCHICAL WORKFLOW
#    Coordinator
#    ↙    ↓    ↘
# Agent1 Agent2 Agent3
#         ↓
#      Sub-Agent
# Coordinator delegates to specialists
# Good for: Complex decision trees
```

## Agent Communication

```python
# Shared memory for context
memory = {
    "type": "ConversationBufferMemory",
    "shared": True,  # All agents access same memory
    "return_messages": True
}

# Agent A stores findings
memory.save_context(
    {"input": "Research topic X"},
    {"output": "Found 10 papers on X..."}
)

# Agent B retrieves context
context = memory.load_memory_variables({})
# Agent B can reference Agent A's findings
```

## Error Handling

```python
# Graceful degradation strategy
error_handling = {
    "agent_timeout": {
        "action": "skip",
        "fallback": "partial_results",
        "notify": True
    },
    "tool_failure": {
        "action": "retry",
        "max_retries": 3,
        "alternative_tool": "backup_search"
    },
    "invalid_output": {
        "action": "request_refinement",
        "max_attempts": 2,
        "default": "error_message"
    }
}
```

## Agent Specialization

```python
# Create domain-specific agents

# SQL Agent (database queries)
sql_agent = {
    "role": "Database Analyst",
    "tools": ["sql_executor", "schema_inspector"],
    "system_prompt": "Expert in SQL and database optimization"
}

# Python Agent (code execution)
python_agent = {
    "role": "Data Scientist",
    "tools": ["python_repl", "jupyter_notebook"],
    "system_prompt": "Expert in Python, pandas, and data analysis"
}

# API Agent (external integrations)
api_agent = {
    "role": "Integration Specialist",
    "tools": ["http_request", "auth_manager"],
    "system_prompt": "Expert in REST APIs and data integration"
}
```

## Performance Optimization

```python
# Parallel execution for independent agents
import asyncio

async def run_agents_parallel():
    tasks = [
        research_agent.execute(query),
        analyst_agent.execute(data),
        writer_agent.execute(context)
    ]
    results = await asyncio.gather(*tasks)
    return combine_results(results)

# Reduces total execution time
# 3 agents @ 30s each: 90s sequential → 30s parallel
```

## Quality Validation

```python
# Validator agent checks output quality
validator_agent = {
    "role": "Quality Assurance",
    "checks": [
        "completeness",  # All required sections present
        "accuracy",  # Facts verified against sources
        "coherence",  # Logical flow
        "formatting"  # Proper structure
    ],
    "action_on_failure": "request_revision"
}

# Flow: coordinator → [agents] → validator → output
```

## Common Pitfalls

```python
# ❌ Don't: Too many agents (coordination overhead)
coordinator.tools = [agent1, agent2, ..., agent10]  # Hard to coordinate

# ✓ Do: 3-5 specialized agents
coordinator.tools = [research, analyst, writer]

# ❌ Don't: No timeout limits
agent.max_iterations = None  # Can run forever

# ✓ Do: Set reasonable limits
agent.max_iterations = 5
agent.timeout = 30

# ❌ Don't: Ignore partial results
error_handling.on_timeout = "fail"  # Lose all work

# ✓ Do: Save partial progress
error_handling.on_timeout = "return_partial"
```

## See Also

- [agents-tools.md](../concepts/agents-tools.md) - Agent fundamentals
- [mcp-server.md](../concepts/mcp-server.md) - MCP for agent coordination
- [custom-components.md](../patterns/custom-components.md) - Custom agent components
