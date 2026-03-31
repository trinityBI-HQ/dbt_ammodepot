# Section 4: Git & Workflow

> **Delivery Standards** — trinityBI Engineering
>
> Last updated: 2026-03-17

---

## 4.1 Branching Model

We use **Trunk-Based Development** — a single protected `main` branch with short-lived feature branches. No `develop`, `release/*`, or `hotfix/*` branches exist.

```
main (protected — always deployable)
  │
  ├── feat/<scope>-<description>       New capability
  ├── fix/<scope>-<description>        Bug fix
  ├── chore/<description>              Config, deps, cleanup
  ├── docs/<description>               Documentation only
  ├── refactor/<description>           Restructure, no behavior change
  └── dependabot/...                   Automated dependency PRs
```

### Branch Rules

| Rule | Detail |
|------|--------|
| Long-lived branches | `main` only |
| Feature branch origin | Always created **from** `main` |
| Merge method | Pull Request (squash or merge commit) |
| Post-merge | Branch **deleted** immediately |
| Direct pushes to `main` | **Blocked** (branch protection) |
| Force pushes to `main` | **Blocked** |
| Branch deletions on `main` | **Blocked** |

### Branch Naming Convention

Format: `{type}/{scope}-{description}` (all lowercase, hyphen-separated)

| Prefix | When to Use | Example |
|--------|-------------|---------|
| `feat/` | New models, sensors, pipelines, macros | `feat/retail-sales-pipeline` |
| `fix/` | Bug fixes in models, sensors, CI | `fix/shopify-dim-product-database` |
| `chore/` | Dependency upgrades, config sync | `chore/upgrade-dbt-1-12` |
| `docs/` | Documentation, KB, README updates | `docs/dbt-uv-runner-kb` |
| `refactor/` | Structural changes, no behavior change | `refactor/schema-routing` |

**Scope is optional** but recommended when the change targets a specific domain (e.g., `feat/inventory-new-model` vs `feat/add-retry-logic`).

---

## 4.2 Commit Standards

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification. Every commit message is machine-parseable to enable automated changelogs, release notes, and semantic versioning.

### Format

```
<type>(<scope>): <description>

[optional body — explains WHY, not WHAT]

[optional footer — e.g., Co-Authored-By, Closes #123]
```

### Commit Types

| Type | Purpose | Example |
|------|---------|---------|
| `feat` | New models, pipelines, macros, sensors | `feat(inventory): add purchase orders bronze model` |
| `fix` | Bug fixes in any layer | `fix(sources): split finale sources by database` |
| `chore` | Dependency upgrades, config, cleanup | `chore(deps): upgrade dbt 1.11.7, dagster 1.12.19` |
| `docs` | Documentation, KB, README | `docs: add dbt 1.11 arguments convention` |
| `refactor` | Code restructuring, no behavior change | `refactor: restructure README for multi-client` |
| `test` | Adding or updating tests | `test(sensor): add CDC polling edge cases` |
| `ci` | CI/CD workflow changes | `ci: use env context instead of secrets in if` |
| `perf` | Performance improvements | `perf(silver): pre-aggregate before final join` |

### Scopes

Scopes identify the affected area. Use them when the change targets a specific domain.

| Scope | Applies To |
|-------|------------|
| `sensor` | Dagster sensors |
| `sources` | dbt source definitions |
| `ci` | GitHub Actions workflows |
| `deps` | Dependency updates |
| `kb` | Knowledge base files |
| `migrations` | Schema or data migrations |

> **Add domain-specific scopes** per project (e.g., `inventory`, `sales`, `n8n`). The scope list is a living standard.

> **Add new scopes** as new domains emerge. The scope list is a living standard.

### Commit Guidelines

