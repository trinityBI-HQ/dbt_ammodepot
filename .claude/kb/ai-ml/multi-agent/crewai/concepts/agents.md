# Agents

> **Purpose**: Autonomous AI units with roles, goals, backstories, tools, and multimodal capabilities
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Agents are the fundamental building blocks of CrewAI (v1.9.x). Each agent is a role-playing autonomous entity with a specific job function, goal, and backstory that shapes its decision-making. Agents can use tools, collaborate with other agents, leverage knowledge sources, and work within Crews or Flows. Since v1.9.0, agents support multimodal inputs (vision/audio) and structured outputs via response_format.

## The Pattern

```python
from crewai import Agent

# DataOps Triage Agent Example (v1.9.x)
triage_agent = Agent(
    role="Log Triage Specialist",
    goal="Classify and prioritize log events by severity",
    backstory="""You are an expert DevOps engineer with 10 years
    of experience monitoring cloud infrastructure. You excel at
    quickly identifying critical issues from log noise.""",
    tools=[log_reader_tool, gcs_tool],
    llm="gemini/gemini-2.0-flash",  # LiteLLM format: provider/model
    allow_delegation=False,
    max_iter=15,
    max_retry_limit=2,
    verbose=True
)
```

## Quick Reference

| Parameter | Required | Description |
|-----------|----------|-------------|
| `role` | Yes | Job title (e.g., "Log Triage Specialist") |
| `goal` | Yes | What agent aims to achieve |
| `backstory` | Yes | Context shaping behavior |
| `tools` | No | List of available tools |
| `llm` | No | LLM via LiteLLM (default: GPT-4o) |
| `allow_delegation` | No | Can delegate tasks (default: False) |
| `max_iter` | No | Max iterations (default: 25) |
| `knowledge_sources` | No | List of knowledge sources (PDF, CSV, text, URLs) |

## LLM Routing via LiteLLM

CrewAI v1.x uses LiteLLM as the underlying routing layer, supporting 100+ providers:

```python
# Provider/model format examples
agent_openai = Agent(role="...", llm="gpt-4o")
agent_gemini = Agent(role="...", llm="gemini/gemini-2.0-flash")
agent_anthropic = Agent(role="...", llm="anthropic/claude-sonnet-4-20250514")
agent_ollama = Agent(role="...", llm="ollama/llama3")
```

## Multimodal Inputs (v1.9.0)

Agents can process vision and audio inputs when using multimodal-capable LLMs:

```python
from crewai import Agent, Task

vision_agent = Agent(
    role="Image Analyst",
    goal="Analyze images for quality issues",
    llm="gpt-4o",  # Must support vision
)

task = Task(
    description="Analyze the dashboard screenshot for anomalies",
    expected_output="List of visual anomalies detected",
    agent=vision_agent,
    images=["path/to/screenshot.png"]  # Multimodal input
)
```

## A2A Protocol (v1.8.1+)

Agent-to-Agent protocol enables interoperability with external agent systems:

```python
# CrewAI agents can communicate with external agents
# via the A2A (Agent-to-Agent) protocol, enabling
# cross-framework collaboration (e.g., CrewAI <-> AutoGen)
```

## Common Mistakes

### Wrong

```python
# Too vague - agent won't know what to do
agent = Agent(
    role="Helper",
    goal="Help with stuff",
    backstory="You help."
)
```

### Correct

```python
# Specific role, clear goal, detailed backstory
agent = Agent(
    role="Root Cause Analyst",
    goal="Identify the root cause of pipeline failures and suggest fixes",
    backstory="""You are a senior SRE specializing in data pipelines.
    You've debugged hundreds of Cloud Run, Pub/Sub, and BigQuery issues.
    You approach problems methodically, checking logs, metrics, and
    recent deployments to find the underlying cause.""",
    tools=[log_reader_tool, metrics_tool],
    max_iter=10  # Prevent runaway analysis
)
```

## Agent Types for DataOps

| Agent | Role | Goal |
|-------|------|------|
| Triage | Log Triage Specialist | Classify severity, filter noise |
| Root Cause | Root Cause Analyst | Find patterns, suggest fixes |
| Reporter | Alert Reporter | Format reports, notify Slack |

## Related

- [Crews](../concepts/crews.md)
- [Tasks](../concepts/tasks.md)
- [Processes and Flows](../concepts/processes.md)
- [Triage Pattern](../patterns/triage-investigation-report.md)
