# Visual Editor

> **Purpose**: Drag-and-drop interface for building, testing, and sharing Langflow applications
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-06

## Overview

Langflow's visual editor provides a low-code interface for creating AI workflows. Features a component library, canvas for building flows, property inspector for configuration, and integrated playground for testing. All flows compile to executable code.

## Editor Layout

```text
┌─────────────────────────────────────────────────────┐
│ Top Bar: Save | Export | Deploy | Settings           │
├──────────┬──────────────────────────────────────────┤
│ Component│         Canvas (Flow Builder)             │
│ Library  │  [Comp1] ──→ [Comp2] ──→ [Comp3]        │
│ - Models │         ╲──→ [Comp4]                     │
│ - Agents │                                           │
│ - Vectors│                                           │
│ - Tools  │                                           │
├──────────┴──────────────────────────────────────────┤
│ Property Inspector: Component Configuration          │
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

```text
1. Drag component from library to canvas
2. Click component to open properties panel
3. Configure parameters (API keys, model settings)
4. Connect output handle → input handle
5. Click "Play" to test in playground

Example: Text Input → Prompt Template → OpenAI LLM → Text Output
```

## Component Configuration

```yaml
component: "OpenAI"
properties:
  model: "gpt-4"
  temperature: 0.7
  max_tokens: 500
  api_key: "${OPENAI_API_KEY}"
inputs:
  - name: "prompt"
    type: "string"
    required: true
outputs:
  - name: "text"
    type: "string"
```

## Testing with Playground

```text
1. Open playground panel (bottom of screen)
2. Enter test inputs → Click "Run"
3. View outputs and intermediate results
4. Inspect each component's output for debugging
```

## Sharing Flows

```bash
# Export: File → Export → flow.json
# Import: File → Import → Select flow.json
# Share via URL (Cloud): Share → Generate Link
# Version control: git add flows/my-flow.json
```

## Common Mistakes

```python
# Wrong: Unconnected components, hardcoded secrets
LLM component with no prompt input  # Will fail
api_key = "sk-abc123..."  # Security risk

# Correct: All inputs connected, env vars
# Prompt → LLM → Output
api_key = "${OPENAI_API_KEY}"
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+S` | Save flow |
| `Ctrl+Z/Y` | Undo/Redo |
| `Delete` | Delete selected |
| `Ctrl+C/V` | Copy/paste |
| `Ctrl+D` | Duplicate |
| `/` | Quick component search |

## Flow Validation

```text
Automatic checks: required inputs connected, no circular dependencies,
compatible data types, required parameters set.
Warnings: missing API key, unconfigured component.
```

## Related

- [flows-components.md](../concepts/flows-components.md) - Component fundamentals
- [custom-components.md](../patterns/custom-components.md) - Build custom components
- [api-integration.md](../patterns/api-integration.md) - Deploy flows as APIs
