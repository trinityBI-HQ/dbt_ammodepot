# Mermaid Quick Reference

> Fast lookup tables. For detailed examples, see linked files.
> **MCP Validated**: 2026-02-17

## Diagram Types

| Type | Identifier | Use Case |
|------|-----------|----------|
| Flowchart | `flowchart LR` | Process flows, decisions |
| Sequence | `sequenceDiagram` | API calls, interactions |
| Class | `classDiagram` | OOP relationships |
| State | `stateDiagram-v2` | State machines |
| ER | `erDiagram` | Database schema |
| Gantt | `gantt` | Project timelines |
| Pie | `pie` | Proportional data |
| Mindmap | `mindmap` | Brainstorming |
| Timeline | `timeline` | Chronological events |
| Git Graph | `gitGraph` | Branch/merge flows |
| C4 Context | `C4Context` | Architecture (L1) |
| Quadrant | `quadrantChart` | 2x2 analysis |
| Sankey | `sankey-beta` | Flow quantities |
| XY Chart | `xychart-beta` | Line/bar charts |
| Block | `block-beta` | System components |
| Kanban | `kanban` | Task boards |
| Architecture | `architecture-beta` | System design |

## Node Shapes

| Syntax | Shape | Example |
|--------|-------|---------|
| `A[text]` | Rectangle | `A[Process]` |
| `A(text)` | Rounded | `A(Start)` |
| `A([text])` | Stadium | `A([Deploy])` |
| `A{text}` | Diamond | `A{Decision}` |
| `A((text))` | Circle | `A((Hub))` |
| `A[(text)]` | Cylinder | `A[(Database)]` |
| `A[[text]]` | Subroutine | `A[[Function]]` |
| `A{{text}}` | Hexagon | `A{{Prepare}}` |
| `A>text]` | Flag | `A>Event]` |
| `A(((text)))` | Double circle | `A(((Target)))` |

## Edge Types

| Syntax | Style |
|--------|-------|
| `-->` | Arrow |
| `---` | Open link |
| `-.->` | Dotted arrow |
| `==>` | Thick arrow |
| `~~~` | Invisible link |
| `--o` | Circle end |
| `--x` | Cross end |
| `<-->` | Bidirectional |
| `-- text -->` | Arrow with label |

## Direction Options

| Code | Direction |
|------|-----------|
| `TB` / `TD` | Top to bottom |
| `BT` | Bottom to top |
| `LR` | Left to right |
| `RL` | Right to left |

## Built-in Themes

| Theme | Best For |
|-------|----------|
| `default` | General use |
| `dark` | Dark mode UIs |
| `forest` | Green-toned diagrams |
| `neutral` | Print / B&W |
| `base` | Custom theming (only modifiable theme) |

## Common Pitfalls

| Don't | Do |
|-------|-----|
| Use color names in themes | Use hex codes (`#ff0000`) |
| Use `end` as a node ID | Quote or rename: `End_Node` |
| Skip diagram type declaration | Always start with `flowchart`, `sequenceDiagram`, etc. |
| Nest curly braces in comments | Use `%%` line comments instead |
| Hardcode styles inline | Use `classDef` + `:::className` |

## Related Documentation

| Topic | Path |
|-------|------|
| All diagram types | `concepts/diagram-types.md` |
| Syntax details | `concepts/syntax-fundamentals.md` |
| Theming | `concepts/theming-styling.md` |
| Full index | `index.md` |
