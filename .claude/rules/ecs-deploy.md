---
paths:
  - ammodepot/**
  - ecs/**
---

# ECS Deployment Rule

After committing changes to dbt models (ammodepot/**) or ECS config (ecs/**), ensure changes are deployed:

1. **Push to main** triggers GitHub Actions CI/CD — automatic ECR build+push. No manual action needed.
2. **Manual fallback**: Run `./ecs/deploy.sh` from the repo root (requires `--profile ammodepot` AWS credentials).

The next scheduled ECS run (within 10 min) picks up the new `:latest` image automatically. No task restart needed.

## What triggers deployment

- SQL models, macros, tests, seeds, YAML under `ammodepot/`
- Dockerfile, entrypoint.sh, pyproject.toml under `ecs/`

## What does NOT trigger deployment

- docs/, streamlit_app/, .claude/, airbyte-ec2/ — no path match in CI workflow
