# Iceberg Table Format Architecture

> **Purpose**: Understand metadata layers, manifests, snapshots, and how Iceberg tracks data
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Iceberg uses a **metadata tree** to track every data file in a table. Unlike Hive (which relies on directory listings), Iceberg maintains an explicit file-level inventory with column-level statistics. This enables atomic commits, efficient query planning, and correct results without expensive file system operations.

## The Metadata Tree

```text
Catalog
  └── Table → current-metadata-pointer
                └── Metadata File (v3.metadata.json)
                      ├── table-uuid
                      ├── schemas (current + history)
                      ├── partition-specs (current + history)
                      ├── sort-orders
                      ├── properties
                      └── snapshots[]
                            ├── snapshot-id
                            ├── timestamp-ms
                            ├── summary (added/deleted/total files and records)
                            └── manifest-list → snap-<id>-<attempt>.avro
                                  └── manifest-file entries[]
                                        ├── manifest-path → <hash>-m0.avro
                                        ├── partition-spec-id
                                        ├── added/existing/deleted files count
                                        └── partition-field-summary (min/max per field)
                                              └── data-file entries[]
                                                    ├── file-path (parquet/orc/avro)
                                                    ├── file-format
                                                    ├── record-count
                                                    ├── file-size-in-bytes
                                                    ├── column-sizes
                                                    ├── value-counts
                                                    ├── null-value-counts
                                                    ├── lower-bounds (per column)
                                                    └── upper-bounds (per column)
```

## Layer Responsibilities

| Layer | Format | Tracks | Immutable? |
|-------|--------|--------|:----------:|
| **Catalog** | Service/DB | Current metadata pointer per table | No (pointer updates) |
| **Metadata File** | JSON | Schemas, partition specs, snapshot list | Yes |
| **Manifest List** | Avro | Which manifests belong to a snapshot | Yes |
| **Manifest File** | Avro | Data file paths + column stats | Yes |
| **Data File** | Parquet/ORC/Avro | Actual row data | Yes |
| **Delete File** | Parquet | Position or equality deletes | Yes |
| **Deletion Vector** | Binary (v3) | Bitmap of deleted rows per data file | Yes |

## How Commits Work

1. Writer produces new data files (Parquet)
2. Writer creates new manifest files tracking those data files
3. Writer creates a new manifest list referencing new + existing manifests
4. Writer creates a new metadata file with a new snapshot entry
5. **Atomic swap**: Catalog updates the current metadata pointer

If two writers conflict, the loser retries — **optimistic concurrency control**.

```text
Before commit:     metadata-v1.json → snap-A → [manifest-1, manifest-2]
Writer adds files: metadata-v2.json → snap-B → [manifest-1, manifest-2, manifest-3]
                                                                         ^^^^^^^^^^^
                                                                         new manifest
```

Shared manifests are **not rewritten** — only new/changed manifests are added.

## Format Spec Versions

| Spec | Key Additions |
|------|---------------|
| **v1** | Original: manifests, snapshots, schema evolution, hidden partitioning |
| **v2** | Row-level deletes (position/equality delete files), sort orders |
| **v3** (2025) | Deletion vectors (binary bitmaps), `variant` type, geospatial types, nanosecond timestamps, default column values, multi-argument transforms, row lineage |
| **v4** (design) | Indexability, cache-friendliness (early design phase) |

## Key Properties

| Property | Value |
|----------|-------|
| Atomicity | Metadata pointer swap (single-writer commit) |
| Isolation | Snapshot isolation (readers see consistent state) |
| Consistency | Optimistic concurrency (retry on conflict) |
| File tracking | Explicit (every file in manifest) vs Hive (directory listing) |
| Statistics | Column-level min/max/null in each manifest entry |

## Common Mistakes

### Wrong

Thinking Iceberg stores data differently from Hive — it uses the **same data files** (Parquet/ORC). The innovation is in **how metadata tracks those files**.

### Correct

Iceberg is a **metadata format**, not a storage format. Data files are standard Parquet. The table format defines how metadata, manifests, and snapshots organize and reference those files.

## Related

- [Catalog](../concepts/catalog.md) — how the metadata pointer is managed
- [Snapshots & Time Travel](../concepts/snapshots-time-travel.md) — snapshot lifecycle
- [Table Maintenance](../patterns/table-maintenance.md) — compaction and cleanup
