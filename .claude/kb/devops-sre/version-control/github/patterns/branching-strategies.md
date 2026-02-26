# Branching Strategies

> **Purpose**: Git Flow, GitHub Flow, and trunk-based development comparison
> **MCP Validated**: 2026-02-19

## When to Use

Choosing the right branching strategy affects deployment speed, team coordination, and code quality. The industry trend (2025-2026) strongly favors trunk-based development for teams deploying frequently.

## Strategy Comparison

| Strategy | Branches | Deploys | Best For |
|----------|----------|---------|----------|
| **Trunk-Based** | main + short-lived | Continuous | Experienced teams, frequent releases |
| **GitHub Flow** | main + feature | On merge to main | Small teams, simple apps |
| **Git Flow** | main, develop, feature, release, hotfix | On release branch | Complex versioning, multiple versions |

## Trunk-Based Development (Recommended)

All developers commit to `main` (or via short-lived branches that merge within 1-2 days). The trunk is always deployable.

```
main ─────●───●───●───●───●───●─── (always deployable)
           \─●─/   \─●─/            (short-lived branches, < 2 days)
```

### Rules
- Feature branches live at most 1-2 days
- Use feature flags for incomplete work
- CI runs on every commit to main
- Deploy from main automatically (CD)

### Implementation

```bash
# Short-lived feature branch
git checkout -b feat/add-button
# ... make changes (small, focused) ...
git push origin feat/add-button
gh pr create --fill
# Merge same day or next day
gh pr merge --squash --delete-branch
```

### Feature Flags Pattern

```python
# Use feature flags for incomplete features on main
if feature_flags.is_enabled("new_dashboard", user):
    return render_new_dashboard()
else:
    return render_old_dashboard()
```

### When to Use
- Teams deploying multiple times per day
- Strong CI/CD pipeline with automated testing
- Experienced developers comfortable with small PRs
- Feature flag infrastructure available

## GitHub Flow

Simple model: main branch + feature branches. Deploy on merge to main.

```
main ───────●───────────●──────────●───── (deploy on merge)
             \──●──●──/              \──●──●──/
              feature/auth            feature/api
```

### Rules
- `main` is always deployable
- Create descriptive feature branches
- Open PR for discussion and review
- Deploy after merge to main

### Implementation

```bash
# Create feature branch from main
git checkout main && git pull
git checkout -b feature/user-auth

# Work on feature (can take days)
git commit -m "feat: add login form"
git commit -m "feat: add JWT validation"
git push origin feature/user-auth

# Create PR, get reviews, merge
gh pr create --title "feat: user authentication"
gh pr merge --squash --delete-branch
```

### When to Use
- Small to medium teams
- Single production version
- Simple deployment pipeline
- Open-source projects

## Git Flow

Complex model with long-lived branches for development, releases, and hotfixes.

```
main    ───●───────────────────●───────●─── (production releases)
            \                 /       /
develop ─────●───●───●───●───●───●───●──── (integration branch)
              \─●─/   \─●─/          \
              feature  feature      hotfix
```

### Branches
| Branch | Purpose | Lifetime |
|--------|---------|----------|
| `main` | Production releases | Permanent |
| `develop` | Integration/staging | Permanent |
| `feature/*` | New features | Temporary |
| `release/*` | Release preparation | Temporary |
| `hotfix/*` | Urgent production fixes | Temporary |

### Implementation

```bash
# Feature development
git checkout develop
git checkout -b feature/payment
# ... develop feature ...
gh pr create --base develop

# Release preparation
git checkout develop
git checkout -b release/v1.2.0
# ... bump version, final testing ...
gh pr create --base main --title "Release v1.2.0"

# Hotfix
git checkout main
git checkout -b hotfix/security-patch
# ... fix ...
gh pr create --base main
# Also merge hotfix back to develop
```

### When to Use
- Multiple versions in production simultaneously
- Formal release cycles (weekly, monthly)
- Large teams with dedicated release managers
- Regulatory environments requiring release documentation

## Decision Matrix

| Factor | Trunk-Based | GitHub Flow | Git Flow |
|--------|-------------|-------------|----------|
| Team size | Any | Small-Medium | Medium-Large |
| Deploy frequency | Continuous | On merge | Scheduled |
| Complexity | Low | Low | High |
| Feature flags needed | Yes | Sometimes | No |
| Multiple versions | No | No | Yes |
| Merge conflicts | Minimal | Moderate | Frequent |
| Time to production | Minutes | Hours | Days-Weeks |

## Anti-Patterns

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| Long-lived branches (> 1 week) | Painful merges, drift | Trunk-based or small PRs |
| No branch protection | Direct pushes bypass review | Enable required PRs + checks |
| Cherry-picking everywhere | Complex, error-prone | Merge-based promotion |
| "Deploy freeze Fridays" | Fear-driven process | Automated testing + rollback |
| Branch per environment | Drift between envs | Single main + feature flags |

## Migration Path

```
Git Flow ──→ GitHub Flow ──→ Trunk-Based Development
  (start)     (simplify)      (mature CI/CD required)
```

Steps to migrate toward trunk-based:
1. Eliminate `develop` branch (merge directly to main)
2. Reduce feature branch lifetime to < 3 days
3. Add feature flags for incomplete work
4. Automate deployment on merge to main
5. Build confidence with automated testing

## Related

- [ci-cd-workflows](ci-cd-workflows.md)
- [code-review](code-review.md)
- [release-management](release-management.md)
- [../concepts/repositories](../concepts/repositories.md)
