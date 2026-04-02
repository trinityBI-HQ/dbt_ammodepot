---
paths:
  - .claude/agents/**
---

# Agent Development Rules

## Creating New Agents
1. Use `/create-agent <name>` for consistency
2. Follow the template at `.claude/agents/_template.md.example`
3. Define clear expertise boundaries — each agent owns a specific domain
4. Integrate with relevant KB domains under `.claude/kb/`

## ⚠️ Required: Automatic Invocation Trigger

Every agent description **must** include `Use PROACTIVELY when <trigger conditions>`.

```yaml
description: |
  <One-line description of what the agent does>.
  Use PROACTIVELY when <specific trigger conditions that cause auto-invocation>.
```

**Why this matters:** Claude Code reads agent descriptions to decide when to auto-invoke. Without `Use PROACTIVELY when`, the agent exists but will never fire automatically — users must reference it by name manually.

When reviewing or editing an agent file, verify this line is present. If it is missing, add it before saving.

## Required Frontmatter
```yaml
---
name: <kebab-case-name>
description: |
  <One-line description>. Use PROACTIVELY when <trigger conditions>.
  <example>...</example>
tools: [Read, Write, Edit, Bash, Grep, Glob, TodoWrite]
memory: user  # For domain agents that benefit from cross-session learning
color: <blue|green|orange|purple|red|yellow>
---
```

## Confidence Scoring
All agents must implement the Agreement Matrix:
- **0.95**: KB + MCP agree → execute confidently
- **0.85**: MCP only → proceed, note as new
- **0.75**: KB only → proceed with disclaimer
- **0.50**: Conflict → ask user to resolve

## Task Thresholds
| Category | Threshold | Action If Below |
|----------|-----------|-----------------|
| CRITICAL | 0.98 | REFUSE + explain |
| IMPORTANT | 0.95 | ASK user first |
| STANDARD | 0.90 | PROCEED + disclaimer |
| ADVISORY | 0.80 | PROCEED freely |

## MCP Validation
Agents query these servers for validation:
- **Context7**: Library documentation (`mcp__context7__query-docs`)
- **Exa**: Code examples (`mcp__exa__get_code_context_exa`)
- **Ref**: Framework docs (`mcp__Ref__ref_search_documentation`)

## Quality Checklist
Before completing any task:
- [ ] KB consulted for domain patterns
- [ ] Confidence calculated (not guessed)
- [ ] Sources cited in response
- [ ] Caveats stated if below threshold
