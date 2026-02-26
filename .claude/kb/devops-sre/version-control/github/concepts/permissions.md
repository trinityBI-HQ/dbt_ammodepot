# Permissions

> **Purpose**: Roles, teams, organization settings, CODEOWNERS, and branch protection
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

GitHub's permissions model controls who can read, write, and administer repositories. It spans individual repository roles, organization teams, branch protection rules, and CODEOWNERS for code review routing. Proper configuration is essential for security and efficient collaboration.

## Repository Roles

| Role | Permissions |
|------|------------|
| **Read** | View code, issues, PRs, wiki |
| **Triage** | Manage issues and PRs (no code write) |
| **Write** | Push code, manage issues, merge PRs |
| **Maintain** | Manage repo settings (no destructive actions) |
| **Admin** | Full control including deletion and settings |

## Organization Teams

```bash
# Teams enable group-based access control
gh api orgs/my-org/teams --jq '.[].slug'

# Add team to repository
gh api repos/owner/repo/teams/backend --method PUT \
  -f permission="push"
```

| Team Pattern | Purpose |
|-------------|---------|
| `@org/backend` | Backend developers (write access) |
| `@org/platform` | Platform/infra team (admin access) |
| `@org/security` | Security reviewers (CODEOWNERS) |
| `@org/readonly` | Stakeholders (read access) |

## CODEOWNERS

The `.github/CODEOWNERS` file assigns automatic reviewers based on file paths. CODEOWNERS reviews can be **required** via branch protection.

### Syntax

```text
# .github/CODEOWNERS

# Default owner for everything
*                       @org/engineering-leads

# Backend code
/src/api/               @org/backend
/src/auth/              @org/security @org/backend

# Infrastructure
/terraform/             @org/platform
/.github/workflows/     @org/platform

# Documentation
/docs/                  @org/tech-writers
*.md                    @org/tech-writers

# Database migrations (require DBA review)
/migrations/            @org/dba-team
```

### Rules
- Last matching pattern wins (bottom of file takes priority)
- Teams use `@org/team-name` format
- Individual users use `@username`
- Patterns follow `.gitignore` syntax

## Branch Protection Rules

Configure via Settings > Branches > Add rule or via API.

### Key Settings

| Setting | Purpose | Recommended |
|---------|---------|-------------|
| **Require PR before merging** | No direct pushes | Always on for main |
| **Required approving reviews** | Min reviewers (1-6) | 1-2 for most teams |
| **Dismiss stale reviews** | Re-review on new pushes | On |
| **Require review from CODEOWNERS** | Domain expert approval | On |
| **Require status checks** | CI must pass | On |
| **Require branches to be up to date** | No stale merges | On for main |
| **Require signed commits** | GPG/SSH signature | Optional |
| **Require linear history** | No merge commits | If using squash/rebase |
| **Restrict force pushes** | Prevent history rewrite | On |
| **Include administrators** | Rules apply to admins | Recommended |

### Rulesets (Modern Alternative)

Repository rulesets are the newer replacement for branch protection rules, offering:
- Organization-wide enforcement
- Tag protection (not just branches)
- Bypass lists for specific teams/apps
- Import/export as JSON

```bash
# View rulesets
gh api repos/owner/repo/rulesets
```

## GitHub Actions Permissions

### Workflow-Level

```yaml
permissions:
  contents: read
  pull-requests: write
  issues: write
  id-token: write     # OIDC cloud auth
```

### Organization-Level
- Settings > Actions > General
- Control which actions can run (all, local only, selected)
- Set default workflow permissions (read-only recommended)
- Require approval for first-time contributors

## Environment Protection

Use `environment: production` in workflow jobs to require manual approval, wait timers, and deployment branch restrictions before deploying.

## Common Mistakes

### Wrong
- Giving Admin access to all developers
- No branch protection on main/production branches
- CODEOWNERS file without required CODEOWNERS review enabled

### Correct
- Use Write role for most developers, Admin only for leads
- Protect main: require PRs, reviews, and status checks
- Enable "Require review from Code Owners" in branch protection

## Related

- [repositories](repositories.md)
- [security](security.md)
- [../patterns/code-review](../patterns/code-review.md)
