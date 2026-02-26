# CI/CD Workflows

> **Purpose**: Common GitHub Actions workflow patterns for test, build, deploy, and matrix strategies
> **MCP Validated**: 2026-02-19

## When to Use

- Automating testing on every push and PR
- Building and deploying applications on merge to main
- Running security scans, linting, and type checking
- Multi-platform or multi-version testing with matrix builds

## Pattern 1: Python CI with uv

```yaml
# .github/workflows/ci.yml
name: CI
on:
  push:
    branches: [main]
  pull_request:

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python-version: ['3.11', '3.12', '3.13']
    steps:
      - uses: actions/checkout@v4

      - name: Install uv
        uses: astral-sh/setup-uv@v7
        with:
          enable-cache: true

      - name: Set up Python
        run: uv python install ${{ matrix.python-version }}

      - name: Install dependencies
        run: uv sync --locked --dev

      - name: Lint
        run: uv run ruff check .

      - name: Type check
        run: uv run mypy src/

      - name: Test
        run: uv run pytest --cov --cov-report=xml

      - name: Minimize uv cache
        run: uv cache prune --ci
```

## Pattern 2: Docker Build and Push

```yaml
# .github/workflows/docker.yml
name: Docker Build
on:
  push:
    branches: [main]
    tags: ['v*']

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v6
        with:
          push: true
          tags: |
            ghcr.io/${{ github.repository }}:latest
            ghcr.io/${{ github.repository }}:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

## Pattern 3: Deploy to AWS with OIDC

```yaml
# .github/workflows/deploy.yml
name: Deploy
on:
  push:
    branches: [main]

permissions:
  id-token: write    # Required for OIDC
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS Credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/GitHubActions
          aws-region: us-east-1

      - name: Deploy
        run: |
          aws s3 sync ./dist s3://my-bucket/
          aws cloudfront create-invalidation --distribution-id EDIST --paths "/*"
```

## Pattern 4: Reusable Workflow

Define reusable workflows with `on: workflow_call` and `inputs`, then call them from other workflows with `uses: ./.github/workflows/reusable-test.yml`. Use this to standardize CI patterns across repositories.

## Pattern 5: Agentic Workflow (Preview, Feb 2026)

Markdown-based workflows using the `gh aw` CLI. Define tasks in natural language and let agents execute them:

```bash
# Create an agentic workflow
gh aw create --name "fix-lint-errors" --description "Fix all linting errors in src/"

# Run an agentic workflow
gh aw run fix-lint-errors

# List agentic workflows
gh aw list
```

Agentic Workflows combine GitHub Actions infrastructure with AI agents for autonomous task execution. They are in Preview as of February 2026.

## Additional Patterns

- **Terraform via Actions**: Use `hashicorp/setup-terraform@v3`, run `plan` on PRs (comment output via `actions/github-script`), run `apply` on merge to main. See [devops-sre/iac/terraform/](../../../iac/terraform/).
- **Scheduled workflows**: Use `on: schedule` with cron for nightly builds, dependency updates, or cleanup tasks.
- **Copilot auto-fix**: Assign security alerts to Copilot agent via security campaigns for automated fix PRs.

## Best Practices

| Practice | Implementation |
|----------|---------------|
| Cancel outdated runs | `concurrency` with `cancel-in-progress: true` |
| Least-privilege permissions | Explicit `permissions` block per job |
| Pin action versions | Use SHA: `actions/checkout@abc123` |
| Cache dependencies | `actions/cache@v4` or built-in caching |
| Set timeouts | `timeout-minutes: 30` on jobs |
| Use OIDC for cloud auth | `id-token: write` + OIDC role (no secrets) |
| Fail fast by default | `strategy: fail-fast: true` (default) |

## Anti-Patterns

| Anti-Pattern | Why Bad | Fix |
|--------------|---------|-----|
| No concurrency control | Wasted runner minutes | Add concurrency group |
| `permissions: write-all` | Over-privileged | List exact permissions |
| Secrets in workflow logs | Credential leak | Use `add-mask` command |
| No timeout set | 6-hour default wastes credits | Set `timeout-minutes` |
| Unpinned third-party actions | Supply chain risk | Pin to commit SHA |

## Related

- [branching-strategies](branching-strategies.md)
- [release-management](release-management.md)
- [../concepts/actions](../concepts/actions.md)
- Cross-ref: [devops-sre/python-tooling/uv/patterns/ci-cd-integration](../../../python-tooling/uv/patterns/ci-cd-integration.md)
- Cross-ref: [devops-sre/iac/terraform/](../../../iac/terraform/)
