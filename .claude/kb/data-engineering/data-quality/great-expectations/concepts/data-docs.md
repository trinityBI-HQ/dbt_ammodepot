# Data Docs

> **MCP Validated:** 2026-02-19

## What Are Data Docs?

Data Docs are auto-generated HTML documentation that GX produces from your Expectation Suites and Validation Results. They provide a human-readable view of your data quality rules and their pass/fail status over time.

Data Docs are one of GX's key differentiators — they turn validation rules into browsable documentation without manual effort.

## What Data Docs Show

| Section | Content |
|---------|---------|
| **Expectation Suites** | All defined rules, organized by suite |
| **Validation Results** | Pass/fail status per expectation per run |
| **Observed Values** | Actual data statistics compared to expectations |
| **Run History** | Chronological view of validation outcomes |
| **Data Asset Info** | Which data sources and assets were validated |

## How Data Docs Are Generated

Data Docs are built by the `UpdateDataDocsAction` in a Checkpoint:

```python
from great_expectations.checkpoint.actions import UpdateDataDocsAction

checkpoint = gx.Checkpoint(
    name="my_checkpoint",
    validation_definitions=[validation_def],
    actions=[
        UpdateDataDocsAction(name="update_docs"),
    ],
)

# Running the checkpoint automatically regenerates Data Docs
result = checkpoint.run()
```

## Data Docs Storage

### Local (Default)

By default, Data Docs are stored in the `gx/uncommitted/data_docs/` directory:

```
gx/
└── uncommitted/
    └── data_docs/
        └── local_site/
            ├── index.html
            ├── expectations/
            └── validations/
```

Open `index.html` in a browser to view.

### Cloud Storage

For shared access, configure Data Docs to publish to cloud storage:

**S3:**
```yaml
# In great_expectations.yml
data_docs_sites:
  s3_site:
    class_name: SiteBuilder
    store_backend:
      class_name: TupleS3StoreBackend
      bucket: my-gx-docs-bucket
      prefix: data_docs/
```

**GCS:**
```yaml
data_docs_sites:
  gcs_site:
    class_name: SiteBuilder
    store_backend:
      class_name: TupleGCSStoreBackend
      bucket: my-gx-docs-bucket
      prefix: data_docs/
```

## Opening Data Docs Programmatically

```python
# Open Data Docs in the default browser
context.open_data_docs()
```

## Best Practices

| Practice | Rationale |
|----------|-----------|
| Always include `UpdateDataDocsAction` | Keeps docs in sync with every validation run |
| Host on cloud storage for teams | Enables shared visibility into data quality |
| Add `.gitignore` for `uncommitted/` | Local Data Docs should not be committed |
| Use Data Docs as quality dashboards | Share links with stakeholders for transparency |
| Review Docs after suite changes | Verify new expectations appear correctly |

## Data Docs vs GX Cloud

| Feature | Data Docs (OSS) | GX Cloud |
|---------|-----------------|----------|
| Hosting | Self-managed (local/S3/GCS) | Managed SaaS |
| History | Stored locally, manual setup | Automatic retention |
| Collaboration | Share via URL/bucket | Built-in team features |
| Alerting | Via checkpoint actions | Native alerts |
| Health Dashboard | N/A | Daily health score, coverage metrics (Jul 2025) |
| AI Expectations | N/A | ExpectAI: plain English rule authoring (Feb/Jul 2025) |
| Catalog Integration | N/A | Atlan integration (Aug 2025) |

## See Also

- [checkpoints.md](checkpoints.md) - Checkpoints trigger Data Docs generation
- [data-context.md](data-context.md) - Context manages Data Docs stores
- [../patterns/checkpoint-actions.md](../patterns/checkpoint-actions.md) - Action configuration patterns
