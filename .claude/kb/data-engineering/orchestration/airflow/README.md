# Apache Airflow

> **Status:** Placeholder - Knowledge base content coming soon

This folder is reserved for Apache Airflow documentation and best practices.

## Why Apache Airflow?

Apache Airflow is a platform to programmatically author, schedule, and monitor workflows. It uses Directed Acyclic Graphs (DAGs) to define task dependencies and is widely adopted for batch-oriented data pipelines.

**When to use Airflow:**
- Task-centric workflows (vs asset-centric like Dagster)
- Large existing Airflow infrastructure
- Need for extensive operator library
- Mature tooling and community support

## Related Technologies

- **Dagster**: See [../dagster/](../dagster/) for asset-based orchestration
- **dbt**: See [../../transformation/dbt-core/](../../transformation/dbt-core/) for SQL transformations
- **Prefect**: Alternative dataflow-centric orchestrator

## To Add Content Here

This KB domain should include:
1. `index.md` - Overview, installation, core concepts
2. `quick-reference.md` - Common CLI commands, DAG examples (max 100 lines)
3. `concepts/` - DAGs, operators, sensors, executors (max 150 lines each)
4. `patterns/` - Best practices, testing patterns, deployment (max 200 lines each)
5. `.metadata.json` - Technology metadata

Use `/create-kb` command to scaffold this domain.
