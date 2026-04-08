# Snowflake + AWS Cost Monitor

Streamlit-in-Snowflake app that unifies Snowflake compute/storage spend with
AWS infrastructure cost from the analytics pipeline (ECS Fargate, EC2 Airbyte,
S3 Iceberg, CloudWatch, Secrets Manager).

Runtime target: **SiS container runtime** (Streamlit 1.50+, full PyPI via
`requirements.txt`, network egress via External Access Integration).

## Layout

```
streamlit_cost_monitor/
├── streamlit_app.py          # SiS entrypoint
├── app.py                    # Local dev entrypoint (streamlit run app.py)
├── snowflake.yml             # snow CLI project definition (used by CI/CD)
├── requirements.txt          # pip deps for container runtime
├── .streamlit/config.toml    # dark theme
├── pages/
│   ├── 1_Snowflake_Compute.py
│   ├── 2_Snowflake_Storage.py
│   ├── 3_Top_Queries.py
│   ├── 4_AWS_Infrastructure.py
│   └── 5_Combined.py
├── utils/
│   ├── config.py             # CREDIT_PRICE_USD, relevant AWS services, TTLs
│   ├── db.py                 # Snowpark session (dual-mode)
│   ├── snowflake_queries.py  # ACCOUNT_USAGE SQL
│   ├── aws_costs.py          # boto3 Cost Explorer wrapper
│   └── chart_theme.py        # Plotly dark theme + dark_dataframe
└── setup/
    ├── 01_bootstrap.sql           # ACCOUNTADMIN: schema, EAI, grants
    ├── 02_create_secret.sql       # ACCOUNTADMIN: write AWS creds (after IAM)
    ├── 03_post_deploy.sql         # ACCOUNTADMIN: bind EAI+secret to Streamlit
    ├── aws_cost_explorer_policy.json
    └── create_aws_iam_user.sh     # svc_iac profile: create IAM user + key
```

## One-time bootstrap

Run these **in order**. All Snowflake SQL runs as `ACCOUNTADMIN`.

### 1. Create the Snowflake objects

```bash
# Connect via Snowsight or snowsql as ACCOUNTADMIN
# Paste-and-run setup/01_bootstrap.sql
```

Creates:
- `AD_ANALYTICS.OPS` schema (owned by `STREAMLIT_ROLE`)
- `COST_MONITOR_STAGE` for uploaded source files
- `IMPORTED PRIVILEGES` on `SNOWFLAKE` → `STREAMLIT_ROLE`
- **Compute pool `COST_MONITOR_POOL`** (CPU_X64_XS, auto-suspend 5 min) for the container runtime
- Network rule `AWS_COST_EXPLORER_RULE` (egress to `ce.us-east-1.amazonaws.com`)
- Placeholder secret `AWS_COST_EXPLORER_CREDS`
- External Access Integration `AWS_COST_EXPLORER_INTEGRATION`
- `GRANT ROLE STREAMLIT_ROLE TO USER SVC_DBT` — so CI/CD can deploy as owner
- Viewer grants for `DASHBOARD_VIEWER_ROLE`

### 2. Create the AWS IAM user

```bash
cd streamlit_cost_monitor/setup
./create_aws_iam_user.sh
```

Requires `aws --profile ammodepot` (the `svc_iac` credentials). Creates:
- IAM user `svc_snowflake_costs`
- Inline policy `CostExplorerReadOnly` (`ce:Get*`)
- One access-key pair, printed **once** to stdout

Copy the key pair, then immediately clear your shell history
(`unset HISTFILE; history -c`).

Rotation:
```bash
./create_aws_iam_user.sh --new-key
```

### 3. Load the AWS credentials into the Snowflake secret

Edit `setup/02_create_secret.sql`, replace the placeholder JSON with the
real access-key pair, run it as `ACCOUNTADMIN`, then **delete the file or
revert the edit** — never commit real credentials.

### 4. First deploy (automated via GitHub Actions)