| Guideline | Rationale |
|-----------|-----------|
| Summarize the **"why"**, not just the "what" | Future-you reads `git log`, not the diff |
| One logical change per commit | Enables clean reverts and bisects |
| Never commit secrets (`.env`, credentials, keys) | Security — secrets belong in vaults |
| Keep subject line under 72 characters | Git tooling truncates beyond this |
| Use imperative mood ("add", not "added") | Matches git's own convention (`Merge branch...`) |
| AI-assisted commits append co-author trailer | Traceability for AI-generated code |

```
Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

---

## 4.3 The Merge Workflow

Every change follows the same lifecycle: **branch → develop → PR → CI → review → merge → deploy**.

```
┌─ Developer ─────────────────────────────────────────────────────┐
│                                                                 │
│  1. Create branch from main                                     │
│     git checkout -b feat/inventory-new-model                    │
│                                                                 │
│  2. Develop locally                                             │
│     dbt parse → dbt build --target dev                          │
│     Pre-commit hooks: flake8, sqlfluff, yaml-lint, secrets      │
│                                                                 │
│  3. Push → Open PR against main                                 │
│                                                                 │
└───────────────────────────┬─────────────────────────────────────┘
                            ▼
┌─ CI (GitHub Actions) ──────────────────────────────────────────-┐
│                                                                 │
│  Parallel lint & validate:                                      │
│    ✓ flake8 + bugbear            Python linting                 │
│    ✓ pytest                      Unit + integration tests       │
│    ✓ sqlfluff                    SQL linting (jinja templater)  │
│    ✓ dbt parse                   SQL/YAML validation            │
│                                                                 │
│  Conditional (models/ or macros/ changed):                      │
│    ✓ dbt build --target dev      Snowflake integration          │
│                                                                 │
│  Branch deployment:                                             │
│    ✓ PEX build → Dagster Cloud   Isolated preview environment   │
│                                                                 │
└───────────────────────────┬─────────────────────────────────────┘
                            ▼
┌─ Review & Merge ───────────────────────────────────────────────-┐
│                                                                 │
│  All 4 status checks pass                                       │
│  All PR conversations resolved                                  │
│  Self-review of the full diff                                   │
│                                                                 │
│  → Merge into main (squash or merge commit)                     │
│                                                                 │
└───────────────────────────┬─────────────────────────────────────┘
                            ▼
┌─ Auto-Deploy ──────────────────────────────────────────────────-┐
│                                                                 │
│  Push to main triggers:                                         │
│    1. Generate dbt manifest                                     │
│    2. Build PEX (Python EXecutable)                             │
│    3. Deploy to Dagster Cloud production                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### CI/CD Workflows

| Workflow | Trigger | What It Does |
|----------|---------|-------------|
| `lint.yml` | Push/PR to `.py`, `.sql`, `.yml` | flake8 + pytest + sqlfluff + dbt parse (parallel) |
| `dbt_test.yml` | PR with model/macro changes | `dbt build` against Snowflake |
| `branch_deployments.yml` | PR open/sync/close | PEX deploy to Dagster Cloud branch env |
| `deploy.yml` | Push to `main` | PEX deploy to Dagster Cloud production |
| `staging_deploy.yml` | Manual (`workflow_dispatch`) | Deploy to staging with optional approval gate |

### Required Status Checks

All 4 must pass before merge is allowed:

| Check | Tool | What It Catches |
|-------|------|----------------|
| `flake8` | flake8 + bugbear | Python style, complexity, common bugs |
| `pytest` | pytest | Logic errors, regressions (21 tests) |
| `sqlfluff` | sqlfluff (jinja templater) | SQL style violations, formatting |
| `dbt-parse` | dbt parse | Invalid SQL, broken refs, YAML schema errors |

### Branch Protection Summary

| Setting | Value |
|---------|-------|
| Require PR before merge | Yes |
| Require approvals | No (solo dev — self-merge allowed) |
| Require status checks | Yes — flake8, pytest, sqlfluff, dbt-parse |
| Require conversation resolution | Yes |
| Allow force push | No |
| Allow branch deletion | No |

