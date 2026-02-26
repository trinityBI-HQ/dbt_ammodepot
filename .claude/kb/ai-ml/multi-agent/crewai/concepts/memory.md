# Memory and Knowledge

> **Purpose**: Persistent context across tasks/executions and built-in knowledge sources
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

CrewAI v1.9.x provides two complementary systems for agent context: **Memory** (runtime learning) and **Knowledge** (pre-loaded reference data). Memory enables agents to remember, reason, and learn from past interactions with short-term, long-term, and entity memory. Knowledge (v1.0+) lets agents access structured data sources like PDFs, CSVs, JSON, Excel files, and URLs without custom tool development.

## Memory Pattern

```python
from crewai import Crew, Process

# Enable memory with defaults
crew = Crew(
    agents=[triage_agent, root_cause_agent, reporter_agent],
    tasks=[triage_task, analysis_task, report_task],
    process=Process.sequential,
    memory=True,  # Enables STM, LTM, Entity memory
    verbose=True
)

# Memory persists learning across kickoffs
result1 = crew.kickoff(inputs={"log_path": "logs/day1.json"})
result2 = crew.kickoff(inputs={"log_path": "logs/day2.json"})
# Day 2 benefits from Day 1 learnings
```

## Memory Types

| Type | Storage | Purpose | Scope |
|------|---------|---------|-------|
| Short-term (STM) | ChromaDB | Current context | Single execution |
| Long-term (LTM) | SQLite3 | Past experiences | Across sessions |
| Entity | ChromaDB | People, concepts | Relationship mapping |

## Knowledge Sources (v1.0+)

Knowledge lets agents reference structured data without writing custom tools:

```python
from crewai import Agent
from crewai.knowledge.source.text_knowledge_source import TextKnowledgeSource
from crewai.knowledge.source.pdf_knowledge_source import PDFKnowledgeSource
from crewai.knowledge.source.csv_knowledge_source import CSVKnowledgeSource

# Text knowledge
runbook = TextKnowledgeSource(
    content="When BigQuery slot usage exceeds 80%, scale up reservations..."
)

# PDF knowledge
sla_doc = PDFKnowledgeSource(file_paths=["docs/sla-agreement.pdf"])

# CSV knowledge
error_catalog = CSVKnowledgeSource(file_paths=["data/known-errors.csv"])

# Agent with knowledge sources
agent = Agent(
    role="SRE Analyst",
    goal="Diagnose issues using runbooks and SLA documentation",
    backstory="Expert SRE with access to operational knowledge.",
    knowledge_sources=[runbook, sla_doc, error_catalog]
)
```

## Available Knowledge Sources

| Source | Class | Input |
|--------|-------|-------|
| Text | `TextKnowledgeSource` | Inline strings |
| PDF | `PDFKnowledgeSource` | `file_paths=["..."]` |
| CSV | `CSVKnowledgeSource` | `file_paths=["..."]` |
| JSON | `JSONKnowledgeSource` | `file_paths=["..."]` |
| Excel | `ExcelKnowledgeSource` | `file_paths=["..."]` |
| URL | `URLKnowledgeSource` | `urls=["..."]` |

## Common Mistakes

### Wrong

```python
# Memory disabled - agents forget everything between runs
crew = Crew(
    agents=[...],
    tasks=[...],
    memory=False  # Default - no learning
)
```

### Correct

```python
# Memory enabled for continuous learning
crew = Crew(
    agents=[triage_agent, root_cause_agent],
    tasks=[triage_task, analysis_task],
    memory=True,  # Enable all memory types
    embedder={
        "provider": "google",
        "config": {"model": "models/embedding-001"}
    }
)
```

## DataOps Use Case

| System | Application |
|--------|-------------|
| STM | Triage results passed to Root Cause agent |
| LTM | "BigQuery quota errors happen on Mondays" |
| Entity | Track service names, error patterns |
| Knowledge (PDF) | SLA docs, runbooks for incident reference |
| Knowledge (CSV) | Known error catalog, escalation contacts |

## Related

- [Crews](../concepts/crews.md)
- [Crew Coordination](../patterns/crew-coordination.md)