Push to `main` with any change under `streamlit_cost_monitor/`. The workflow
`deploy-streamlit-cost-monitor.yml`:
1. Fetches `SVC_DBT`'s private key from AWS Secrets Manager (`ammodepot/dbt/snowflake`)
2. Writes a `snow` CLI config for `SVC_DBT` + `STREAMLIT_ROLE`
3. Runs `snow streamlit deploy --replace` from `streamlit_cost_monitor/`
4. Smoke-tests with `describe streamlit ad_analytics.ops.cost_monitor`

No new GitHub secrets needed — it reuses the `AWS_ACCESS_KEY_ID` and
`AWS_SECRET_ACCESS_KEY` secrets that already back the dbt→ECS workflow.

### 5. Bind the External Access Integration to the deployed app

After the first successful deploy, run `setup/03_post_deploy.sql` as
`ACCOUNTADMIN`. This is a one-time step because `snow streamlit deploy`
doesn't own the EAI and can't attach it itself.

## Local development

```bash
cd streamlit_cost_monitor
# Activate the venv that already has dbt + snowflake packages, or make one:
uv venv && source .venv/bin/activate
uv pip install -r requirements.txt python-dotenv cryptography

# Snowflake auth: reuses ammodepot/.env (key-pair, SVC_DBT)
# AWS auth: reuses AWS_PROFILE=ammodepot from your shell
export AWS_PROFILE=ammodepot

streamlit run app.py
```

The local path uses `SVC_DBT` with `TRANSFORMER_ROLE` by default. To test
the same privileges the deployed app has, run:

```bash
SNOWFLAKE_ROLE=STREAMLIT_ROLE streamlit run app.py
```

## Changing the credit price

Contract rate updates? Edit one constant:

```python
# utils/config.py
CREDIT_PRICE_USD: float = 3.00
```

All Snowflake cost figures and KPIs recompute on the next cache miss (1h).

## Extending the AWS services list

`utils/config.py → AWS_RELEVANT_SERVICES` is the allowlist used by page 4
to filter out noise. If you start using new services (e.g. AWS Batch, ECR,
Route 53) just add them to the tuple.

## Runtime — container, not warehouse

This app targets the **SiS container runtime** (GA 2026-03-09). Practical
differences from warehouse runtime:

| | Warehouse runtime | Container runtime (this app) |
|---|---|---|
| Streamlit version | 1.22 (frozen) | Latest (1.55+, incl. nightly) |
| Python packages | conda allowlist | any PyPI via `requirements.txt` |
| Network egress | blocked | via External Access Integration |
| Python version | 3.9 / 3.10 / 3.11 | 3.11 only |
| Compute | shared XSMALL warehouse | dedicated compute pool (CPU_X64_XS) |
| Cost model | per-query on warehouse | per-second on compute pool |

Container runtime is required because **we need `boto3`** (not in the
warehouse allowlist) and **network egress** to `ce.us-east-1.amazonaws.com`.

## Costs incurred by this app

| Source | Unit cost | Monthly est. |
|---|---|---|
| Compute pool `cost_monitor_pool` (CPU_X64_XS) | ~0.06 credits/hr active | ~$5 (1h/day viewing, auto-suspend 5 min) |
| AWS Cost Explorer API | $0.01 / request | ~$0.30 (6h cache on 5 calls) |
| Snowflake ACCOUNT_USAGE queries | compute on `COMPUTE_WH` | < $0.50 |

Total: **under $6/month** — monitoring cost that pays for itself the first
time it catches a runaway query. Drop to ~$1 by using the warehouse runtime
instead, but that would require rewriting `utils/aws_costs.py` to dump
Cost Explorer data to S3 + an external table (see POC in `docs/`).

## Troubleshooting

**Page 4 shows "Unable to fetch AWS Cost Explorer data"** — the EAI or
secret isn't attached. Run `setup/03_post_deploy.sql` again.

**`snow streamlit deploy` fails with "insufficient privileges to create Streamlit"**
— `SVC_DBT` doesn't have `STREAMLIT_ROLE`. Re-run section 2 of
`01_bootstrap.sql` (the `grant role` line is idempotent).

**KPI shows `$0` for "Prior Month"** — you're in the first month of usage
for that warehouse. Expected, not a bug.

**Anomaly page empty** — needs 28 days of history. Shows
"insufficient-history" until then.
