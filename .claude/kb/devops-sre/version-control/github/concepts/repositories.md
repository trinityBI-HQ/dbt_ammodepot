# Repositories

> **Purpose**: Git repositories, branches, commits, tags, and releases on GitHub
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

A GitHub repository is a Git-hosted project containing code, history, branches, and collaboration tools. Repositories are the fundamental unit of work on GitHub, combining version control with issues, PRs, Actions, and security features.

## Core Concepts

### Repository Types

| Type | Visibility | Use Case |
|------|-----------|----------|
| **Public** | Anyone can view | Open-source projects |
| **Private** | Restricted access | Proprietary code |
| **Internal** | Org members only | Inner-source (Enterprise) |
| **Fork** | Copy of another repo | Contributing to upstream |
| **Template** | Starter for new repos | Standardized project setup |

### Branches

```bash
# Create and switch to branch
git checkout -b feature/add-auth
gh pr create --base main --head feature/add-auth

# Default branch (usually 'main')
# Protected via branch protection rules
# All PRs target this branch
```

**Branch naming conventions:**
- `feature/description` -- new features
- `fix/description` -- bug fixes
- `release/v1.2.0` -- release preparation
- `hotfix/description` -- urgent production fixes

### Commits

```bash
# Conventional commits (recommended for automation)
git commit -m "feat: add user authentication"
git commit -m "fix: resolve null pointer in parser"
git commit -m "docs: update API reference"
git commit -m "chore: upgrade dependencies"
```

### Tags and Releases

```bash
# Lightweight tag
git tag v1.0.0

# Annotated tag (recommended)
git tag -a v1.0.0 -m "Release 1.0.0"
git push origin v1.0.0

# Create GitHub Release via gh CLI
gh release create v1.0.0 --generate-notes --title "v1.0.0"

# Upload assets to release
gh release upload v1.0.0 dist/*.whl
```

### Repository Settings

| Setting | Purpose |
|---------|---------|
| `.gitignore` | Exclude files from version control |
| `.github/` | Workflows, issue templates, CODEOWNERS |
| `LICENSE` | Open-source license declaration |
| `README.md` | Project overview and documentation |
| `.github/FUNDING.yml` | Sponsorship links |

## GitHub-Specific Features

| Feature | Description |
|---------|-------------|
| **GitHub Pages** | Host static sites from repo |
| **Discussions** | Forum-style Q&A threads |
| **Wiki** | Built-in documentation wiki |
| **Packages** | Host npm, Docker, Maven packages |
| **Codespaces** | Cloud dev environments |
| **Topics** | Categorize repos for discovery |

## Common Operations with gh CLI

```bash
# Create repo with .gitignore and license
gh repo create my-app --public --gitignore Python --license MIT

# Clone with gh
gh repo clone owner/repo

# Fork and clone
gh repo fork owner/repo --clone

# View repo in browser
gh repo view --web

# Archive a repository
gh repo archive owner/repo
```

## GitHub MCP Server (GA Sep 2025)

The GitHub MCP Server enables AI tools to interact with repositories using the Model Context Protocol:

- **Authentication**: OAuth 2.1 + PKCE (no personal access tokens needed)
- **Works across IDEs**: VS Code, JetBrains, Xcode, Eclipse, and any MCP-compatible client
- **Capabilities**: Read repos, create issues, manage PRs, search code, access Actions status
- **Setup**: `gh mcp install` or configure in IDE MCP settings

## Common Mistakes

### Wrong
```bash
# Committing directly to main without protection
git push origin main  # No review, no CI
```

### Correct
```bash
# Use branches + PRs for all changes
git checkout -b fix/update-config
git commit -m "fix: correct database timeout"
git push origin fix/update-config
gh pr create --fill
```

## Related

- [pull-requests](pull-requests.md)
- [permissions](permissions.md)
- [../patterns/branching-strategies](../patterns/branching-strategies.md)
