# Mermaid Knowledge Base

> **Purpose**: JavaScript-based diagramming tool that renders text definitions into SVG diagrams
> **MCP Validated**: 2026-02-17

## Quick Navigation

| File | Purpose |
|------|---------|
| [concepts/diagram-types.md](concepts/diagram-types.md) | All 20+ diagram types with syntax identifiers |
| [concepts/syntax-fundamentals.md](concepts/syntax-fundamentals.md) | Node shapes, edges, subgraphs, directions, comments |
| [concepts/theming-styling.md](concepts/theming-styling.md) | Themes (default, dark, forest, neutral, base), custom CSS, directives |
| [concepts/configuration.md](concepts/configuration.md) | Mermaid config, init directives, render options, security |
| [patterns/architecture-diagrams.md](patterns/architecture-diagrams.md) | Software architecture patterns (C4, system context, components) |
| [patterns/data-flow-diagrams.md](patterns/data-flow-diagrams.md) | ETL/pipeline flow visualization patterns |
| [patterns/ci-cd-diagrams.md](patterns/ci-cd-diagrams.md) | CI/CD pipeline and deployment flow diagrams |
| [patterns/integration-patterns.md](patterns/integration-patterns.md) | Integration with GitHub, GitLab, Docusaurus, Notion, Confluence |
| [quick-reference.md](quick-reference.md) | Fast lookup tables for all diagram types |

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Diagrams as Code** | Text-based definitions render into SVG diagrams |
| **Markdown Native** | Renders inside fenced code blocks on GitHub, GitLab, Notion |
| **20+ Diagram Types** | Flowchart, sequence, class, state, ER, Gantt, pie, mindmap, timeline, etc. |
| **Theming** | 5 built-in themes with customizable variables via `base` theme |
| **Directives** | Per-diagram configuration using `%%{init: {...}}%%` syntax |
| **Layout Engines** | Dagre (default) and ELK for advanced layouts |

## Installation

```bash
npm install mermaid
# CDN: import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs';
```

**No install needed for:** GitHub, GitLab, Notion, Obsidian (native support).

## Getting Started

```markdown
```mermaid
flowchart LR
    A[Start] --> B{Decision}
    B -->|Yes| C[Action]
    B -->|No| D[End]
```                                (remove the leading spaces)
```

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/syntax-fundamentals.md, concepts/diagram-types.md |
| **Intermediate** | concepts/theming-styling.md, patterns/architecture-diagrams.md |
| **Advanced** | concepts/configuration.md, patterns/integration-patterns.md |

## Agent Usage

| Agent | Primary Files | Use Case |
|-------|---------------|----------|
| kb-architect | All files | Generate diagrams for documentation |
| code-documenter | patterns/architecture-diagrams.md | Visualize system architecture |
| ci-cd-specialist | patterns/ci-cd-diagrams.md | Document CI/CD pipelines |

## Cross-References

| Related KB | Relevance |
|------------|-----------|
| [GitHub](../../devops-sre/version-control/github/) | Native Mermaid rendering in READMEs and issues |
| [Docker Compose](../../devops-sre/containerization/docker-compose/) | Service architecture diagrams |
| [Dagster](../../data-engineering/orchestration/dagster/) | Pipeline flow visualization |

## Project Context

Standard tool for diagrams-as-code. Embeds directly in Markdown (GitHub, GitLab, Obsidian, Notion). Version-controlled diagrams alongside code. 20+ diagram types. Extensible theming. Live editor at [mermaid.live](https://mermaid.live/).
