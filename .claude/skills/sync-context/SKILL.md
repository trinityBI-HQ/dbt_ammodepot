---
name: sync-context
description: Sync project context to CLAUDE.md by scanning .claude/ structure and codebase patterns
argument-hint: "[--section <name>] [--dry-run]"
---

# Sync Context

Scans the current project's `.claude/` structure and codebase, then updates `CLAUDE.md` with accurate counts, tables, and references. Works in any project that has a `.claude/` folder.

## Usage

```bash
/sync-context                    # Full scan and update
/sync-context --section agents   # Update specific section only
/sync-context --dry-run          # Preview changes without saving
```

---

## What It Scans

The skill auto-detects which components exist and only generates sections for what's present.

| Component | How Detected | CLAUDE.md Section Generated |
|-----------|-------------|----------------------------|
| `agents/` | `Glob(".claude/agents/**/*.md")` excluding `_*` | Agents table (category, count, names) |
| `kb/` | `Glob(".claude/kb/**/index.md")` | Knowledge Base table (category, count, technologies) |
| `rules/` | `Glob(".claude/rules/*.md")` | Rules list (name, path scope, purpose) |
| `docs/` | `Glob(".claude/docs/*.md")` | Delivery Standards table (doc, scope) |
| `skills/` | `Glob(".claude/skills/*/SKILL.md")` | Skills list (grouped by function) |
| `dev/`, `sdd/` | Directory existence check | Mentioned in layout if present |
| Project code | `Glob("**/*.py")`, `Glob("**/*.sql")`, `Glob("**/dbt_project.yml")` | Project-specific context (tech stack, structure) |

---

## Execution Steps

### Step 1: Read Existing CLAUDE.md

```text
Read(".claude/CLAUDE.md")
```

Parse into sections by `##` headers. Identify which sections exist and their content.

### Step 2: Scan .claude/ Components

Run these scans in parallel:

```text
# Agents: count and categorize by parent folder
Glob(".claude/agents/**/*.md")
→ Group by directory (code-quality/, data-engineering/, workflow/, etc.)
→ Extract name from frontmatter

# KB: count technologies by category
Glob(".claude/kb/**/index.md")
→ Group by top-level category (data-engineering/, ai-ml/, cloud/, etc.)
→ Extract technology name from parent folder

# Rules: list with path scope
Glob(".claude/rules/*.md")
→ Read first 5 lines of each for paths: frontmatter
→ Extract rule name and scope

# Docs: list delivery standards
Glob(".claude/docs/*.md")
→ Extract title from first # heading

# Skills: list slash commands
Glob(".claude/skills/*/SKILL.md")
→ Extract name and description from frontmatter
```

### Step 3: Scan Project Code (if present)

Only runs if the project has source code (not a pure KB repo):

```text
# Detect tech stack
Glob("**/dbt_project.yml")      → dbt project (extract name, profile)
Glob("**/pyproject.toml")       → Python project (extract deps)
Glob("**/dagster_orchestration") → Dagster orchestration
Glob("**/*.sql")                → SQL models (count by layer)
Glob(".github/workflows/*.yml") → CI/CD workflows
```

### Step 4: Generate Updated Sections

Build each section from scan results. Use these templates:

**Directory Layout:**
```markdown
## Directory Layout

\```
.claude/
├── agents/       # {agent_count} specialized domain experts ({category_count} categories)
├── skills/       # {skill_count} slash commands
├── rules/        # {rule_count} path-scoped instruction files
├── kb/           # {kb_count} technology knowledge bases ({kb_category_count} categories)
├── docs/         # {doc_count} delivery standards documents
{├── dev/          # Dev loop system (only if exists)}
{├── sdd/          # SDD workflow artifacts (only if exists)}
└── CLAUDE.md     # This file (global context)
\```
```

**Agents table:**
```markdown
## Agents ({agent_count} across {category_count} categories)

| Category | Count | Key Agents |
|----------|-------|------------|
| {category} | {count} | {agent_names comma-separated} |
```

