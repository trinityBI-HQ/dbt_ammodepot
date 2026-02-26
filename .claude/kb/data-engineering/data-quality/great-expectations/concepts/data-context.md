# Data Context

> **MCP Validated:** 2026-02-19

## What Is a Data Context?

The Data Context is the entry point for all Great Expectations operations. It is a Python object that manages configuration, metadata, stores, and access to all GX workflow components (Data Sources, Expectation Suites, Validation Definitions, Checkpoints).

In GX 1.x, you create a Data Context programmatically using the fluent API rather than editing YAML files.

## Creating a Data Context

### Ephemeral (In-Memory)

```python
import great_expectations as gx

# No persistence -- good for notebooks and testing
context = gx.get_context()
```

### File-Based (Persistent)

```python
# Persists configuration to disk
context = gx.get_context(mode="file", project_root_dir="./gx_project")
```

This creates a `gx/` directory with:

```
gx_project/
└── gx/
    ├── great_expectations.yml    # Project config
    ├── expectations/             # Stored Expectation Suites
    ├── checkpoints/              # Stored Checkpoints
    ├── uncommitted/              # Data Docs, credentials (gitignored)
    └── plugins/                  # Custom expectations
```

### Cloud (GX Cloud)

```python
# Requires GX Cloud account and environment variables
# GX_CLOUD_ORGANIZATION_ID, GX_CLOUD_ACCESS_TOKEN
context = gx.get_context(mode="cloud")
```

## Context Stores

The Data Context manages several stores for persisting GX objects:

| Store | Purpose | Default Location |
|-------|---------|-----------------|
| Expectations Store | Expectation Suites as JSON | `gx/expectations/` |
| Validations Store | Validation Results | `gx/uncommitted/validations/` |
| Checkpoint Store | Checkpoint definitions | `gx/checkpoints/` |
| Data Docs Store | Generated HTML documentation | `gx/uncommitted/data_docs/` |

## Working with the Context

### Managing Expectation Suites

```python
# Create
suite = context.suites.add(gx.ExpectationSuite(name="my_suite"))

# Retrieve
suite = context.suites.get(name="my_suite")

# List
all_suites = context.suites.all()
```

### Managing Validation Definitions

```python
# Create and store
validation_def = gx.ValidationDefinition(
    data=batch_definition, suite=suite, name="my_validation"
)
context.validation_definitions.add(validation_def)

# Retrieve
validation_def = context.validation_definitions.get("my_validation")
```

### Managing Checkpoints

```python
# Create and store
checkpoint = gx.Checkpoint(
    name="my_checkpoint",
    validation_definitions=[validation_def],
    actions=[UpdateDataDocsAction(name="update_docs")],
)
context.checkpoints.add(checkpoint)

# Retrieve and run
checkpoint = context.checkpoints.get("my_checkpoint")
result = checkpoint.run()
```

## Environment Variables

Store sensitive values in environment variables and reference them with `${VAR_NAME}` syntax in connection strings:

```python
connection_string = "${MY_DATABASE_URL}"
data_source = context.data_sources.add_postgres(
    name="prod_db", connection_string=connection_string
)
```

## GX 0.x vs 1.x

| Feature | GX 0.x | GX 1.x (Current) |
|---------|--------|-------------------|
| Configuration | YAML files (`great_expectations.yml`) | Fluent Python API |
| CLI workflow | `great_expectations init` | `gx.get_context()` |
| Datasource config | YAML blocks | `context.data_sources.add_*()` |
| Checkpoint config | YAML | Python objects |
| Python support | Up to 3.11 | Up to 3.13 (1.x series) |

The GX 1.x API is fully programmatic. YAML configuration files are still generated for persistence but are managed through the Python API, not edited directly.

**Important:** GX Core 0.18 support ended on Oct 1, 2025. All projects must migrate to 1.x. The 1.4-1.11 releases introduced cleaner APIs and typed parameters.

## See Also

- [data-sources.md](data-sources.md) - Connecting to data backends
- [checkpoints.md](checkpoints.md) - Running validations in production
- [data-docs.md](data-docs.md) - Auto-generated documentation
