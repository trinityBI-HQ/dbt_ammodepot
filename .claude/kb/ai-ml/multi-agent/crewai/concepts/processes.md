# Processes and Flows

> **Purpose**: Execution flow control -- sequential, hierarchical, and event-driven Flows
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

CrewAI v1.9.x provides three orchestration models: **sequential** (linear), **hierarchical** (manager-coordinated), and **Flows** (event-driven with decorators). Flows are the primary addition in v1.x, enabling conditional branching, loops, shared state, and human-in-the-loop pauses. Since v1.9.0, Flows also support parent-child event ordering hierarchies.

## Crew Processes

```python
from crewai import Crew, Process

# Sequential: Tasks run in order
sequential_crew = Crew(
    agents=[triage_agent, root_cause_agent, reporter_agent],
    tasks=[triage_task, analysis_task, report_task],
    process=Process.sequential
)

# Hierarchical: Manager delegates dynamically
hierarchical_crew = Crew(
    agents=[triage_agent, root_cause_agent, reporter_agent],
    tasks=[complex_task],
    process=Process.hierarchical,
    manager_llm="gemini/gemini-2.0-flash"
)
```

| Process | Execution | Manager | Best For |
|---------|-----------|---------|----------|
| `sequential` | Fixed order | No | Linear workflows |
| `hierarchical` | Dynamic | Yes | Complex, adaptive |

## Flows (v1.0+ Stable)

Flows provide event-driven orchestration using decorators. Steps react to events from other steps, enabling branching, loops, and shared state.

```python
from crewai.flow.flow import Flow, start, listen, router

class IncidentFlow(Flow):
    @start()
    def collect_logs(self):
        """Entry point - runs first."""
        return fetch_logs()

    @listen(collect_logs)
    def triage(self, logs):
        """Reacts to collect_logs completion."""
        return triage_crew.kickoff(inputs={"logs": logs})

    @router(triage)
    def route_by_severity(self, result):
        """Conditional branching based on triage output."""
        if result.severity == "CRITICAL":
            return "escalate"
        return "auto_fix"

    @listen("escalate")
    def handle_critical(self, result):
        return escalation_crew.kickoff(inputs={"incident": result})

    @listen("auto_fix")
    def handle_auto(self, result):
        return remediation_crew.kickoff(inputs={"issue": result})

# Run the Flow
flow = IncidentFlow()
flow.kickoff()
```

### Flow Decorators

| Decorator | Purpose | Triggers |
|-----------|---------|----------|
| `@start()` | Entry point(s) of a Flow | On `flow.kickoff()` |
| `@listen(step)` | React to step completion | When referenced step finishes |
| `@router(step)` | Conditional branching | Returns route name string |

### Flow State (Shared)

Flows maintain shared state across all steps via `self.state`:

```python
from pydantic import BaseModel

class IncidentState(BaseModel):
    severity: str = ""
    errors: list = []
    notified: bool = False

class MyFlow(Flow[IncidentState]):
    @start()
    def begin(self):
        self.state.severity = "ERROR"
        self.state.errors = ["OOM on cloud-run-v2"]
```

## Human-in-the-Loop for Flows (v1.8.0)

Flows can pause execution and wait for human feedback:

```python
class ApprovalFlow(Flow):
    @start()
    def analyze(self):
        return analysis_crew.kickoff()

    @listen(analyze)
    def request_approval(self, analysis):
        # Flow pauses here for human input
        return self.pause_for_human_input(
            prompt="Review analysis and approve remediation"
        )

    @listen(request_approval)
    def execute_remediation(self, human_response):
        if human_response.approved:
            return remediation_crew.kickoff()
```

## Event Ordering (v1.9.0)

Parent-child event hierarchies ensure deterministic execution order when multiple listeners react to the same event.

## DataOps Recommendation

| Scenario | Orchestration | Reason |
|----------|---------------|--------|
| Standard monitoring | Sequential Crew | Predictable: Triage->Analyze->Report |
| Incident response | Flow with @router | Severity-based branching |
| High volume logs | Sequential Crew | Lower cost per execution |
| Approval workflows | Flow + human-in-the-loop | Pause for human decision |

## Related

- [Crews](../concepts/crews.md)
- [Triage Pattern](../patterns/triage-investigation-report.md)
- [Escalation Workflow](../patterns/escalation-workflow.md)
