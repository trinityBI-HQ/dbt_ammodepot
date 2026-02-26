# Data Contracts Quick Reference

> Fast lookup tables. For code examples, see linked files.

## Specification Formats

| Format | Standard | Language | Best For |
|--------|----------|----------|----------|
| ODCS (YAML) | Open Data Contract Standard v3.1.2 | YAML | Universal data contracts (default format) |
| datacontract.yaml | datacontract-cli v0.11.4 spec | YAML | CLI-based testing and linting |
| JSON Schema | JSON Schema Draft 2020-12 | JSON | API-first, programmatic validation |
| Protobuf | Protocol Buffers | .proto | Streaming, gRPC, Kafka |
| Avro | Apache Avro | .avsc | Kafka, Hadoop ecosystem |

## Tooling Ecosystem

| Tool | Purpose | Contract Format |
|------|---------|-----------------|
| datacontract-cli | Lint, test, diff, export contracts | datacontract.yaml |
| Soda Core | Data quality checks as contracts | soda YAML |
| Confluent Schema Registry | Schema governance for Kafka | Avro/Protobuf/JSON Schema |
| dbt model contracts | Column-level enforcement in dbt | schema.yml |
| Great Expectations | Expectation suites as contracts | Python/YAML |
| Atlan / Collibra | Catalog-driven contract management | Proprietary |

## Contract Components

| Component | Required | Description |
|-----------|----------|-------------|
| Schema | Yes | Field names, types, constraints, nullable |
| Owner | Yes | Team or individual responsible for producing data |
| SLA | Yes | Freshness, availability, latency guarantees |
| Quality rules | Yes | Not-null, uniqueness, range, custom checks |
| Versioning | Yes | Semantic version (MAJOR.MINOR.PATCH) |
| Semantics | Recommended | Business definitions, classifications (PII, etc.) |
| Consumers | Recommended | Registered downstream dependencies |
| Lineage | Optional | Source-to-target mapping |

## Decision Matrix

| Use Case | Choose |
|----------|--------|
| Universal contract spec | ODCS (YAML) |
| CLI-based contract testing | datacontract-cli |
| Kafka schema governance | Confluent Schema Registry |
| dbt column enforcement | dbt model contracts |
| Runtime quality gates | Soda Core / Great Expectations |
| Catalog-driven governance | Atlan / Collibra |

## Implementation Approaches

| Approach | Description | Best For |
|----------|-------------|----------|
| Producer-driven | Producer defines and publishes contract | Centralized teams, APIs |
| Consumer-driven | Consumers specify their expectations | Microservices, data mesh |
| Schema-first | Schema defined before implementation | Greenfield, strict governance |
| Governance-driven | Central team mediates contracts | Regulated industries |

## Common Pitfalls

| Don't | Do |
|-------|-----|
| Define contracts after the pipeline exists | Design contracts first (schema-first) |
| Put all rules in one massive contract | Split into logical domains/datasets |
| Skip versioning | Use semantic versioning from day one |
| Enforce only schema, ignore quality | Include quality rules and SLAs |
| Make contracts producer-only decisions | Involve consumers in contract design |
| Treat contracts as documentation | Automate enforcement in CI/CD |

## Related Documentation

| Topic | Path |
|-------|------|
| Fundamentals | `concepts/fundamentals.md` |
| ODCS Specification | `patterns/odcs-specification.md` |
| Pipeline Enforcement | `patterns/pipeline-enforcement.md` |
| Full Index | `index.md` |
