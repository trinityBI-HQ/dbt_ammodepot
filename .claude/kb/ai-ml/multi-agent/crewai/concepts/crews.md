# Crews

> **Purpose**: Team composition and orchestration of multiple agents
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

A Crew is a team of agents working together to accomplish related tasks. Crews define the collaboration strategy, task flow, and optional features like memory and planning. In CrewAI v1.9.x, Crews can be orchestrated directly or composed within Flows for event-driven execution with branching, loops, and shared state.

## The Pattern

```python
from crewai import Crew, Process

# DataOps Monitoring Crew (v1.9.x)
monitoring_crew = Crew(
    agents=[triage_agent, root_cause_agent, reporter_agent],
    tasks=[triage_task, analysis_task, report_task],
    process=Process.sequential,
    memory=True,
    verbose=True,
    max_rpm=30,  # Rate limit API calls
    share_crew=False
)

# Execute the crew
result = monitoring_crew.kickoff()
```

## Quick Reference

| Parameter | Required | Description |
|-----------|----------|-------------|
| `agents` | Yes | List of Agent instances |
| `tasks` | Yes | List of Task instances |
| `process` | No | sequential or hierarchical |
| `memory` | No | Enable memory system (default: False) |
| `verbose` | No | Show execution details |
| `max_rpm` | No | Max requests per minute |
| `manager_llm` | No | LLM for hierarchical manager |
| `knowledge_sources` | No | Crew-level knowledge sources |

## Process Types

| Process | Best For | Characteristics |
|---------|----------|-----------------|
| `sequential` | Linear workflows | Predictable, easy to debug |
| `hierarchical` | Complex projects | Dynamic delegation, manager agent |

For event-driven orchestration with branching and loops, see [Flows in Processes](../concepts/processes.md).

## Using Crews Inside Flows

```python
from crewai.flow.flow import Flow, start, listen

class MonitoringFlow(Flow):
    @start()
    def collect_logs(self):
        return fetch_logs_from_gcs()

    @listen(collect_logs)
    def run_triage(self, logs):
        # Crews can be kicked off inside Flow steps
        result = monitoring_crew.kickoff(inputs={"logs": logs})
        return result

    @listen(run_triage)
    def notify(self, analysis):
        if analysis.severity == "CRITICAL":
            reporter_crew.kickoff(inputs={"report": analysis})
```

## Common Mistakes

### Wrong

```python
# Missing task dependencies - agents work in isolation
crew = Crew(
    agents=[agent1, agent2, agent3],
    tasks=[task1, task2, task3],
    process=Process.sequential
)
# Tasks don't share context
```

### Correct

```python
# Tasks reference each other for context flow
triage_task = Task(description="...", agent=triage_agent)
analysis_task = Task(
    description="...",
    agent=root_cause_agent,
    context=[triage_task]  # Gets triage output
)
report_task = Task(
    description="...",
    agent=reporter_agent,
    context=[triage_task, analysis_task]  # Gets both outputs
)

crew = Crew(
    agents=[triage_agent, root_cause_agent, reporter_agent],
    tasks=[triage_task, analysis_task, report_task],
    process=Process.sequential,
    memory=True  # Enable for cross-task learning
)
```

## Kickoff Methods

| Method | Description |
|--------|-------------|
| `kickoff()` | Run crew synchronously |
| `kickoff_async()` | Run crew asynchronously |
| `kickoff_for_each(inputs)` | Run for each input item |

## Related

- [Agents](../concepts/agents.md)
- [Processes and Flows](../concepts/processes.md)
- [Crew Coordination](../patterns/crew-coordination.md)