**KB table:**
```markdown
## Knowledge Base ({kb_count} technologies in {kb_category_count} categories)

| Category | Count | Key Technologies |
|----------|-------|------------------|
| {category} | {count} | {technology_names comma-separated} |
```

**Delivery Standards table** (only if `.claude/docs/` exists):
```markdown
## Delivery Standards ({doc_count} documents in `.claude/docs/`)

| Doc | Scope |
|-----|-------|
| `{filename}` | {first_heading_or_description} |
```

**Rules list:**
```markdown
## Rules ({rule_count} path-scoped files)

| Rule | Path Scope | Purpose |
|------|-----------|---------|
| `{filename}` | `{paths_from_frontmatter}` | {first_heading} |
```

**Skills list:**
```markdown
## Skills ({skill_count} slash commands)

**Core:** {skills_grouped_by_function}
**Development:** ...
**Workflow (SDD):** ...
```

### Step 5: Apply Update Rules

| Section | Update Mode | Behavior |
|---------|------------|----------|
| Project Overview | **Preserve** | Never auto-modify (manual context) |
| Directory Layout | **Replace** | Regenerate from scan |
| Agents | **Replace** | Regenerate from scan |
| Knowledge Base | **Replace** | Regenerate from scan |
| Delivery Standards | **Replace** | Regenerate from scan |
| Rules | **Replace** | Regenerate from scan |
| Skills | **Replace** | Regenerate from scan |
| Key Patterns | **Preserve** | Manual (confidence scoring, git workflow, MCP) |
| Quick Reference | **Preserve** | Manual (curated task→agent mapping) |
| Any project-specific sections | **Preserve** | Never touch sections not in the template |

**Rule:** If a section exists in CLAUDE.md but wasn't generated by the scan (e.g., "Architecture Overview" in a dbt project), preserve it untouched.

### Step 6: Write or Preview

If `--dry-run`:
```text
SYNC-CONTEXT DRY RUN
━━━━━━━━━━━━━━━━━━━━

Scanned:
  Agents:  {count} across {categories} categories
  KB:      {count} technologies in {categories} categories
  Rules:   {count} path-scoped files
  Docs:    {count} delivery standards
  Skills:  {count} slash commands

Sections to update:
  • Directory Layout: UPDATE (agents count changed: {old} → {new})
  • Agents: UPDATE (removed 3, structure changed)
  • Knowledge Base: NO CHANGE
  • Delivery Standards: UPDATE (1 new doc added)
  • Skills: NO CHANGE

Sections preserved:
  • Project Overview
  • Key Patterns
  • Quick Reference

━━━━━━━━━━━━━━━━━━━━
Run without --dry-run to apply changes.
```

If writing:
```text
Edit(".claude/CLAUDE.md", old_string=..., new_string=...)
```

Use targeted Edit calls per section — never rewrite the entire file.

---

## Flags

| Flag | Description |
|------|-------------|
| `--dry-run` | Preview changes without saving |
| `--section {name}` | Update only: `agents`, `kb`, `rules`, `docs`, `skills`, `layout` |
| `--verbose` | Show detailed scan results |

---

## When to Run

- After adding/removing agents or KB entries
- After creating new rules or docs files
- After adding new skills
- Before `/sync-repos` (ensures CLAUDE.md is current before pushing)
- After any session that modifies `.claude/` structure

---

## Notes

- **Lab vs downstream**: In claude-code-lab this scans the full KB/agent roster. In downstream projects (after `/sync-repos`), it scans whatever subset was synced.
- **Project-specific sections**: Any `##` section in CLAUDE.md that the skill doesn't recognize is preserved. This protects project-specific context (Architecture, Snowflake Objects, Deployment, etc.).
- **No code analysis for pure KB repos**: If no `*.py`, `*.sql`, or project config files exist, Step 3 is skipped entirely.
