---
name: enrich-kb
description: Write web search or MCP findings back into the KB so the same search doesn't recur
argument-hint: "<technology> [finding or context]"
---

# Enrich KB

Capture knowledge gaps discovered during web searches or MCP queries and write them back into the relevant KB so future sessions answer from local context instead of the internet.

## Usage

```bash
/enrich-kb dbt                          # Interactive: describes finding, picks KB path
/enrich-kb snowflake "dynamic tables"  # Non-interactive: enriches Snowflake KB with dynamic tables pattern
/enrich-kb dagster --dry-run            # Preview what would be created/updated
```

---

## What It Does

1. **Locates** the correct KB path for the technology using the routing table in CLAUDE.md
2. **Determines** whether to create a new pattern file or update an existing one
3. **Writes** a concise pattern file (≤200 lines) with the captured finding + copy-paste examples
4. **Updates** the category `index.md` or `README.md` with a navigation entry

---

## Execution Steps

### Step 1: Identify Technology and KB Path

If the technology is not provided, ask:

```text
AskUserQuestion("What technology does this finding apply to?
  Examples: dbt, snowflake, dagster, airbyte, terraform, ...")
```

Then map the technology to its KB path using the routing table in `.claude/CLAUDE.md` (Lookup Policy section). If the technology is not in the routing table, identify the closest category.

```text
Read(".claude/CLAUDE.md")   # get routing table
Glob(".claude/kb/{category}/{subcategory}/{technology}/")  # confirm path exists
```

### Step 2: Gather the Finding

If no finding was provided as an argument, ask:

```text
AskUserQuestion("What did you learn from the web search or MCP query?
  Describe the pattern, command, or configuration — include enough detail
  for a copy-paste example.")
```

If context was given as an argument, use it directly.

### Step 3: Determine File Placement

Check whether the finding belongs in an existing file or needs a new one:

```text
Glob(".claude/kb/{path}/patterns/*.md")      # list existing pattern files
Read(".claude/kb/{path}/index.md")           # check what's already covered
```

**Decision rules:**
- Existing pattern file covers this topic → edit that file, add a new section
- New topic → create `.claude/kb/{path}/patterns/{topic}.md`
- Quick lookup fact (no code example) → add to `quick-reference.md` instead
- Conceptual definition → add to `concepts/{concept}.md`

### Step 4: Write the KB Entry

Create or update the file following KB conventions (from `.claude/rules/kb-development.md`):

```markdown
## {Pattern/Concept Name}

**When to use:** {one-line trigger condition}

**Why:** {rationale — what problem it solves}

```{language}
{copy-paste ready example}
```

**Gotchas:**
- {edge case 1}
- {edge case 2}
```

File size limits:
- `patterns/*.md`: ≤200 lines
- `concepts/*.md`: ≤150 lines
- `quick-reference.md`: ≤100 lines

```text
Write(".claude/kb/{path}/patterns/{topic}.md", content)
# or
Edit(".claude/kb/{path}/patterns/{existing}.md", old_string=..., new_string=...)
```

### Step 5: Update Index

Add a navigation entry so the new content is discoverable:

```text
Read(".claude/kb/{path}/index.md")
Edit(".claude/kb/{path}/index.md", ...)   # add entry under patterns section
```

If category `README.md` exists, add or update the technology description there too.

### Step 6: Report

```text
ENRICH KB RESULTS
━━━━━━━━━━━━━━━━━

Technology : {technology}
KB Path    : .claude/kb/{path}/
Action     : {Created | Updated} {filename}
Index      : {updated | no change needed}

Content preview:
  {first heading and first 2 lines of the written content}

Next time this topic comes up, the KB will answer it directly.

━━━━━━━━━━━━━━━━━
```

---

## Flags

| Flag | Description |
|------|-------------|
| `--dry-run` | Show what would be created/updated without writing files |

---

## Examples

```bash
# Capture a Snowflake dynamic tables pattern found via web search
/enrich-kb snowflake "dynamic tables — incremental refresh syntax and lag config"

# Capture a dbt unit test pattern after MCP lookup
/enrich-kb dbt "unit tests with overrides for ref() and source()"

# Interactive — will ask for technology and finding
/enrich-kb

# Preview without writing
/enrich-kb dagster "partitioned asset backfills" --dry-run
```

---

## Notes

- Run this immediately after a web search or MCP query fills a knowledge gap — while context is fresh
- The finding should be general enough to apply to future questions, not project-specific business logic
- If the KB already covers the topic well, this skill is a no-op (report "KB already covers this")
- After enriching, the next invocation of the relevant agent will load the updated KB content

---

## See Also

- `.claude/rules/kb-development.md` — file size limits, required structure, validation
- `.claude/CLAUDE.md` — Lookup Policy section with KB routing table
- `/create-kb` — for adding an entirely new technology KB
