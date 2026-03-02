# Agents and Tools

> **Purpose**: Autonomous components that use tools to accomplish goals, powered by LangChain
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-06

## Overview

Agents in Langflow are autonomous components that use tools to accomplish complex tasks. Based on LangChain's agent framework, they decide which tools to use, when, and how to interpret results. Agents support multi-step reasoning, error recovery, and multi-agent systems.

## Agent Types

| Type | Reasoning | Use Case |
|------|-----------|----------|
| **OpenAI Functions** | Function calling API | Structured tool selection |
| **Tool Calling** | Native tool use | Latest models with tool support |
| **ReAct** | Reasoning + Acting | Step-by-step problem solving |
| **Conversational** | Memory + tools | Stateful interactions |
| **Custom** | User-defined logic | Domain-specific behavior |

## Agent Configuration

```python
agent = {
    "type": "ToolCallingAgent", "llm": "gpt-4",
    "tools": [search_tool, calculator_tool, api_call_tool],
    "max_iterations": 5, "early_stopping": "force", "verbose": True
}
# Flow: receive task → reason → call tool → interpret → repeat or return
```

## Tool Definition

```python
calculator_tool = {
    "name": "calculator", "description": "Performs mathematical calculations",
    "parameters": {"expression": {"type": "string", "description": "Math expression to evaluate"}}
}

api_tool = {
    "name": "get_weather", "description": "Fetches current weather for a city",
    "function": weather_api_call, "parameters": {"city": {"type": "string", "required": True}}
}
```

## Available Tools

| Category | Tools | Purpose |
|----------|-------|---------|
| **Search** | Google, Bing, DuckDuckGo | Web information retrieval |
| **Data** | SQL, API, File Read | Data access |
| **Compute** | Calculator, Python REPL | Calculations and code |
| **External** | Zapier, IFTTT | Service integration |
| **Custom** | User-defined | Domain-specific logic |

## ReAct Reasoning Example

```text
Task: "What's the weather in Paris and convert temp to Celsius?"
Thought: I need weather data → Action: get_weather(Paris) → Obs: 75F
Thought: Convert to Celsius → Action: calculator((75-32)*5/9) → Obs: 23.89
Final Answer: The weather in Paris is 24C
```

## Multi-Agent Systems

```python
research_agent = {"role": "Researcher", "tools": [search_tool, scrape_tool]}
analysis_agent = {"role": "Analyst", "tools": [calculator_tool, python_tool]}
writer_agent = {"role": "Writer", "tools": [format_tool]}

coordinator = {
    "tools": [research_agent, analysis_agent, writer_agent],
    "workflow": "sequential"  # Or parallel, hierarchical
}
```

## Common Mistakes

```python
# Wrong: no limits, vague descriptions, too many tools
agent.max_iterations = None
tool.description = "Does stuff"
agent.tools = [tool1, tool2, ..., tool50]

# Correct: limits set, clear descriptions, focused toolset (3-10)
agent.max_iterations = 5
agent.timeout = 30
tool.description = "Converts temperature from Fahrenheit to Celsius"
agent.tools = [search, calculator, api_call]
```

## Agent Memory

```python
memory = {"type": "ConversationBufferMemory", "return_messages": True, "memory_key": "chat_history"}
agent.memory = memory
# Enables context across turns: "Search Python tutorials" → "Now filter for beginners"
```

## Error Handling & Performance

```python
strategies = {
    "retry": {"max_retries": 3, "backoff": "exponential"},
    "fallback": {"alternative_tool": "backup_search"},
    "escalation": {"notify_human": True, "partial_results": True}
}
```

| Parameter | Default | Tuning |
|-----------|---------|--------|
| `temperature` | 0.7 | Lower (0.3) for focused, higher for creative |
| `max_iterations` | 15 | 3-5 simple, 10-15 complex |
| `tool_count` | Unlimited | 3-10 optimal, 15 max |

## Related

- [language-models.md](../concepts/language-models.md) - LLM configuration for agents
- [multi-agent-workflow.md](../patterns/multi-agent-workflow.md) - Multi-agent patterns
- [custom-components.md](../patterns/custom-components.md) - Custom tool creation
