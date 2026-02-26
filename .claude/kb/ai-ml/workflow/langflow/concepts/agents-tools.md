# Agents and Tools

> **Purpose**: Autonomous components that use tools to accomplish goals, powered by LangChain
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-06

## Overview

Agents in Langflow are autonomous components that can use tools to accomplish complex tasks. Based on LangChain's agent framework, they decide which tools to use, when to use them, and how to interpret results. Agents support multi-step reasoning, error recovery, and can be combined into multi-agent systems.

## Agent Types

| Type | Reasoning | Use Case |
|------|-----------|----------|
| **OpenAI Functions** | Function calling API | Structured tool selection |
| **Tool Calling** | Native tool use | Latest models with tool support |
| **ReAct** | Reasoning + Acting | Step-by-step problem solving |
| **Conversational** | Memory + tools | Stateful interactions |
| **Custom** | User-defined logic | Domain-specific behavior |

## Agent Structure

```python
# Agent component configuration
agent = {
    "type": "ToolCallingAgent",
    "llm": "gpt-4",  # Backing language model
    "tools": [  # Available tools
        search_tool,
        calculator_tool,
        api_call_tool
    ],
    "max_iterations": 5,  # Prevent infinite loops
    "early_stopping": "force",  # Stop on max iterations
    "verbose": True  # Log reasoning steps
}

# Execution flow
# 1. Agent receives task
# 2. Reasons about which tool to use
# 3. Calls tool with parameters
# 4. Interprets result
# 5. Repeats or returns final answer
```

## Tool Definition

```python
# Built-in tool example
calculator_tool = {
    "name": "calculator",
    "description": "Performs mathematical calculations",
    "parameters": {
        "expression": {
            "type": "string",
            "description": "Math expression to evaluate"
        }
    }
}

# Custom tool example
api_tool = {
    "name": "get_weather",
    "description": "Fetches current weather for a city",
    "function": weather_api_call,
    "parameters": {
        "city": {"type": "string", "required": True}
    }
}
```

## Available Tools

| Category | Tools | Purpose |
|----------|-------|---------|
| **Search** | Google, Bing, DuckDuckGo | Web information retrieval |
| **Data** | SQL, API, File Read | Data access |
| **Compute** | Calculator, Python REPL | Calculations and code |
| **External** | Zapier, IFTTT | Integration with services |
| **Custom** | User-defined | Domain-specific logic |

## Agent Reasoning

```text
# ReAct pattern example
Task: "What's the weather in Paris and convert temp to Celsius?"

Thought: I need to get weather data first
Action: get_weather
Action Input: {"city": "Paris"}
Observation: Temperature is 75°F

Thought: Now I need to convert to Celsius
Action: calculator
Action Input: {"expression": "(75 - 32) * 5/9"}
Observation: 23.89

Thought: I have the final answer
Final Answer: The weather in Paris is 24°C
```

## Multi-Agent Systems

```python
# Create specialized agents
research_agent = {
    "role": "Researcher",
    "tools": [search_tool, scrape_tool],
    "goal": "Gather information on topic"
}

analysis_agent = {
    "role": "Analyst",
    "tools": [calculator_tool, python_tool],
    "goal": "Analyze gathered data"
}

writer_agent = {
    "role": "Writer",
    "tools": [format_tool],
    "goal": "Write summary report"
}

# Coordinate via agent-as-tool pattern
coordinator = {
    "tools": [research_agent, analysis_agent, writer_agent],
    "workflow": "sequential"  # Or parallel, hierarchical
}
```

## Common Mistakes

### Wrong

```python
# No max iterations (risk of infinite loops)
agent.max_iterations = None

# Vague tool descriptions
tool.description = "Does stuff"  # Agent won't know when to use it

# Too many tools (agent gets confused)
agent.tools = [tool1, tool2, ..., tool50]
```

### Correct

```python
# Set reasonable limits
agent.max_iterations = 5
agent.timeout = 30  # seconds

# Clear, specific descriptions
tool.description = "Converts temperature from Fahrenheit to Celsius"

# Focused tool set (3-10 tools optimal)
agent.tools = [search, calculator, api_call]
```

## Agent Memory

```python
# Conversational memory for context
memory = {
    "type": "ConversationBufferMemory",
    "return_messages": True,
    "memory_key": "chat_history"
}

# Agent uses memory for context
agent.memory = memory

# Example conversation
User: "Search for Python tutorials"
Agent: [uses search tool, returns results]
User: "Now filter for beginners"  # Context from previous turn
Agent: [remembers previous results, filters them]
```

## Error Handling

```python
# Agent error recovery strategies
strategies = {
    "retry": {
        "max_retries": 3,
        "backoff": "exponential"
    },
    "fallback": {
        "alternative_tool": "backup_search",
        "simplified_query": True
    },
    "escalation": {
        "notify_human": True,
        "partial_results": True
    }
}
```

## Performance Tuning

| Parameter | Default | Tuning |
|-----------|---------|--------|
| `temperature` | 0.7 | Lower (0.3) for focused, higher for creative |
| `max_iterations` | 15 | 3-5 for simple tasks, 10-15 for complex |
| `tool_count` | Unlimited | 3-10 optimal, 15 maximum |

## Related

- [language-models.md](../concepts/language-models.md) - LLM configuration for agents
- [multi-agent-workflow.md](../patterns/multi-agent-workflow.md) - Multi-agent patterns
- [custom-components.md](../patterns/custom-components.md) - Custom tool creation
