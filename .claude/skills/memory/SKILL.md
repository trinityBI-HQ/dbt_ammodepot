---
name: memory
description: Save valuable insights from the current session to the auto-memory system
argument-hint: "[note]"
---

# Memory

Save session insights as properly-typed memory files with MEMORY.md index updates.

## Usage

```bash
/memory                           # Interactive: asks what to save and type
/memory "specific note to save"   # Save with context, asks for type
```

---

## What It Does

1. **Identifies** valuable insights from the current session (or uses the provided note)
2. **Asks** which memory type to use (user, feedback, project, reference)
3. **Writes** a memory file with proper frontmatter to the auto-memory directory
4. **Updates** MEMORY.md index with a one-line pointer

---

## Memory Types

| Type | When to Save | Example |
|------|-------------|---------|
| `user` | Learn about the user's role, preferences, knowledge | "Victor runs a multi-client data practice" |
| `feedback` | User corrects or confirms an approach | "Don't remove KBs — user experiments with AI" |
| `project` | Learn about ongoing work, goals, decisions | "Repo purpose is institutional memory, not code" |
| `reference` | Discover external resources and their purpose | "Pipeline bugs tracked in Linear project INGEST" |

---

## Execution Steps

### Step 1: Identify What to Save

If a note is provided, use it as context. Otherwise, scan the conversation for:
- Decisions with non-obvious rationale
- User corrections or confirmations of approach
- Project context not derivable from code
- External resource locations

**Don't save:**
- Code patterns (derivable from reading the code)
- Git history (use `git log`)
- Debugging solutions (the fix is in the code)
- Anything already in CLAUDE.md
- Ephemeral task details

### Step 2: Ask Memory Type

Use AskUserQuestion to confirm the type and content:

```text
What type of memory is this?
  - user: About the user's role, preferences, or knowledge
  - feedback: Guidance on how to approach work (corrections or confirmations)
  - project: Ongoing work, goals, decisions, context
  - reference: Pointers to external systems or resources
```

### Step 3: Determine File Location

The auto-memory directory is at:
```text
~/.claude/projects/{project-hash}/memory/
```

Find it by reading the existing MEMORY.md path from conversation context, or locate it:
```text
Glob("~/.claude/projects/*/memory/MEMORY.md")
```

### Step 4: Write Memory File

Create a file with kebab-case name: `{type}_{topic}.md`

```markdown
---
name: {Memory Name}
description: {One-line description — used to decide relevance in future conversations}
type: {user|feedback|project|reference}
---

{Memory content}

{For feedback/project types, include:}
**Why:** {the reason}
**How to apply:** {when/where this guidance kicks in}
```

```text
Write("~/.claude/projects/.../memory/{type}_{topic}.md", content)
```

### Step 5: Update MEMORY.md Index

Add a one-line pointer under the correct `##` heading:

```text
Read("~/.claude/projects/.../memory/MEMORY.md")

# Find the ## {Type} section and append:
- [{Title}]({filename}.md) — {one-line hook, under 150 chars}

Edit("MEMORY.md", old_string=..., new_string=...)
```

If the type section doesn't exist yet, create it.

### Step 6: Report

```text
MEMORY SAVED
━━━━━━━━━━━━

Type: {type}
File: {filename}.md
Index: MEMORY.md updated

Content preview:
  {first 2 lines of memory content}

━━━━━━━━━━━━
```

---

## Flags

| Flag | Description |
|------|-------------|
| `--list` | Show current MEMORY.md contents |

---

## What NOT to Save

Per the auto-memory system rules:

- Code patterns, conventions, architecture, file paths — derivable from reading code
- Git history, recent changes — `git log` / `git blame` are authoritative
- Debugging solutions — the fix is in the code; the commit message has context
- Anything already in CLAUDE.md files
- Ephemeral task details or current conversation context

If the user asks to save something that falls in these categories, ask what was *surprising* or *non-obvious* about it — that's the part worth keeping.

---

## Notes

- Memory files accumulate over time — check for duplicates before creating
- Update existing memories rather than creating new ones when the topic matches
- Convert relative dates to absolute when saving (e.g., "Thursday" → "2026-03-30")
- MEMORY.md index should stay under 200 lines (truncated beyond that)

## See Also

- Auto-memory system documentation (built into Claude Code)
- `.claude/rules/skill-development.md` — skill conventions
