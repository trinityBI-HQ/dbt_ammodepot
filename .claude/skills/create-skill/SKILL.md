---
name: create-skill
description: Create a new slash command from the standard skill template
argument-hint: "<skill-name>"
---

# Create Skill

Create a new slash command skill from the standard template with interactive configuration.

## Usage

```bash
/create-skill <skill-name>         # Create new skill interactively
/create-skill --list                # List all existing skills
/create-skill --template            # Show the skill template
```

**Examples**: `/create-skill deploy-staging`, `/create-skill validate-schema`, `/create-skill cost-report`

---

## What It Does

1. **Validates** — checks naming and conflicts with existing skills
2. **Gathers requirements** — asks about purpose, arguments, and behavior
3. **Generates** — creates SKILL.md from template with filled-in sections
4. **Reports** — shows file location and invocation syntax

---

## Execution Steps

### Step 1: Validate

```text
# Check name is kebab-case
Validate: {name} matches ^[a-z][a-z0-9-]+$

# Check skill doesn't already exist
Glob(".claude/skills/{name}/SKILL.md")
→ If exists: "Skill '{name}' already exists at .claude/skills/{name}/SKILL.md"
```

### Step 2: Gather Requirements

Ask the user these questions using AskUserQuestion:

1. **Purpose** — What does this skill do? (free text)
2. **Arguments** — What arguments does it accept? (free text, e.g., `<file> [--verbose]`)
3. **Category** — What type of skill is this?
   - Options: `workflow` (multi-step process), `generator` (creates files), `analyzer` (reads and reports), `utility` (simple action)
4. **Writes files?** — Does this skill create or modify files?
   - If yes: `--dry-run` flag is automatically included
5. **Related** — Any related skills, agents, or docs? (free text, optional)

### Step 3: Generate

```text
# Read template
Read(".claude/skills/_template.md.example")

# Create skill directory
Bash("mkdir -p .claude/skills/{name}")

# Generate SKILL.md with:
# - Frontmatter: name, description, argument-hint from answers
# - Usage section with invocation patterns
# - Execution Steps tailored to the category:
#   - workflow: multi-step with validation → process → verify
#   - generator: input → generate → write → report
#   - analyzer: scan → analyze → format → output
#   - utility: validate → execute → confirm
# - Flags table (always includes --dry-run if skill writes files)
# - See Also from related answer

Write(".claude/skills/{name}/SKILL.md", content)
```

### Step 4: Report

```text
CREATE-SKILL RESULTS
━━━━━━━━━━━━━━━━━━━━

Created: .claude/skills/{name}/SKILL.md

Invocation:
  /{name}
  /{name} {argument-hint}

Category: {category}
Flags: {flags}

Next steps:
  1. Review and customize the generated SKILL.md
  2. Test with: /{name} --dry-run
  3. Run /sync-context to update CLAUDE.md

━━━━━━━━━━━━━━━━━━━━
```

---

## Flags

| Flag | Description |
|------|-------------|
| `--list` | List all existing skills with descriptions |
| `--template` | Display the skill template |

---

## Execution Instructions

When this command is invoked:

1. **If `--list` flag**: List all directories in `.claude/skills/` (excluding `_template*`), read each SKILL.md frontmatter, display name + description table.

2. **If `--template` flag**: Display contents of `.claude/skills/_template.md.example`.

3. **If `<name>` provided**:

   a. Validate name is kebab-case (lowercase, hyphens, starts with letter)

   b. Check `.claude/skills/{name}/SKILL.md` doesn't already exist

   c. Ask interactive questions per Step 2

   d. Read template from `.claude/skills/_template.md.example`

   e. Generate SKILL.md by filling template with answers:
      - Replace `{skill-name}` with name
      - Replace `{Skill Title}` with title-cased name
      - Fill Usage section with argument patterns
      - Generate 2-4 Execution Steps based on category
      - Add `--dry-run` to Flags if skill writes files
      - Fill See Also from related answer

   f. Write to `.claude/skills/{name}/SKILL.md`

   g. Report success

4. **If no argument**: Show usage help and prompt for skill name

---

## Notes

- Skill names must be unique across the project
- Skills are synced to downstream projects via `/sync-repos`
- See `.claude/rules/skill-development.md` for conventions and size guidelines

## See Also

- **Template**: `.claude/skills/_template.md.example`
- **Rules**: `.claude/rules/skill-development.md`
- **Existing skills**: `.claude/skills/`
- **Agent creation**: `/create-agent`
- **KB creation**: `/create-kb`
