# Pull Requests

> **Purpose**: PR workflows, reviews, merge strategies, and draft PRs
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Pull requests (PRs) are GitHub's code review mechanism. A PR proposes changes from one branch to another, enabling discussion, review, CI checks, and controlled merging. PRs are the primary collaboration workflow on GitHub.

## PR Lifecycle

```
Create Branch -> Push Commits -> Open PR -> Review -> CI Checks -> Merge -> Delete Branch
```

## Creating PRs

```bash
# Create PR with title and body
gh pr create --title "feat: add auth module" --body "Implements JWT auth"

# Create PR filling from commit messages
gh pr create --fill

# Create draft PR (not ready for review)
gh pr create --draft --title "WIP: new dashboard"

# Create PR targeting specific base branch
gh pr create --base develop --head feature/auth

# Create PR with reviewers and labels
gh pr create --reviewer alice,bob --label "enhancement"
```

## Merge Strategies

### Merge Commit

```bash
gh pr merge 123 --merge
```

- Creates a merge commit on the target branch
- Preserves complete branch history and all individual commits
- Best for: long-running feature branches where history matters

### Squash Merge

```bash
gh pr merge 123 --squash
```

- Combines all PR commits into a single commit on target
- Clean, linear history on the main branch
- Best for: feature branches with many small or WIP commits

### Rebase Merge

```bash
gh pr merge 123 --rebase
```

- Replays each commit on top of the target branch
- Linear history without merge commits
- Best for: clean, well-structured commit histories

## Decision Matrix

| Scenario | Strategy | Why |
|----------|----------|-----|
| Many WIP commits | **Squash** | Clean single commit |
| Each commit meaningful | **Rebase** | Preserve linear history |
| Long feature, need context | **Merge** | Full history preserved |
| Conventional commits for releases | **Squash** | Single commit message for changelog |
| Monorepo with multiple changes | **Merge** | Track related changes |

## Review Workflow

```bash
# Request review
gh pr edit 123 --add-reviewer alice

# Approve PR
gh pr review 123 --approve

# Request changes
gh pr review 123 --request-changes --body "Fix the SQL injection risk"

# Leave comment
gh pr review 123 --comment --body "Consider adding tests"

# View review status
gh pr checks 123
```

## Draft PRs

Draft PRs cannot be merged until marked ready. Use them for:
- Work-in-progress features needing early feedback
- Architectural proposals with code
- Triggering CI before requesting review

```bash
# Create draft
gh pr create --draft

# Mark ready for review
gh pr ready 123
```

## Auto-Merge

Enable auto-merge to merge automatically once all requirements are met:

```bash
# Enable auto-merge with squash strategy
gh pr merge 123 --auto --squash
```

Requirements: branch protection with required checks and/or reviews.

## PR Templates

Create `.github/pull_request_template.md` with sections for Summary, Test Plan, and a Checklist (tests pass, docs updated, no secrets).

## Copilot-Generated PRs (GA 2025)

The Copilot Coding Agent can autonomously create PRs from assigned issues:

- **Issue-to-PR**: Assign an issue to `@copilot`; it creates a branch, writes code, and opens a PR
- **Multi-model**: Uses GPT-5, GPT-5 mini, or Claude Opus 4.1 depending on complexity
- **Review workflow**: Copilot PRs go through the same review process as human PRs
- **Copilot CLI code-review** (Jan 2026): Run `gh copilot code-review` for AI-powered review

## Common Mistakes

| Wrong | Correct |
|-------|---------|
| Merging without CI passing | Require status checks in branch protection |
| Approving without reading diff | Review actual code changes |
| PRs open for weeks | Keep PRs small (< 400 lines), review within 24h |

## Related

- [repositories](repositories.md)
- [permissions](permissions.md)
- [../patterns/code-review](../patterns/code-review.md)
