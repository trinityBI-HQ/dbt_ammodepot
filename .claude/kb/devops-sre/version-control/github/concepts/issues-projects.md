# Issues and Projects

> **Purpose**: Issue tracking, labels, milestones, and GitHub Projects v2
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

GitHub Issues track bugs, features, and tasks. GitHub Projects v2 provides flexible project management with table, board, and roadmap views. Together they form a lightweight but powerful project management system integrated directly with code.

## Issues

### Creating Issues

```bash
# Simple issue
gh issue create --title "Fix login timeout" --label "bug"

# Issue with body and assignee
gh issue create --title "Add dark mode" \
  --body "Support system-level dark mode preference" \
  --assignee "@me" --label "enhancement" --milestone "v2.0"

# Issue from template
gh issue create --template "bug_report.md"
```

### Issue Templates

Create `.github/ISSUE_TEMPLATE/bug_report.yml` with YAML form syntax: define `name`, `description`, `labels`, and a `body` array of `textarea`, `input`, and `dropdown` fields with optional `validations.required: true`.

### Labels

| Label | Color | Use |
|-------|-------|-----|
| `bug` | Red | Something is broken |
| `enhancement` | Blue | New feature request |
| `documentation` | Green | Docs improvement |
| `good first issue` | Purple | Beginner-friendly |
| `breaking-change` | Orange | Backwards-incompatible |
| `priority: high` | Red | Urgent attention |

```bash
# Create custom label
gh label create "priority: high" --color FF0000 --description "Urgent"

# List labels
gh label list
```

### Milestones

Group issues into release milestones:

```bash
# Create milestone
gh api repos/owner/repo/milestones \
  -f title="v2.0" -f due_on="2026-06-01T00:00:00Z"

# Assign issue to milestone
gh issue edit 42 --milestone "v2.0"
```

### Copilot Coding Agent (GA 2025)

Assign issues to `@copilot` for autonomous code generation: `gh issue edit 42 --add-assignee "@copilot"`. Copilot creates a branch, writes code, runs tests, and opens a PR.

### Managing Issues

```bash
# List open issues
gh issue list

# Filter by label and assignee
gh issue list --label "bug" --assignee "@me"

# Close with comment
gh issue close 42 --comment "Fixed in #55"

# Link PR to issue (auto-close on merge)
gh pr create --title "fix: resolve #42 login timeout"
```

## GitHub Projects v2

### Overview

Projects v2 is a flexible planning tool that connects to issues and PRs across repositories.

### Views

| View | Best For |
|------|----------|
| **Table** | Spreadsheet-like with custom fields, sorting, filtering |
| **Board** | Kanban with status columns (To Do, In Progress, Done) |
| **Roadmap** | Timeline view with date-based planning |

### Custom Fields

| Field Type | Example Use |
|------------|-------------|
| **Text** | Notes, descriptions |
| **Number** | Story points, priority score |
| **Date** | Target date, sprint end |
| **Single Select** | Status, priority, team |
| **Iteration** | Sprint tracking |

### Automation

Projects support built-in automations:
- Auto-add items when issues/PRs are created
- Auto-set status when PRs are merged
- Auto-archive completed items after N days
- Auto-add items matching filters

### CLI Access

```bash
# List projects
gh project list

# View project items
gh project item-list 1

# Add issue to project
gh project item-add 1 --owner "@me" --url "https://github.com/owner/repo/issues/42"
```

## Linking Issues and PRs

```markdown
<!-- In PR description -- auto-closes on merge -->
Closes #42
Fixes #43
Resolves #44
```

## Common Mistakes

**Wrong**: Issues without labels, no issue templates, orphaned issues never linked to PRs.
**Correct**: Label taxonomy in CONTRIBUTING.md, issue forms with required fields, link every PR to an issue.

## Related

- [repositories](repositories.md)
- [permissions](permissions.md)
