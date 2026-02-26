# Security

> **Purpose**: Dependabot, code scanning, secret scanning, and GitHub Advanced Security (GHAS)
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

GitHub provides layered security features: Dependabot for dependency vulnerabilities, secret scanning for leaked credentials, and code scanning (CodeQL) for source code vulnerabilities. GitHub Advanced Security (GHAS) bundles premium features for enterprise use.

## GHAS Products (2025+)

As of April 2025, GHAS is unbundled into two standalone products:

| Product | Price | Includes |
|---------|-------|----------|
| **GitHub Secret Protection** | $19/active committer/mo | Secret scanning, push protection, AI detection |
| **GitHub Code Security** | $30/active committer/mo | Code scanning, Copilot Autofix, dependency review |

Both are available to GitHub Team plans (no longer requires Enterprise).

## Dependabot

### What It Does

Scans dependency manifests (package.json, requirements.txt, pyproject.toml, etc.) against the GitHub Advisory Database for known vulnerabilities.

### Configuration

Create `.github/dependabot.yml`:

```yaml
version: 2
updates:
  - package-ecosystem: "pip"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10
    labels:
      - "dependencies"
    reviewers:
      - "team-leads"

  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

### Features

| Feature | Description |
|---------|-------------|
| **Alerts** | Notifications for vulnerable dependencies |
| **Security updates** | Auto-PRs to patch vulnerable deps |
| **Version updates** | Auto-PRs to keep deps current |
| **Auto-triage** | Custom rules to dismiss/snooze alerts |
| **Grouped updates** | Combine related updates in one PR |

## Secret Scanning

Detects credentials, API keys, and tokens committed to repositories.

### Push Protection (All Public Repos)

Push protection is now **enabled by default for all public repositories**. It blocks pushes containing detected secrets **before** they reach the repository:

```bash
# If push is blocked:
# remote: Push blocked: secret detected (GitHub Token)
# Use gh CLI to bypass with justification (if allowed)
```

### Supported Patterns

Scans for 200+ secret types from partners: AWS keys, Azure tokens, Google API keys, Slack tokens, database connection strings, and more.

Custom patterns can be defined in org/repo settings using regex (e.g., `MYCO_API_[A-Z0-9]{32}`).

## Code Scanning (CodeQL)

Static analysis that finds vulnerabilities in source code.

### Setup

```yaml
# .github/workflows/codeql.yml
name: CodeQL Analysis
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 6 * * 1'  # Weekly Monday 6 AM

jobs:
  analyze:
    runs-on: ubuntu-latest
    permissions:
      security-events: write
    strategy:
      matrix:
        language: ['python', 'javascript']
    steps:
      - uses: actions/checkout@v4
      - uses: github/codeql-action/init@v3
        with:
          languages: ${{ matrix.language }}
      - uses: github/codeql-action/autobuild@v3
      - uses: github/codeql-action/analyze@v3
```

### Languages Supported

Python, JavaScript/TypeScript, Java, C/C++, C#, Go, Ruby, Swift, Kotlin.

## Security Campaigns

Bulk-assign security alerts across repositories to Copilot agent or developers. Copilot generates fix PRs automatically. Track remediation org-wide by severity/CVSS score.

## Security Best Practices

| Practice | Implementation |
|----------|---------------|
| Enable Dependabot alerts | Settings > Code security |
| Enable secret scanning | Settings > Code security |
| Enable push protection | Blocks secrets before commit |
| Pin Actions to SHA | Prevent supply-chain attacks |
| Use OIDC for cloud auth | No long-lived credentials in secrets |
| Require security reviews | CODEOWNERS for security-critical paths |
| Run CodeQL on schedule | Catch issues in existing code |

## Common Mistakes

**Wrong**: Disabling Dependabot due to alert volume, storing secrets in workflows, using `actions/checkout@main`.
**Correct**: Auto-triage rules, `${{ secrets.NAME }}` for sensitive values, pin actions to SHA.

## Related

- [permissions](permissions.md)
- [../patterns/ci-cd-workflows](../patterns/ci-cd-workflows.md)
- [../patterns/release-management](../patterns/release-management.md)
