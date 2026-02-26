# Code Review

> **Purpose**: PR review best practices, CODEOWNERS configuration, required reviews, and auto-merge
> **MCP Validated**: 2026-02-19

## When to Use

- Establishing code review standards for a team or organization
- Configuring CODEOWNERS for automatic reviewer assignment
- Setting up branch protection for required reviews
- Enabling auto-merge for trusted workflows

## CODEOWNERS Configuration

### Setup

Create `.github/CODEOWNERS` (must be in `.github/`, root, or `docs/`):

```text
# Default: engineering leads review everything
*                           @org/engineering-leads

# Backend
/src/api/                   @org/backend-team
/src/models/                @org/backend-team @org/dba

# Frontend
/src/components/            @org/frontend-team
/src/styles/                @org/frontend-team

# Infrastructure
/terraform/                 @org/platform
/.github/workflows/         @org/platform
/Dockerfile                 @org/platform

# Security-critical paths
/src/auth/                  @org/security-team
/src/crypto/                @org/security-team

# Data pipelines
/dbt/                       @org/data-engineering
/dagster/                   @org/data-engineering

# Documentation (lower barrier)
/docs/                      @org/tech-writers
*.md                        @org/tech-writers
```

### Best Practices

| Practice | Why |
|----------|-----|
| Last pattern wins | Put specific paths after general ones |
| Use teams, not individuals | Resilient to people leaving |
| Keep CODEOWNERS in `.github/` | Standard location, easy to find |
| Protect CODEOWNERS itself | Add `.github/CODEOWNERS @org/leads` |
| Review CODEOWNERS in onboarding | New devs understand review routing |

## Branch Protection for Reviews

### Recommended Settings for `main`

```text
[x] Require a pull request before merging
    [x] Required approving reviews: 1
    [x] Dismiss stale pull request approvals when new commits are pushed
    [x] Require review from Code Owners
[x] Require status checks to pass before merging
    [x] Require branches to be up to date before merging
    Status checks: CI, lint, test
[x] Restrict who can push to matching branches
```

### Configuration via gh CLI

```bash
# View branch protection rules
gh api repos/owner/repo/branches/main/protection

# Note: Branch protection API is complex --
# consider using Terraform for declarative management.
# See: devops-sre/iac/terraform/ KB
```

## Review Process Best Practices

### For Authors

| Practice | Details |
|----------|---------|
| Keep PRs small | < 400 lines changed (ideal: < 200) |
| Write descriptive PR body | Summarize why, not just what |
| Self-review before requesting | Catch obvious issues yourself |
| Link to issue | `Closes #42` for traceability |
| Add screenshots for UI changes | Visual context for reviewers |
| Respond to all comments | Resolve or explain, never ignore |

### For Reviewers

| Practice | Details |
|----------|---------|
| Review within 24 hours | Blocked PRs slow the team |
| Focus on logic, not style | Automate style with linters |
| Ask questions, don't just command | "Why X?" is better than "Do Y" |
| Approve with minor comments | Don't block on nitpicks |
| Use suggestion blocks | GitHub's suggestion feature for small fixes |

### Suggestion Blocks

```markdown
```suggestion
def calculate_total(items: list[Item]) -> Decimal:
    return sum(item.price for item in items)
```
```

Reviewers can suggest exact code changes that authors accept with one click.

## Auto-Merge

Automatically merge PRs when all requirements are met:

```bash
# Enable auto-merge on a PR (squash strategy)
gh pr merge 123 --auto --squash

# Requirements must be met:
# - All required status checks pass
# - All required reviews approved
# - Branch is up to date (if required)
# - No merge conflicts
```

### When to Enable Auto-Merge

| Scenario | Auto-Merge | Why |
|----------|-----------|-----|
| Dependabot PRs | Yes | Automated, low risk |
| Small config changes | Yes | Reviewed, low risk |
| Feature PRs | Case by case | Complex changes need attention |
| Security patches | Yes | Speed matters |
| Refactoring PRs | No | Potential for subtle issues |

### Dependabot Auto-Merge

```yaml
# .github/workflows/dependabot-auto-merge.yml
name: Auto-merge Dependabot
on: pull_request

permissions:
  contents: write
  pull-requests: write

jobs:
  auto-merge:
    if: github.actor == 'dependabot[bot]'
    runs-on: ubuntu-latest
    steps:
      - name: Auto-merge minor/patch updates
        run: gh pr merge --auto --squash "$PR_URL"
        env:
          PR_URL: ${{ github.event.pull_request.html_url }}
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Copilot Code Review Agent (Jan 2026)

Use `gh copilot code-review` (or `--pr 123`) for AI-powered first-pass review. Copilot analyzes diffs for bugs, security issues, and style violations, posting inline comments. Use as a complement to human review, combined with CODEOWNERS for domain-specific oversight.

## Review Checklist Template

Add to `.github/pull_request_template.md` a checklist covering: style compliance, tests, docs updates, no secrets, error handling, and performance considerations.

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|--------------|---------|-----|
| Rubber-stamp approvals | Bugs slip through | Enforce meaningful reviews |
| Reviews taking > 48 hours | Author context lost | Set team SLO for review time |
| Reviewing 1000+ line PRs | Reviewer fatigue | Enforce PR size limits |
| Only senior devs review | Bottleneck | Rotate reviewers, pair juniors |
| No CODEOWNERS | Random reviewer assignment | Define ownership explicitly |
| Blocking on style nits | Slow velocity | Use automated formatters |

## Related

- [branching-strategies](branching-strategies.md)
- [ci-cd-workflows](ci-cd-workflows.md)
- [../concepts/permissions](../concepts/permissions.md)
- [../concepts/pull-requests](../concepts/pull-requests.md)
