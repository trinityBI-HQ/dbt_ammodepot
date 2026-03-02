# GitHub Quick Reference

> Fast lookup tables for gh CLI and common GitHub workflows.

## gh CLI -- Repository & PR Commands

| Command | Purpose |
|---------|---------|
| `gh repo clone owner/repo` | Clone a repository |
| `gh repo create name --public` | Create new repository |
| `gh pr create --title "msg" --body "desc"` | Create pull request |
| `gh pr list` | List open PRs |
| `gh pr view 123` | View PR details |
| `gh pr checkout 123` | Check out a PR locally |
| `gh pr merge 123 --squash` | Squash-merge a PR |
| `gh pr review 123 --approve` | Approve a PR |
| `gh pr diff 123` | Show PR diff |

## gh CLI -- Issues & Projects

| Command | Purpose |
|---------|---------|
| `gh issue create --title "bug" --label "bug"` | Create issue |
| `gh issue list --label "bug"` | List issues by label |
| `gh issue close 42` | Close an issue |
| `gh project list` | List GitHub Projects |
| `gh project view 1` | View project board |

## gh CLI -- Copilot Agents (Jan 2026+)

| Command | Purpose |
|---------|---------|
| `gh copilot code-review` | AI-powered code review on current changes |
| `gh copilot plan` | Generate an implementation plan |
| `gh copilot task` | Execute a coding task autonomously |
| `gh copilot explore` | Explore and understand a codebase |

## gh CLI -- Actions & Releases

| Command | Purpose |
|---------|---------|
| `gh run list` | List workflow runs |
| `gh run view 12345` | View run details |
| `gh run watch 12345` | Watch run in real-time |
| `gh run rerun 12345` | Re-run a failed workflow |
| `gh release create v1.0.0 --generate-notes` | Create release |
| `gh release list` | List releases |
| `gh aw list` | List agentic workflows (Preview) |

## gh CLI -- API & Advanced

| Command | Purpose |
|---------|---------|
| `gh api repos/owner/repo/pulls` | Direct API call |
| `gh api graphql -f query='{...}'` | GraphQL query |
| `gh secret set NAME --body "value"` | Set Actions secret |
| `gh variable set NAME --body "value"` | Set Actions variable |
| `gh auth login` | Authenticate gh CLI |
| `gh alias set co 'pr checkout'` | Create command alias |

## Merge Strategies

| Strategy | When to Use | Result |
|----------|-------------|--------|
| **Merge commit** | Preserve full history | Merge commit on target |
| **Squash merge** | Clean history, many small commits | Single commit on target |
| **Rebase merge** | Linear history, clean commits | Rebased commits on target |

## Branch Protection Checklist

| Setting | Purpose |
|---------|---------|
| Require PR before merging | No direct pushes to main |
| Required approvals (1-6) | Minimum reviewers |
| Dismiss stale reviews | Re-review after new pushes |
| Require status checks | CI must pass before merge |
| Require CODEOWNERS review | Domain experts must approve |
| Restrict force pushes | Prevent history rewriting |

## Workflow Trigger Events

| Event | Fires When |
|-------|------------|
| `push` | Commits pushed to branch |
| `pull_request` | PR opened, synced, reopened |
| `schedule` | Cron schedule (e.g., nightly) |
| `workflow_dispatch` | Manual trigger via UI/API |
| `release` | Release published |
| `issue_comment` | Comment on issue or PR |

## Common Pitfalls

| Problem | Solution |
|---------|----------|
| Secrets in code | Enable secret scanning + push protection |
| Stale dependencies | Enable Dependabot alerts + auto-PRs |
| No CI on PRs | Add branch protection + required checks |
| Long-lived branches | Use trunk-based or GitHub Flow |
| Missing CODEOWNERS | Add `.github/CODEOWNERS` file |

See also: `index.md`, `patterns/ci-cd-workflows.md`, `patterns/branching-strategies.md`