---

## 4.4 Environment Mapping

Each environment serves a specific purpose in the delivery pipeline. Code promotes from left to right.

```
LOCAL DEV  →  BRANCH PREVIEW  →  STAGING  →  PRODUCTION
(manual)      (auto on PR)       (manual)     (auto on merge)
```

| Environment | Trigger | Snowflake Schema | Dagster Target | Deploy Method |
|-------------|---------|-----------------|----------------|---------------|
| **Local Dev** | Any branch | `DBT_DEV` (single schema) | `dagster dev` (localhost) | Manual `dbt build` |
| **Branch Preview** | PR open/sync | `DBT_DEV` | Branch deployment (isolated) | Auto — `branch_deployments.yml` |
| **Staging** | Manual dispatch | `DBT_DEV` | Staging environment | Manual — `staging_deploy.yml` |
| **Production** | Push to `main` | `DBT_PROD_bronze`, `_silver`, `_gold` | Production | Auto — `deploy.yml` |

### Schema Routing Logic

The `generate_schema_name` macro controls where models land:

| Target | Behavior | Result |
|--------|----------|--------|
| `dev` | All models → single schema | `DBT_DEV.stg_shopify__orders` |
| `prod` | Models → layer-specific schemas | `DBT_PROD_bronze.stg_shopify__orders` |

**Why single schema in dev?** Simplifies local development — no need to manage multiple schemas for feature work. Layer separation only matters in production where consumers depend on stable schema paths.

### Deployment Details

| Detail | Value |
|--------|-------|
| Deploy method | PEX (Python EXecutable) — no Docker build required |
| Python version | 3.11 |
| Manifest generation | `dagster-dbt project prepare-and-package` |
| Concurrency | In-progress deploys to same branch are auto-cancelled |
| Dagster Cloud URL | `trinitybi.dagster.cloud` |

---

## 4.5 Pull Request Checklist

Copy this into each PR description. Remove sections that don't apply.

```markdown
## PR Checklist

### Branch & Commits
- [ ] Branch name follows `{type}/{scope}-{description}` convention
- [ ] Commits follow Conventional Commits: `type(scope): description`
- [ ] No secrets or `.env` files in the diff

### Pre-Commit Hooks (run locally)
- [ ] flake8 passes
- [ ] sqlfluff passes
- [ ] yaml-lint passes
- [ ] secrets scan clean

### dbt Models (if applicable)
- [ ] No `SELECT *` — explicit column lists only (`select * from final` is the sole exception)
- [ ] Model naming follows layer convention (stg_, int_, or plain marts)
- [ ] Materialization matches layer:
  - Bronze → `view`
  - Silver → `table` or `incremental`
  - Gold → `table`
- [ ] YAML schema file exists with tests for new/modified models
- [ ] `dbt parse` passes locally
- [ ] `dbt build --target dev` passes against Snowflake
- [ ] Incremental models use 3-day lookback for late-arriving data
- [ ] Business values use dbt variables (no hardcoded magic numbers)

### Python / Dagster (if applicable)
- [ ] flake8 passes with zero warnings
- [ ] All pytest tests pass
- [ ] Lazy imports in `sensors.py` (avoid manifest dependency at import)
- [ ] Dev-only deps in `[dependency-groups]`, not `[project] dependencies`

### CI Gates (automated — all must be green)
- [ ] flake8
- [ ] pytest
- [ ] sqlfluff
- [ ] dbt-parse
- [ ] dbt Test (if models/macros changed)
- [ ] Branch deployment succeeds

### Post-Merge
- [ ] Full diff self-reviewed
- [ ] All PR conversations resolved
- [ ] CLAUDE.md updated (if conventions changed)
- [ ] Feature branch deleted
```

---

## 4.6 Pre-Commit Hooks

Every developer runs these hooks locally before pushing. They mirror CI to catch issues early.

