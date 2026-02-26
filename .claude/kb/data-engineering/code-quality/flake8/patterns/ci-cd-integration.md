# CI/CD Integration

> **Purpose**: Integrate flake8 into pre-commit hooks, GitHub Actions, and Azure DevOps pipelines
> **MCP Validated**: 2026-02-19

## When to Use

- Enforcing code quality on every commit or pull request
- Preventing lint violations from reaching the main branch
- Automating code review for style consistency
- Running flake8 as a quality gate in CI/CD

## Implementation

### Pre-commit Hook

The most common integration point. Runs flake8 before each commit locally.

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/PyCQA/flake8
    rev: 7.3.0  # pin to a specific version
    hooks:
      - id: flake8
        additional_dependencies:
          - flake8-bugbear==24.8.19
          - flake8-bandit==4.1.1
          - flake8-import-order==0.18.2
          - flake8-pyproject==1.2.3
        args: [--config, .flake8]
```

```bash
# Install pre-commit
pip install pre-commit

# Install the hooks
pre-commit install

# Run against all files (first time or CI)
pre-commit run flake8 --all-files

# Update hook versions
pre-commit autoupdate
```

**Key detail**: Plugins must be listed in `additional_dependencies` because pre-commit runs flake8 in an isolated virtualenv.

### GitHub Actions

```yaml
# .github/workflows/lint.yml
name: Lint

on:
  pull_request:
    paths:
      - "**.py"
      - ".flake8"
      - ".pre-commit-config.yaml"

jobs:
  flake8:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Install dependencies
        run: |
          pip install flake8 flake8-bugbear flake8-bandit

      - name: Run flake8
        run: flake8 --count --statistics .
```

### GitHub Actions with Pre-commit

```yaml
# .github/workflows/pre-commit.yml
name: Pre-commit

on:
  pull_request:

jobs:
  pre-commit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - uses: pre-commit/action@v3.0.1
```

### Azure DevOps Pipeline

```yaml
# azure-pipelines.yml
trigger:
  branches:
    include:
      - main
  paths:
    include:
      - "**.py"

pool:
  vmImage: "ubuntu-latest"

steps:
  - task: UsePythonVersion@0
    inputs:
      versionSpec: "3.11"

  - script: |
      pip install flake8 flake8-bugbear flake8-bandit
    displayName: "Install flake8"

  - script: |
      flake8 --count --statistics --output-file=flake8-report.txt .
    displayName: "Run flake8"
    continueOnError: false

  - task: PublishBuildArtifacts@1
    condition: failed()
    inputs:
      pathToPublish: flake8-report.txt
      artifactName: flake8-report
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `--count` | off | Print total error count (useful for CI) |
| `--statistics` | off | Show error code frequency |
| `--output-file` | stdout | Write results to file |
| `--format=pylint` | default | Machine-parseable output for CI |
| `--exit-zero` | off | Always exit 0 (for warnings-only mode) |

## uv Integration

For projects using uv (like this repo):

```yaml
# GitHub Actions with uv
- name: Install uv
  uses: astral-sh/setup-uv@v4

- name: Install dependencies
  run: uv pip install flake8 flake8-bugbear flake8-bandit

- name: Run flake8
  run: uv run flake8 --count --statistics dagster_orchestration/
```

## Dagster + dbt Project Pattern

For monorepos with both Python (Dagster) and SQL (dbt):

```yaml
# Only lint Python directories, skip dbt artifacts
- name: Run flake8
  run: |
    flake8 \
      --count \
      --statistics \
      dagster_orchestration/ \
      --exclude=dbt_packages,target,logs
```

## Example Usage

```bash
# Local: run pre-commit on staged files only
pre-commit run flake8

# Local: run against all files
pre-commit run flake8 --all-files

# CI: strict mode with statistics
flake8 --count --statistics --show-source .
```

## See Also

- [project-configuration.md](project-configuration.md) - Base flake8 config
- [plugin-stack.md](plugin-stack.md) - Plugins to include in CI
- [../concepts/configuration.md](../concepts/configuration.md) - Config options reference
