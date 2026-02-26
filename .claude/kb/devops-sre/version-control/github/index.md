# GitHub Knowledge Base

> **Purpose**: Cloud-based Git hosting platform with PR workflows, Actions CI/CD, security scanning, and project management
> **MCP Validated**: 2026-02-19

## Quick Navigation

### Concepts (< 150 lines each)

| File | Purpose |
|------|---------|
| [concepts/repositories.md](concepts/repositories.md) | Repos, branches, commits, tags, releases |
| [concepts/pull-requests.md](concepts/pull-requests.md) | PRs, reviews, merge strategies, draft PRs |
| [concepts/actions.md](concepts/actions.md) | Workflows, jobs, steps, runners, marketplace |
| [concepts/issues-projects.md](concepts/issues-projects.md) | Issues, labels, milestones, GitHub Projects v2 |
| [concepts/security.md](concepts/security.md) | Dependabot, code scanning, secret scanning, GHAS |
| [concepts/permissions.md](concepts/permissions.md) | Roles, teams, CODEOWNERS, branch protection |

### Patterns (< 200 lines each)

| File | Purpose |
|------|---------|
| [patterns/branching-strategies.md](patterns/branching-strategies.md) | Git Flow, GitHub Flow, trunk-based development |
| [patterns/ci-cd-workflows.md](patterns/ci-cd-workflows.md) | GitHub Actions workflow patterns (test, build, deploy) |
| [patterns/code-review.md](patterns/code-review.md) | PR review best practices, CODEOWNERS, auto-merge |
| [patterns/release-management.md](patterns/release-management.md) | Semantic versioning, release-please, changelogs |

---

## Quick Reference

- [quick-reference.md](quick-reference.md) - gh CLI commands and workflow cheat sheet

---

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Pull Requests** | Code review workflow with merge strategies (merge, squash, rebase) |
| **GitHub Actions** | Built-in CI/CD with YAML workflows, marketplace actions, matrix builds |
| **Copilot Coding Agent** | Assign issues to @copilot for autonomous code generation and PR creation (GA 2025) |
| **Copilot Multi-Model** | GPT-5, GPT-5 mini, Claude Opus 4.1 across VS Code, JetBrains, Xcode, Eclipse |
| **GitHub MCP Server** | OAuth 2.1 + PKCE MCP server for IDE-agnostic AI integration (GA Sep 2025) |
| **Agentic Workflows** | Markdown-based Actions with `gh aw` CLI (Preview Feb 2026) |
| **Branch Protection** | Required reviews, status checks, CODEOWNERS enforcement |
| **Security Scanning** | Dependabot alerts, code scanning (CodeQL), secret scanning, push protection for all public repos |
| **GitHub Projects v2** | Kanban/table views with custom fields, automation, and roadmaps |
| **GitHub CLI (gh)** | Full-featured CLI for PRs, issues, Actions, API access, and Copilot agents |

---

## Learning Path

| Level | Files |
|-------|-------|
| **Beginner** | concepts/repositories.md, concepts/pull-requests.md |
| **Intermediate** | concepts/actions.md, patterns/branching-strategies.md |
| **Advanced** | concepts/security.md, patterns/ci-cd-workflows.md, patterns/release-management.md |

---

## Cross-References

| Related KB | Connection |
|------------|------------|
| [devops-sre/iac/terraform/](../../iac/terraform/) | Deploy infrastructure via GitHub Actions |
| [devops-sre/python-tooling/uv/](../../python-tooling/uv/) | Python CI patterns with uv + Actions |
| [cloud/aws/](../../../cloud/aws/) | AWS deployment via Actions workflows |
| [cloud/gcp/](../../../cloud/gcp/) | GCP deployment via Actions workflows |

---

## Agent Usage

| Agent | Primary Files | Use Case |
|-------|---------------|----------|
| ci-cd-specialist | patterns/ci-cd-workflows.md | CI/CD pipeline configuration |
| code-reviewer | patterns/code-review.md, concepts/permissions.md | Code review workflows |
| python-developer | patterns/ci-cd-workflows.md | Python project CI setup |
