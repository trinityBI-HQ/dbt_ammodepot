---
paths:
  - ".claude/skills/**/*.md"
---

# Skill Development Rules

## Structure

Each skill lives in its own folder with a single file:
```
.claude/skills/{skill-name}/SKILL.md
```

## Required Frontmatter

```yaml
---
name: {kebab-case-name}
description: {One-line description}
argument-hint: "{usage pattern with [optional] and <required> args}"
---
```

## Required Sections

Every skill MUST have at minimum:
1. **Title** (`# {Skill Title}`) — one-sentence purpose
2. **Usage** — code block showing invocation patterns
3. **Execution Steps** — numbered steps with tool call examples
4. **Flags** — table of supported flags (at minimum `--dry-run` if the skill writes files)

## Optional Sections

- **What It Does** — high-level bullet summary (useful for complex skills)
- **Examples** — concrete invocation examples
- **Notes** — constraints, edge cases, prerequisites
- **See Also** — related skills, agents, rules, or docs

## Conventions

- **Naming**: kebab-case, verb-noun preferred (e.g., `create-agent`, `sync-repos`)
- **Folder**: `.claude/skills/{name}/SKILL.md` — one folder per skill, file always named `SKILL.md`
- **Idempotent**: Skills should be safe to run multiple times without side effects
- **Dry-run**: Any skill that writes files should support `--dry-run`
- **Output format**: Use the box-drawing format for results:
  ```text
  {SKILL-NAME} RESULTS
  ━━━━━━━━━━━━━━━━━━━━
  {content}
  ━━━━━━━━━━━━━━━━━━━━
  ```
- **Tool calls**: Show as `ToolName("args")` in execution steps (not bash commands)
- **No code execution**: Skills are prompt instructions, not scripts. They guide Claude Code's tool usage.

## Size Guidelines

- **Simple skills** (memory, create-agent): 100-150 lines
- **Standard skills** (sync-context, audit): 150-250 lines
- **Complex skills** (create-pr, review, dev): 250-400 lines
- **Maximum**: 400 lines — if larger, split into sub-steps or reference external docs

## Creating New Skills

Use `/create-skill <name>` for consistency, or copy from `.claude/skills/_template.md.example`.

## Template

`.claude/skills/_template.md.example` — standard skill structure with placeholder sections.
