# GitHub Actions

> **Purpose**: CI/CD workflows, jobs, steps, runners, and the Actions marketplace
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

GitHub Actions is a CI/CD platform built into GitHub. Workflows are YAML files in `.github/workflows/` triggered by events like pushes, PRs, or schedules. Each workflow contains jobs that run on runners (GitHub-hosted or self-hosted), and jobs contain steps that execute commands or reusable actions.

## Core Concepts

### Workflow Structure

```yaml
name: CI                          # Workflow name
on: [push, pull_request]          # Trigger events

jobs:
  test:                           # Job ID
    runs-on: ubuntu-latest        # Runner
    steps:                        # Sequential steps
      - uses: actions/checkout@v4 # Reusable action
      - run: echo "Hello"        # Shell command
```

### Events (Triggers)

| Event | Use Case | Example |
|-------|----------|---------|
| `push` | Run on every push | `on: push` |
| `pull_request` | PR opened/updated | `on: pull_request` |
| `schedule` | Cron-based | `on: schedule: [{cron: '0 0 * * *'}]` |
| `workflow_dispatch` | Manual trigger | Button in Actions UI |
| `release` | On release publish | Deploy on new release |
| `workflow_call` | Reusable workflow | Called by other workflows |

### Runners

`ubuntu-latest` (Linux, most workloads), `windows-latest`, `macos-latest`, or self-hosted runners.

**New runners (2025-2026):**
- **1 vCPU Linux runner** (GA Jan 2026): Cost-effective for lightweight tasks
- **ARM64 runners**: Available in private repos for faster builds on ARM architectures

### Jobs and Steps

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4       # Checkout code
      - uses: actions/setup-python@v5   # Setup runtime
        with:
          python-version: '3.12'
      - run: pip install -r requirements.txt  # Shell command
      - run: pytest                     # Run tests
```

### Matrix Strategy

Run jobs across multiple configurations:

```yaml
jobs:
  test:
    strategy:
      matrix:
        python-version: ['3.11', '3.12', '3.13']
        os: [ubuntu-latest, windows-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}
```

### Secrets and Variables

```yaml
steps:
  - run: echo "${{ secrets.API_KEY }}"    # Encrypted secret
  - run: echo "${{ vars.ENVIRONMENT }}"   # Plain variable
```

```bash
# Set via gh CLI
gh secret set API_KEY --body "sk-abc123"
gh variable set ENVIRONMENT --body "production"
```

### Job Dependencies

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps: [...]

  deploy:
    needs: test              # Runs after 'test' passes
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps: [...]
```

## Key Actions from Marketplace

| Action | Purpose |
|--------|---------|
| `actions/checkout@v4` | Check out repository |
| `actions/setup-python@v5` | Install Python |
| `actions/setup-node@v4` | Install Node.js |
| `actions/cache@v4` | Cache dependencies |
| `actions/upload-artifact@v4` | Upload build artifacts |
| `docker/build-push-action@v6` | Build and push Docker images |

## Permissions

```yaml
permissions:
  contents: read          # Least privilege
  pull-requests: write    # Comment on PRs
  id-token: write         # OIDC for cloud auth
```

## Concurrency

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true   # Cancel outdated runs
```

## Common Mistakes

**Wrong**: `uses: some-action/dangerous@main` (mutable reference).
**Correct**: `uses: some-action/safe@a1b2c3d4e5f6` (pin to commit SHA for security).

## Agentic Workflows (Preview, Feb 2026)

Markdown-based Actions using natural language. Managed via `gh aw` CLI (`gh aw list`, `gh aw run`). Combines Actions infrastructure with AI agents for autonomous task execution.

## Related

- [../patterns/ci-cd-workflows](../patterns/ci-cd-workflows.md)
- [security](security.md)
- [permissions](permissions.md)
