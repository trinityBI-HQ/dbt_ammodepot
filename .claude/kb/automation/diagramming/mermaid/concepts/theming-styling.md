# Theming and Styling

> **Purpose**: Built-in themes, custom theming via base theme, and styling approaches
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-17

## Overview

Mermaid provides 5 built-in themes and a customizable `base` theme. Custom themes modify `themeVariables` using hex color codes only (not color names).

## Built-in Themes

| Theme | Description | Best For |
|-------|-------------|----------|
| `default` | Standard blue/gray | General documentation |
| `dark` | Dark backgrounds | Dark mode interfaces |
| `forest` | Green tones | Environmental themes |
| `neutral` | Grayscale | Print / B&W documents |
| `base` | Customizable foundation | Brand colors |

## Applying Themes

### Frontmatter (Recommended)
```mermaid
---
config:
  theme: dark
---
flowchart LR
    A --> B
```

### Init Directive
```mermaid
%%{init: {'theme': 'forest'}}%%
flowchart LR
    A --> B
```

### JavaScript (Site-wide)
```javascript
mermaid.initialize({ theme: 'dark' });
```

## Custom Theme Variables

Only the `base` theme supports `themeVariables`. Derived colors auto-calculate.

| Variable | Controls |
|----------|----------|
| `primaryColor` | Main node background |
| `primaryTextColor` | Text in primary nodes |
| `primaryBorderColor` | Border of primary nodes |
| `secondaryColor` | Secondary backgrounds |
| `tertiaryColor` | Tertiary elements |
| `lineColor` | Edge/connection lines |
| `noteBkgColor` | Note backgrounds |

### Example: Brand Colors
```mermaid
%%{init: {
  'theme': 'base',
  'themeVariables': {
    'primaryColor': '#1a73e8',
    'primaryTextColor': '#ffffff',
    'primaryBorderColor': '#1557b0',
    'lineColor': '#5f6368',
    'secondaryColor': '#e8f0fe'
  }
}}%%
flowchart LR
    A[Service A] --> B[Service B]
```

### Example: Dark Mode
```mermaid
%%{init: {
  'theme': 'base',
  'themeVariables': {
    'primaryColor': '#2d333b',
    'primaryTextColor': '#c9d1d9',
    'primaryBorderColor': '#444c56',
    'lineColor': '#8b949e',
    'darkMode': true
  }
}}%%
flowchart LR
    A[Dark Node] --> B[Another]
```

## Node-Level Styling

### classDef
```mermaid
flowchart LR
    classDef success fill:#4caf50,stroke:#2e7d32,color:#fff
    classDef error fill:#f44336,stroke:#c62828,color:#fff
    A[Deploy]:::success --> B{Check}
    B -->|Fail| C[Rollback]:::error
```

### Inline Style
```text
style A fill:#e1bee7,stroke:#7b1fa2,stroke-width:2px
```

## Look Variants (v11+)

| Look | Description |
|------|-------------|
| `classic` | Traditional rendering |
| `handDrawn` | Sketch-like appearance |

```mermaid
---
config:
  look: handDrawn
  theme: neutral
---
flowchart LR
    A[Sketch] --> B[Hand Drawn]
```

## Constraints

- Theme engine accepts **hex codes only** (not `red`, `blue`)
- Shadow DOM prevents external CSS overrides
- Only `base` theme supports `themeVariables`
- Changing `primaryColor` auto-updates derived colors

## Related

- [Configuration](configuration.md) - Full config options
- [Syntax Fundamentals](syntax-fundamentals.md) - classDef and inline styles
