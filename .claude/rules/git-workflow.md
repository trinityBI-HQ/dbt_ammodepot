---
paths:
  - .git/**
  - "*.md"
  - "*.sql"
  - "*.py"
  - "*.yml"
  - "*.yaml"
---

# Git Workflow Rules

> **Model:** Trunk-based development with short-lived feature branches and Conventional Commits.

## Branching Model

```
main (protected, always deployable)
  ├── feat/<scope>-<description>     ← New models, pipelines, features
  ├── fix/<scope>-<description>      ← Bug fixes
  ├── chore/<description>            ← Dependencies, config, cleanup
  ├── docs/<description>             ← Documentation changes
  ├── refactor/<description>         ← Code restructuring (no behavior change)
  └── dependabot/...                 ← Automated dependency PRs
```

### Rules

- `main` is the **only long-lived branch** — no `develop`, `release/*`, or `hotfix/*`.
- All work happens on **short-lived feature branches** created from `main`.
- Branches merge via **Pull Request** and are **deleted after merge**.
- **No direct pushes** to `main` — branch protection enforced.
- No force pushes or branch deletions on `main`.

### Branch Naming

| Prefix | Usage | Example |
|--------|-------|---------|
| `feat/` | New models, sensors, pipelines, macros | `feat/retail-sales-pipeline` |
| `fix/` | Bug fixes in models, sensors, CI | `fix/shopify-dim-product-database` |
| `chore/` | Dependency upgrades, config sync | `chore/sync-claude-md` |
| `docs/` | Documentation, KB, CLAUDE.md updates | `docs/dbt-uv-runner-kb` |
| `refactor/` | Structural changes, no behavior change | `refactor/schema-routing` |

## Commit Standards (Conventional Commits)

### Format

```
<type>(<scope>): <description>
```

### Commit Types

| Type | When to Use |
|------|-------------|
| `feat` | New models, pipelines, macros, sensors, features |
| `fix` | Bug fixes in any layer |
| `chore` | Dependency upgrades, config changes, cleanup |
| `docs` | Documentation, knowledge base, README updates |
| `refactor` | Code restructuring with no behavior change |
| `test` | Adding or updating tests |
| `ci` | CI/CD workflow changes |
| `perf` | Performance improvements |

### Scopes

Use scopes to identify the affected area:

| Scope | Applies To |
|-------|------------|
| `sensor` | Dagster sensors |
| `sources` | dbt source definitions |
| `ci` | GitHub Actions workflows |
| `deps` | Dependency updates |
| `agents` | `.claude/agents/**` |
| `kb` | `.claude/kb/**` |
| `skills` | `.claude/skills/**` |
| `migrations` | Schema or data migrations |

> Add domain-specific scopes per project (e.g., `inventory`, `sales`, `n8n`).

### Guidelines

1. **Summarize the "why"**, not just the "what".
2. **One logical change per commit** — keep commits focused.
3. **Never commit secrets** — no `.env`, credentials, or key files.
4. AI-assisted commits append: `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>`

## Merge Workflow

```
Developer: branch from main → develop → push → open PR
CI (auto):  flake8 + pytest + sqlfluff + dbt parse (parallel)
            dbt build against Snowflake (conditional on model changes)
            Branch deploy to Dagster Cloud
Review:     All status checks pass + conversations resolved + self-review
Merge:      Squash or merge commit into main
Deploy:     Auto-deploy to production (PEX → Dagster Cloud)
```

### Required Status Checks

| Check | Purpose |
|-------|---------|
| `flake8` | Python linting |
| `pytest` | Unit and integration tests |
| `sqlfluff` | SQL linting (jinja templater) |
| `dbt-parse` | SQL/YAML validation |
| `dbt Test` | Snowflake integration (conditional) |

## Environment Mapping

| Environment | Trigger | Schema | Deploy |
|-------------|---------|--------|--------|
| Local Dev | Any branch | `DBT_DEV` (single) | Manual `dbt build` |
| Branch Preview | PR open/sync | `DBT_DEV` | Auto branch deploy |
| Staging | Manual dispatch | `DBT_DEV` | Manual with approval |
| Production | Push to `main` | `DBT_PROD_bronze/silver/gold` | Auto deploy |

## Pull Request Standards

- Branch name follows convention: `{type}/{scope}-{description}`
- Commits follow Conventional Commits format
- No secrets or `.env` files in the diff
- Pre-commit hooks pass locally
- All CI gates green before merge
- All PR conversations resolved
- Feature branch deleted after merge
- `CLAUDE.md` updated if conventions changed

## Dev Loop Integration

- Use `/dev` for agentic development with PROMPT files
- Use `/create-pr` for pull request creation with conventional commits
- Use `/review` for dual AI review (CodeRabbit + Claude) before merging
- SDD workflow artifacts live in `.claude/sdd/`

## Project Structure

Both agents and KB use hierarchical category/subcategory structures. When adding new items, maintain the existing hierarchy patterns.
