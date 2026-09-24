# ecs/ — production dbt on ECS Fargate

`deploy-ecs.yml` builds this image and pushes `:latest` to ECR on every push to `main` that touches
`ammodepot/` or `ecs/`. EventBridge runs it on Fargate Spot at `cron(5,20,35,50 * * * ? *)` UTC —
five minutes before each Power BI refresh at :00/:15/:30/:45, measured from `QUERY_HISTORY`. A build
takes ~3.5 minutes. Setup and operations: `README.md`.

`entrypoint.sh` runs, in order: `refresh_iceberg.py` (refreshes the 55 Iceberg tables, 8 threads —
**the only thing that does**, and the run stops if it fails), source freshness, `dbt build`, then
`dbt snapshot` (non-fatal).

## The race every production fix is in

Each scheduled run rebuilds from `:latest`. Anything done to production that `main` does not already
contain is overwritten within 15 minutes.

- **Hotfix a model Power BI is reading**: commit and push *first*, wait for the image
  (`gh run list --workflow deploy-ecs.yml`), then run the model locally with `--target prod`. Built
  locally first, it is rebuilt from the old image on the next run — a 42-column fix once
  fell back to 11 columns that way. If a task is already running, it is on the old image:
  let it finish.
- **A fix that needs DDL** (`drop`, `alter`, `truncate`): merge, confirm the new image is in ECR
  (`aws ecr describe-images --repository-name ammodepot/dbt --image-ids imageTag=latest
  --profile ammodepot`), *then* run the DDL. Before it, the old code runs against the new state and
  can recreate what the DDL cleared.

## Facts that are not in the code

- **The secret `ammodepot/dbt/snowflake` holds only the RSA key and its passphrase.** Account, user,
  role and warehouse are environment variables in `task-definition.json`. The auto-remediation Lambda
  reads the same secret.
- **Cron syntax differs by platform**: EventBridge is 6-field Quartz with `?`; Snowflake `SCHEDULE`
  is 5-field UNIX. Copying `5,20,35,50 * * * ? *` into a Snowflake alert or task fails — drop the
  `?` and the year.
- **When CI is unavailable**, `./ecs/deploy.sh` from the repo root builds and pushes the image by hand.
- Logs: CloudWatch `/ecs/ammodepot-dbt`. Alarms `dbt-build-failure` and `dbt-task-missing` (no run
  in 30 min) mail through SNS. Every AWS command takes `--profile ammodepot`.
