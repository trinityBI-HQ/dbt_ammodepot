# Flows and Components

> **Purpose**: Core building blocks of Langflow - flows are DAGs, components are nodes
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-06

## Overview

Flows are functional representations of AI application workflows in Langflow. When a flow runs, Langflow builds a Directed Acyclic Graph (DAG) from nodes (components) and edges (connections), executing components sequentially based on dependencies. Each component represents a single step like an LLM call, vector store query, or data transformation.

## Flow Structure

```python
# Flow execution order (automatic DAG resolution)
# 1. Load document (no dependencies)
# 2. Split text (depends on loader)
# 3. Create embeddings (depends on splitter)
# 4. Store in vector DB (depends on embeddings)
# 5. Retrieve context (depends on vector store + user query)
# 6. Generate response (depends on retrieval + LLM)

# Components execute when all inputs are available
# Results pass to dependent components automatically
```

## Component Types

| Type | Purpose | Examples |
|------|---------|----------|
| **Input** | Entry points for data | Text Input, File Upload, API Call |
| **Processing** | Transform data | Text Splitter, Embeddings, Parser |
| **Storage** | Persist data | Vector Store, Memory, Cache |
| **Models** | AI inference | OpenAI, Anthropic, Ollama |
| **Agents** | Autonomous execution | Tool Calling Agent, ReAct Agent |
| **Output** | Return results | Text Output, API Response, Chat |

## Component Connections

```yaml
# Edge definition (visual connection)
source_component: "document_loader"
source_output: "documents"
target_component: "text_splitter"
target_input: "documents"

# Data flows from source output to target input
# Type validation ensures compatibility
```

## Component Grouping

```python
# Group related components into reusable units
# Example: RAG retrieval group
components:
  - vector_store: "Pinecone"
  - embeddings: "OpenAI Embeddings"
  - retriever: "Vector Store Retriever"

# Save as custom component for reuse
# Reduces flow complexity
```

## Flow Parameters

| Parameter | Purpose | Example |
|-----------|---------|---------|
| `name` | Flow identifier | "customer-support-rag" |
| `description` | Flow purpose | "RAG chatbot for docs" |
| `inputs` | External parameters | API keys, model names |
| `outputs` | Return values | Chat response, metadata |

## Common Mistakes

### Wrong

```python
# Circular dependencies (not allowed in DAG)
component_a → component_b → component_c → component_a

# Missing required inputs
llm_component.prompt = None  # Will fail at runtime
```

### Correct

```python
# Linear or branching DAG
input → process_a → output
     → process_b → output

# All required inputs provided
llm_component.prompt = prompt_template.output
llm_component.model = "gpt-4"
```

## Testing Flows

```python
# Use built-in playground
# 1. Click "Play" button in editor
# 2. Provide test inputs
# 3. View component outputs in real-time
# 4. Debug component-by-component

# Check execution logs
# Monitor component state
# Validate output format
```

## Flow Metadata

```yaml
flow_id: "abc-123-def"
version: "1.0.0"
created: "2026-02-06"
components_count: 12
edge_count: 15
execution_time_ms: 2500
```

## Related

- [visual-editor.md](../concepts/visual-editor.md) - Drag-and-drop interface
- [agents-tools.md](../concepts/agents-tools.md) - Agent components
- [custom-components.md](../patterns/custom-components.md) - Build custom components
