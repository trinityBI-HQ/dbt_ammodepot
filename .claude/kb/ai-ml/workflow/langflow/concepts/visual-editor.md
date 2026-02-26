# Visual Editor

> **Purpose**: Drag-and-drop interface for building, testing, and sharing Langflow applications
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-06

## Overview

Langflow's visual editor provides a low-code interface for creating AI workflows without writing extensive code. The editor features a component library, canvas for building flows, property inspector for configuration, and integrated playground for testing. All flows are visual representations that compile to executable code.

## Editor Layout

```text
┌─────────────────────────────────────────────────────┐
│ Top Bar: Save | Export | Deploy | Settings          │
├──────────┬──────────────────────────────────────────┤
│          │                                           │
│ Component│         Canvas (Flow Builder)            │
│ Library  │                                           │
│          │  [Comp1] ──→ [Comp2] ──→ [Comp3]        │
│ - Models │         ╲                                 │
│ - Agents │          ╲──→ [Comp4]                    │
│ - Vectors│                                           │
│ - Tools  │                                           │
│          │                                           │
├──────────┴──────────────────────────────────────────┤
│ Property Inspector: Component Configuration         │
└─────────────────────────────────────────────────────┘
```

## Component Library

| Category | Available Components | Count |
|----------|---------------------|-------|
| **Language Models** | OpenAI, Anthropic, Google, Ollama, HuggingFace | 20+ |
| **Vector Stores** | Pinecone, Weaviate, Chroma, FAISS, Qdrant | 10+ |
| **Agents** | OpenAI Agent, Tool Calling, ReAct, Conversational | 8+ |
| **Data Loaders** | File, Web, PDF, JSON, CSV, API | 15+ |
| **Tools** | Search, Calculator, Python, API Call, Custom | 25+ |

## Building a Flow

```python
# Step-by-step flow creation
1. Drag component from library to canvas
2. Click component to open properties
3. Configure parameters (API keys, settings)
4. Drag from output handle to input handle
5. Repeat to build complete flow
6. Click "Play" to test

# Example: Simple chatbot
Text Input → Prompt Template → OpenAI LLM → Text Output
```

## Component Configuration

```yaml
# Example: OpenAI LLM component
component: "OpenAI"
properties:
  model: "gpt-4"
  temperature: 0.7
  max_tokens: 500
  api_key: "${OPENAI_API_KEY}"  # Environment variable

inputs:
  - name: "prompt"
    type: "string"
    required: true

outputs:
  - name: "text"
    type: "string"
```

## Testing with Playground

```python
# Built-in testing environment
# 1. Open playground panel (bottom of screen)
# 2. Enter test inputs
# 3. Click "Run"
# 4. View outputs and intermediate results

# Example test
input: "What is Langflow?"
output: "Langflow is a visual framework..."

# Inspect each component's output
# Debug step-by-step execution
# Validate data flow
```

## Sharing Flows

```bash
# Export flow as JSON
File → Export → flow.json

# Share via URL (Langflow Cloud)
Share → Generate Link → https://langflow.app/flows/abc123

# Import flow
File → Import → Select flow.json

# Version control
git add flows/my-flow.json
git commit -m "Add RAG chatbot flow"
```

## Common Mistakes

### Wrong

```python
# Forgetting to connect components
LLM component with no prompt input  # Will fail

# Hardcoding secrets
api_key = "sk-abc123..."  # Security risk
```

### Correct

```python
# All required inputs connected
Prompt → LLM → Output

# Use environment variables
api_key = "${OPENAI_API_KEY}"
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+S` | Save flow |
| `Ctrl+Z` | Undo |
| `Ctrl+Y` | Redo |
| `Delete` | Delete selected component |
| `Ctrl+C/V` | Copy/paste components |
| `Ctrl+D` | Duplicate component |

## Component Search

```python
# Quick component search
# Press "/" in component library
# Type component name
# Press Enter to add to canvas

# Example: "/openai" → finds OpenAI components
```

## Flow Validation

```python
# Automatic validation checks
✓ All required inputs connected
✓ No circular dependencies
✓ Compatible data types
✓ Required parameters set

# Warnings displayed in editor
⚠ Missing API key
⚠ Component not configured
```

## Related

- [flows-components.md](../concepts/flows-components.md) - Component fundamentals
- [custom-components.md](../patterns/custom-components.md) - Build custom components
- [api-integration.md](../patterns/api-integration.md) - Deploy flows as APIs
