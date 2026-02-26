# Traces and Spans

> **Purpose**: Hierarchical structure for observability data in Langfuse v3
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

A trace represents a single request or operation in your LLM application. Traces contain observations (spans, generations, events, agents, tools, and more) that form a hierarchical tree showing the execution flow. Sessions optionally group multiple traces together, useful for multi-turn conversations.

Langfuse v3 introduced **Agent Graphs** (GA Nov 2025), which visualize the real execution flow of complex agents -- showing branching, loops, and tool calls as an interactive graph rather than a flat list.

## Observation Types (v3)

| Type | Description | Use Case |
|------|-------------|----------|
| `span` | Generic observation | Function calls, I/O operations |
| `generation` | LLM-specific span | Model calls with tokens/cost |
| `event` | Point-in-time marker | Logging discrete events |
| `agent` | Agent execution step | Agent graph visualization |
| `tool` | Tool invocation | Function/API calls from agents |
| `chain` | Processing chain | Sequential pipeline steps |
| `retriever` | RAG document fetch | Retrieval operations |
| `embedding` | Vector generation | Embedding model calls |
| `guardrail` | Safety validation | Input/output checks |

## The Pattern

```python
from langfuse import get_client

langfuse = get_client()

# Create a trace with context manager
with langfuse.start_as_current_observation(
    as_type="span",
    name="process-invoice",
    user_id="user-123",
    session_id="session-456",
    metadata={"source": "cloud-run"}
) as root_span:

    # Nested span for preprocessing
    with langfuse.start_as_current_observation(
        as_type="span",
        name="preprocess"
    ) as preprocess_span:
        preprocess_span.update(output="Preprocessed invoice image")

    # Nested generation for LLM call
    with langfuse.start_as_current_observation(
        as_type="generation",
        name="extract-fields",
        model="gemini-1.5-pro"
    ) as gen:
        gen.update(output={"vendor": "UberEats", "total": 42.50})

    root_span.update(output="Invoice processed successfully")
```

## Agent Graphs (v3)

Agent graphs automatically visualize complex agent execution flows. Use the `agent` and `tool` observation types to generate interactive graph views in the Langfuse UI.

```python
# Agent with tool calls -- renders as graph in UI
with langfuse.start_as_current_observation(
    as_type="agent",
    name="invoice-agent"
) as agent:
    with langfuse.start_as_current_observation(
        as_type="tool",
        name="fetch-invoice-image"
    ) as tool:
        tool.update(output={"bytes": 1024})

    with langfuse.start_as_current_observation(
        as_type="generation",
        name="extract-fields",
        model="gemini-1.5-pro"
    ) as gen:
        gen.update(output={"vendor": "Acme"})
```

## Common Mistakes

### Wrong

```python
# Creating orphan spans without context
span = langfuse.start_span(name="my-span")
# Forgetting to end it or losing the hierarchy
```

### Correct

```python
# Using context manager ensures proper hierarchy and cleanup
with langfuse.start_as_current_observation(
    as_type="span",
    name="my-span"
) as span:
    # Automatic parent-child relationship
    # Automatic end() on exit
    span.update(output="Done")
```

## Key Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `trace_id` | string | Unique identifier for the trace |
| `user_id` | string | End-user identifier |
| `session_id` | string | Groups related traces |
| `metadata` | dict | Custom key-value pairs |
| `input` | any | Operation input data |
| `output` | any | Operation output data |

## Related

- [Generations](../concepts/generations.md)
- [Python SDK Integration](../patterns/python-sdk-integration.md)
- [Trace Linking](../patterns/trace-linking.md)
