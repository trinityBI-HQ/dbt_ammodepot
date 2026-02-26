# CI/CD Integration

> **Purpose**: Integrating Soda data quality checks into CI/CD pipelines, dbt, and orchestrators
> **MCP Validated**: 2026-02-19

## When to Use

- Running data quality checks on every PR that modifies SQL or dbt models
- Gating deployments on data quality pass/fail
- Embedding Soda scans into Dagster, Airflow, or Prefect pipelines
- Validating staging data before promoting to production

## GitHub Actions Integration

### Using the Official Soda GitHub Action

```yaml
# .github/workflows/data-quality.yml
name: Data Quality Scan

on:
  pull_request:
    paths:
      - "models/**"
      - "checks/**"

jobs:
  soda_scan:
    runs-on: ubuntu-latest
    name: Run Soda Scan
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Perform Soda Scan
        uses: sodadata/soda-github-action@v1
        env:
          SODA_CLOUD_API_KEY: ${{ secrets.SODA_CLOUD_API_KEY }}
          SODA_CLOUD_API_SECRET: ${{ secrets.SODA_CLOUD_API_SECRET }}
          SNOWFLAKE_USERNAME: ${{ secrets.SNOWFLAKE_USERNAME }}
          SNOWFLAKE_PASSWORD: ${{ secrets.SNOWFLAKE_PASSWORD }}
        with:
          soda_library_version: v1.0.4
          data_source: snowflake
          configuration: ./soda/configuration.yml
          checks: ./soda/checks.yml
```

Results are automatically posted as PR comments with pass/warn/fail summary.

### Manual pip-based Workflow

```yaml
# .github/workflows/soda-scan.yml
name: Soda Scan

on:
  push:
    branches: [main]

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Install Soda
        run: pip install soda-snowflake

      - name: Run Soda Scan
        env:
          SNOWFLAKE_USER: ${{ secrets.SNOWFLAKE_USER }}
          SNOWFLAKE_PASSWORD: ${{ secrets.SNOWFLAKE_PASSWORD }}
        run: soda scan -d my_snowflake -c soda/configuration.yml soda/checks.yml
```

## dbt Integration

### Run Soda After dbt

```bash
# Build dbt models, then validate with Soda
dbt run --target prod
soda scan -d warehouse -c configuration.yml checks.yml
```

### dbt + Soda in GitHub Actions

```yaml
jobs:
  dbt_and_soda:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install dependencies
        run: |
          pip install dbt-snowflake soda-snowflake
      - name: Run dbt
        run: dbt run --target ci
      - name: Run Soda checks
        run: soda scan -d warehouse -c soda/configuration.yml soda/checks.yml
```

## Programmatic Python Integration

### Dagster Integration

```python
from dagster import asset, AssetExecutionContext
from soda.scan import Scan


def run_soda_scan(data_source: str, checks_path: str) -> dict:
    scan = Scan()
    scan.set_data_source_name(data_source)
    scan.add_configuration_yaml_file("soda/configuration.yml")
    scan.add_sodacl_yaml_files(checks_path)
    scan.execute()
    return {
        "has_failures": scan.has_check_fails(),
        "results": scan.get_scan_results(),
    }


@asset(deps=["orders_silver"])
def orders_quality_check(context: AssetExecutionContext):
    results = run_soda_scan("warehouse", "soda/checks/orders.yml")
    if results["has_failures"]:
        raise Exception("Soda quality checks failed")
    context.log.info("All Soda checks passed")
```

### Airflow Integration

```python
from airflow.decorators import task
from soda.scan import Scan


@task
def soda_quality_gate():
    scan = Scan()
    scan.set_data_source_name("warehouse")
    scan.add_configuration_yaml_file("/opt/soda/configuration.yml")
    scan.add_sodacl_yaml_files("/opt/soda/checks/")
    scan.execute()
    scan.assert_no_checks_fail()  # raises on failure


# In DAG: dbt_run >> soda_quality_gate() >> downstream_task
```

### Generic Python

```python
from soda.scan import Scan

scan = Scan()
scan.set_data_source_name("my_source")
scan.add_configuration_yaml_file("configuration.yml")
scan.add_sodacl_yaml_files("checks.yml")
scan.execute()

# Check results
print(f"Has failures: {scan.has_check_fails()}")
print(f"Results: {scan.get_scan_results()}")

# Fail the pipeline if checks fail
scan.assert_no_checks_fail()
```

## Project Structure

```
project/
├── dbt/
│   └── models/
├── soda/
│   ├── configuration.yml
│   └── checks/
│       ├── bronze.yml
│       ├── silver.yml
│       └── gold.yml
├── .github/
│   └── workflows/
│       └── data-quality.yml
└── dagster/
    └── assets/
```

## See Also

- [Check Patterns](../patterns/check-patterns.md)
- [Monitoring and Alerting](../patterns/monitoring-alerting.md)
- [Data Sources](../concepts/data-sources.md)
