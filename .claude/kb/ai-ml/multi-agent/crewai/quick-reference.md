# CrewAI Quick Reference

> Fast lookup tables for v1.9.x. For code examples, see linked files.
> **MCP Validated**: 2026-02-19

## Agent Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `role` | str | required | Agent's job title/function |
| `goal` | str | required | What the agent aims to achieve |
| `backstory` | str | required | Context shaping agent behavior |
| `tools` | list | `[]` | Tools available to the agent |
| `llm` | str/LLM | GPT-4o | LLM via LiteLLM (e.g., `gemini/gemini-2.0-flash`) |
| `allow_delegation` | bool | `False` | Can delegate to other agents |
| `max_iter` | int | `25` | Maximum reasoning iterations |
| `max_retry_limit` | int | `2` | Retries on error |
| `knowledge_sources` | list | `[]` | Built-in knowledge (PDF, CSV, text, URLs) |

## Task Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `description` | str | required | What needs to be done |
| `expected_output` | str | required | Format/content of result |
| `agent` | Agent | required | Who performs the task |
| `context` | list | `[]` | Dependent tasks for context |
| `human_input` | bool | `False` | Require human approval |
| `output_json` | BaseModel | None | Pydantic model for structured output |
| `output_pydantic` | BaseModel | None | Return validated Pydantic object |

## Flow Decorators (v1.0+)

| Decorator | Purpose | Example |
|-----------|---------|---------|
| `@start()` | Entry point of a Flow | `@start() def begin(self):` |
| `@listen(step)` | React to step completion | `@listen(begin) def next(self, result):` |
| `@router(step)` | Conditional branching | Return route name for path selection |

## Process Types

| Process | Use Case | Manager |
|---------|----------|---------|
| `sequential` | Linear workflows, predictable | No |
| `hierarchical` | Complex projects, dynamic | Yes (auto/manual) |
| **Flow** | Event-driven, branching, loops | No (decorator-based) |

## Memory Types

| Memory | Storage | Purpose |
|--------|---------|---------|
| Short-term | ChromaDB (RAG) | Current context within execution |
| Long-term | SQLite3 | Learning across sessions |
| Entity | ChromaDB (RAG) | People, places, concepts tracking |

## Knowledge Sources (v1.0+)

| Source | Class | Input |
|--------|-------|-------|
| Text | `TextKnowledgeSource` | Inline strings |
| PDF | `PDFKnowledgeSource` | PDF file paths |
| CSV | `CSVKnowledgeSource` | CSV file paths |
| JSON | `JSONKnowledgeSource` | JSON file paths |
| Excel | `ExcelKnowledgeSource` | XLSX file paths |
| URL | `URLKnowledgeSource` | Web page URLs |

## Key v1.9 Features

| Feature | Version | Summary |
|---------|---------|---------|
| Flows | 1.0+ | @start/@listen event-driven orchestration |
| Knowledge | 1.0+ | Built-in document ingestion for agents |
| Human-in-the-Loop (Flows) | 1.8.0 | Pause Flows for human feedback |
| A2A Protocol | 1.8.1+ | External agent interoperability |
| Galileo | 1.8.1 | LLM observability integration |
| Multimodal | 1.9.0 | Vision/audio inputs |
| Structured Outputs | 1.9.0 | response_format across providers |
| Keycloak SSO | 1.9.0 | Enterprise auth |
| Event Ordering | 1.9.0 | Parent-child event hierarchies |

## Common Pitfalls

| Don't | Do |
|-------|-----|
| Use `allow_delegation=True` on all agents | Enable only when needed |
| Skip `expected_output` | Always define output format |
| Ignore `max_iter` limits | Set appropriate bounds |
| Use hierarchical for simple tasks | Use sequential for linear flows |
| Use Crews when Flows fit better | Use Flows for event-driven branching |
| Hardcode LLM provider strings | Use LiteLLM format: `provider/model` |

## Related Documentation

| Topic | Path |
|-------|------|
| Agent Concepts | `concepts/agents.md` |
| Custom Tools | `concepts/tools.md` |
| Flows and Processes | `concepts/processes.md` |
| Memory and Knowledge | `concepts/memory.md` |
| Full Index | `index.md` |