| Hook | Tool | What It Catches |
|------|------|----------------|
| Python lint | flake8 + bugbear | Style, complexity, common bugs |
| SQL lint | sqlfluff | SQL formatting, style violations |
| YAML lint | yaml-lint | Invalid YAML syntax |
| Secrets scan | detect-secrets | Accidentally committed credentials |

### Setup

```bash
# Install pre-commit (one-time)
uv tool install pre-commit

# Install hooks in the repo (one-time per clone)
pre-commit install
```

Pre-commit runs automatically on `git commit`. To run manually against all files:

```bash
pre-commit run --all-files
```

---

## 4.7 Production Schedules & Monitoring

Once deployed, the production Dagster environment runs on these schedules:

| Trigger | Schedule | Scope |
|---------|----------|-------|
| Daily full build | `0 6 * * *` UTC | All 27 models + 114 dbt tests |
| CDC sensors | 60-second polling | 6 Snowflake Streams → orders subgraph or full DAG |

### Monitoring

- **Dagster Cloud UI** — Job runs, asset materializations, sensor ticks
- **Snowflake Query History** — dbt execution performance
- **GitHub Actions** — CI/CD pipeline status

---

## 4.8 AI-Assisted Development

When using Claude Code or other AI tools within this workflow:

### Branch & Commit Automation

| Tool | Purpose |
|------|---------|
| `/create-pr` | Generates branch, conventional commit, and structured PR description |
| `/review` | Dual AI review (CodeRabbit static analysis + Claude architectural review) |
| `/dev` | Agentic development with PROMPT files and verification loops |

### AI Co-Author Policy

All AI-generated or AI-assisted commits **must** include the co-author trailer:

```
Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

This ensures:
- **Traceability** — which commits had AI involvement
- **Auditability** — reviewers know to apply extra scrutiny
- **Compliance** — organization can track AI-generated code volume

### Confidence Gates for AI Changes

AI agents follow confidence scoring before making changes:

| Score | Condition | Action |
|-------|-----------|--------|
| 0.95 | KB + external docs agree | Execute confidently |
| 0.85 | External docs only | Proceed, flag as new pattern |
| 0.75 | Internal KB only | Proceed with disclaimer |
| 0.50 | Sources conflict | **Stop** — ask engineer to decide |

---

## 4.9 Quick Reference Card

**Start a feature:**
```bash
git checkout main && git pull
git checkout -b feat/sales-new-pipeline
```

**Commit your work:**
```bash
git add models/bronze/sales/
git commit -m "feat(sales): add target retail sales bronze model"
```

**Push and open PR:**
```bash
git push -u origin feat/sales-new-pipeline
gh pr create --title "feat(sales): add target retail sales bronze model" --base main
```

**After merge — clean up:**
```bash
git checkout main && git pull
git branch -d feat/sales-new-pipeline
```

---

## 4.10 Anti-Patterns

| Don't | Why | Do Instead |
|-------|-----|------------|
| Push directly to `main` | Bypasses CI and review | Always use a PR |
| Use generic branch names (`my-branch`, `test`) | No context for reviewers | Use typed prefix: `feat/`, `fix/` |
| Write commit messages like "fix stuff" | Useless in `git log` | Conventional format with scope |
| Bundle unrelated changes in one PR | Hard to review and revert | One concern per PR |
| Skip pre-commit hooks (`--no-verify`) | Pushes lint failures to CI | Fix locally first |
| Keep stale branches alive | Clutters the remote | Delete after merge |
| Force-push to shared branches | Rewrites history others depend on | Only on your own unreviewed branch |
| Commit `.env` or credentials | Security incident | Use Snowflake env vars or secrets manager |
| Mix `feat` and `refactor` in one commit | Muddies the changelog | Separate commits, one type each |

---

*Section 4 of the trinityBI Delivery Standards. For naming conventions see Section 1, for architecture see Section 2, for coding standards see Section 5.*
