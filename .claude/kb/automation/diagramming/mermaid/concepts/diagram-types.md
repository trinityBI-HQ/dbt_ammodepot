# Mermaid Diagram Types

> **Purpose**: Complete reference for all diagram types supported by Mermaid
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-17

## Overview

Mermaid supports 20+ diagram types, each with a unique syntax identifier. Every diagram starts with its type declaration followed by content definitions.

## Diagram Type Reference

| Type | Identifier | Category |
|------|-----------|----------|
| Flowchart | `flowchart LR/TD` | Structural |
| Sequence | `sequenceDiagram` | Behavioral |
| Class | `classDiagram` | Structural |
| State | `stateDiagram-v2` | Behavioral |
| ER Diagram | `erDiagram` | Structural |
| Gantt | `gantt` | Project Mgmt |
| Pie Chart | `pie` | Data Viz |
| Mindmap | `mindmap` | Structural |
| Timeline | `timeline` | Project Mgmt |
| Git Graph | `gitGraph` | Structural |
| C4 Context | `C4Context` | Architecture |
| C4 Container | `C4Container` | Architecture |
| C4 Component | `C4Component` | Architecture |
| User Journey | `journey` | Behavioral |
| Quadrant | `quadrantChart` | Data Viz |
| Sankey | `sankey-beta` | Data Viz |
| XY Chart | `xychart-beta` | Data Viz |
| Block | `block-beta` | Structural |
| Kanban | `kanban` | Project Mgmt |
| Architecture | `architecture-beta` | Architecture |
| Packet | `packet-beta` | Network |
| Requirement | `requirementDiagram` | Structural |
| ZenUML | `zenuml` | Behavioral |

## Key Examples

### Flowchart
```mermaid
flowchart TD
    A[Start] --> B{Valid?}
    B -->|Yes| C[Process]
    B -->|No| D[Reject]
```

### Sequence Diagram
```mermaid
sequenceDiagram
    Client->>Server: POST /api/data
    Server->>DB: INSERT
    DB-->>Server: OK
    Server-->>Client: 201 Created
```

### ER Diagram
```mermaid
erDiagram
    CUSTOMER ||--o{ ORDER : places
    ORDER ||--|{ LINE_ITEM : contains
```

### State Diagram
```mermaid
stateDiagram-v2
    [*] --> Draft
    Draft --> Review : submit
    Review --> Approved : approve
    Approved --> [*]
```

### Gantt Chart
```mermaid
gantt
    title Sprint Plan
    dateFormat YYYY-MM-DD
    section Backend
        API Design :a1, 2026-01-01, 5d
        Implementation :after a1, 10d
```

### Pie Chart
```mermaid
pie title Storage
    "S3" : 45
    "GCS" : 30
    "Azure" : 25
```

### Mindmap
```mermaid
mindmap
    root((Project))
        Backend
            API
            Database
        Frontend
            React
            CSS
```

### Git Graph
```mermaid
gitGraph
    commit id: "init"
    branch feature
    commit id: "feat-1"
    checkout main
    merge feature id: "merge"
```

### Class Diagram
```mermaid
classDiagram
    class Animal {
        +String name
        +makeSound() void
    }
    Animal <|-- Dog
    Animal <|-- Cat
```

### Timeline
```mermaid
timeline
    title Milestones
    2026-Q1 : MVP Launch
    2026-Q2 : GA Release
```

### Quadrant Chart
```mermaid
quadrantChart
    title Priority Matrix
    x-axis Low Effort --> High Effort
    y-axis Low Impact --> High Impact
    Feature A: [0.8, 0.9]
    Feature B: [0.2, 0.7]
```

## Related

- [Syntax Fundamentals](syntax-fundamentals.md) - Node shapes, edges, directions
- [Architecture Diagrams](../patterns/architecture-diagrams.md) - Real-world patterns
