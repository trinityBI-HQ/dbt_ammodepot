# Create Agent Command

> Create a new specialized subagent from the standard template.

## Usage

```
/create-agent <AGENT-NAME>
```

**Examples**: `/create-agent redis-expert`, `/create-agent api-designer`, `/create-agent security-auditor`

## What Happens

1. **Gathers requirements** — asks about capabilities, domain, and tools needed
2. **Validates naming** — ensures kebab-case and no conflicts
3. **Generates agent** — creates file from template with full structure
4. **Reports completion** — shows file location and capabilities

## Options

| Command | Action |
|---------|--------|
| `/create-agent <name>` | Create new agent interactively |
| `/create-agent --list` | List all existing agents |
| `/create-agent --template` | Show the agent template |

## Interactive Questions

When creating an agent, you'll be asked:

1. **Identity** — What is this agent's primary purpose?
2. **Domain** — What knowledge area does it specialize in?
3. **Capabilities** — What are the 3-5 main things it can do?
4. **Tools** — Which tools does it need access to?
5. **KB Integration** — Does it have a corresponding KB domain?
6. **Threshold** — What's the default confidence threshold? (0.90/0.95/0.98)

## Agent Structure

Generated agents follow this structure:

```markdown
---
name: {agent-name}
description: |
  {description with examples}
tools: [Read, Write, Edit, ...]
color: {blue|green|orange|purple|red|yellow}
---

# {Agent Name}

> **Identity:** ...
> **Domain:** ...
> **Default Threshold:** ...

## Quick Reference
## Validation System
## Execution Template
## Context Loading
## Knowledge Sources
## Capabilities
## Response Formats
## Error Recovery
## Anti-Patterns
## Quality Checklist
## Extension Points
## Changelog
## Remember
```

## File Location

Agents are created in: `.claude/agents/{agent-name}.md`

For categorized agents, use subdirectories matching the hierarchy:
- `.claude/agents/ai-ml/` — LLM, extraction, monitoring agents
- `.claude/agents/cloud/aws/` — AWS Lambda, deployment agents
- `.claude/agents/cloud/gcp/` — GCP Cloud Run, pipeline agents
- `.claude/agents/code-quality/` — Review, testing, documentation agents
- `.claude/agents/communication/` — Explanation, analysis, planning agents
- `.claude/agents/data-engineering/{subcategory}/` — Spark, Databricks, dbt, Dagster agents
- `.claude/agents/devops-sre/` — CI/CD, infrastructure agents
- `.claude/agents/dev/` — Dev loop agents
- `.claude/agents/exploration/` — Codebase analysis agents
- `.claude/agents/workflow/` — SDD workflow agents

## See Also

- **Template**: `.claude/agents/_template.md.example`
- **Existing Agents**: `.claude/agents/`
- **KB Domains**: `.claude/kb/`

## Execution Instructions

When this command is invoked:

1. **If `--list` flag**: List all `.md` files in `.claude/agents/` (excluding template)

2. **If `--template` flag**: Display the contents of `.claude/agents/_template.md.example`

3. **If `<name>` provided**:

   a. Validate the name is kebab-case (lowercase with hyphens)

   b. Check if agent already exists at `.claude/agents/{name}.md`

   c. Ask the user these questions using AskUserQuestion:
      - What is the primary purpose of this agent? (free text)
      - What knowledge domain does it cover? (free text)
      - What are 3-5 capabilities it should have? (free text)
      - Which tools should it have access to? (multi-select from common tools)
      - Does it have a corresponding KB domain in `.claude/kb/`? (yes/no + which one)
      - What confidence threshold? (0.90 Standard / 0.95 Important / 0.98 Critical)
      - What color for the agent? (blue/green/orange/purple/red/yellow)

   d. Read the template from `.claude/agents/_template.md.example`

   e. Generate the agent file by filling in the template with:
      - Agent name and description with examples
      - Identity, domain, and threshold
      - Capabilities section with detailed processes
      - KB integration if applicable
      - Appropriate tools list
      - Domain-specific anti-patterns and quality checks

   f. Write the file to `.claude/agents/{name}.md`

   g. Report success with the file path and summary of capabilities

4. **If no argument**: Show usage help and prompt for agent name
