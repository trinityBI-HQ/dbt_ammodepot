# CrewAI Knowledge Base

> **Purpose**: Multi-agent AI orchestration with Flows, Knowledge, and autonomous DataOps monitoring
> **Version**: 1.9.x (GA since October 2025)
> **MCP Validated**: 2026-02-19

## Quick Navigation

### Concepts (< 150 lines each)

| File | Purpose |
|------|---------|
| [concepts/agents.md](concepts/agents.md) | Role-playing agents, A2A protocol, multimodal inputs |
| [concepts/crews.md](concepts/crews.md) | Team composition, Flows orchestration, kickoff methods |
| [concepts/tasks.md](concepts/tasks.md) | Work units, structured outputs, response_format |
| [concepts/tools.md](concepts/tools.md) | Custom tools, LiteLLM routing, tool calling (v1.9) |
| [concepts/memory.md](concepts/memory.md) | Memory systems and built-in Knowledge Base sources |
| [concepts/processes.md](concepts/processes.md) | Sequential, hierarchical, and Flows execution |

### Patterns (< 200 lines each)

| File | Purpose |
|------|---------|
| [patterns/triage-investigation-report.md](patterns/triage-investigation-report.md) | Three-agent architecture for log monitoring |
| [patterns/log-analysis-agent.md](patterns/log-analysis-agent.md) | Custom tools for GCS log reading and parsing |
| [patterns/escalation-workflow.md](patterns/escalation-workflow.md) | Agent-to-human handoff and delegation |
| [patterns/slack-integration.md](patterns/slack-integration.md) | Alert notifications via Slack webhooks |
| [patterns/circuit-breaker.md](patterns/circuit-breaker.md) | Preventing runaway agents with iteration limits |
| [patterns/crew-coordination.md](patterns/crew-coordination.md) | Pipeline monitoring with coordinated crews |

---

## Quick Reference

- [quick-reference.md](quick-reference.md) - Fast lookup tables for agents, tasks, Flows, and processes

---

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Agent** | Autonomous unit with role, backstory, goal, and tools |
| **Crew** | Team of agents working together on related tasks |
| **Task** | Unit of work with description, expected output, and structured response_format |
| **Tool** | Capability given to agents (log reader, Slack sender, custom functions) |
| **Memory** | Persistent context across executions (STM, LTM, Entity) |
| **Process** | Execution flow (sequential or hierarchical) |
| **Flow** | Event-driven workflow with @start/@listen decorators, branching, and shared state |
| **Knowledge** | Built-in knowledge sources (text, PDF, CSV, JSON, Excel, URLs) |
| **A2A** | Agent-to-Agent protocol for external agent interoperability (v1.8.1+) |

---

## What Changed in v1.x (GA)

| Version | Feature | Description |
|---------|---------|-------------|
| 1.0 | GA Release | Stable API, production-ready (Oct 2025) |
| 1.0+ | Flows | Event-driven orchestration with @start()/@listen() |
| 1.0+ | Knowledge | Built-in knowledge sources for agents |
| 1.0+ | LiteLLM | Underlying LLM routing layer for all providers |
| 1.8.0 | Human-in-the-Loop (Flows) | Pause Flow execution for human feedback |
| 1.8.1 | A2A Protocol | Agent-to-Agent external interoperability |
| 1.8.1 | Galileo | LLM observability integration |
| 1.9.0 | Multimodal | Vision/audio file inputs for agents |
| 1.9.0 | Structured Outputs | response_format across providers |
| 1.9.0 | Keycloak SSO | Enterprise authentication |
| 1.9.0 | Event Ordering | Parent-child hierarchy for events |
| 1.9.0 | Tool Calling | Overhauled tool calling mechanisms |

---

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/agents.md, concepts/tasks.md |
| **Intermediate** | concepts/crews.md, concepts/processes.md (Flows) |
| **Advanced** | patterns/circuit-breaker.md, patterns/escalation-workflow.md |

---

## Project Context

This KB supports DataOps monitoring and multi-agent orchestration patterns:

```
Cloud Logging -> GCS Export -> CrewAI Triage -> Root Cause -> Reporter -> Slack
```

With Flows (v1.0+), the same pipeline can use event-driven orchestration:

```
@start() -> triage_step -> @listen() -> analyze_step -> @listen() -> report_step
```
