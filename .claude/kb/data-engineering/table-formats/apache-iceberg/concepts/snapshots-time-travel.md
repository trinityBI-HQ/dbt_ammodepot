# Snapshots, Time Travel, Branching & Tagging

> **Purpose**: Understand snapshot lifecycle, time travel queries, branches, and tags
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Every write to an Iceberg table creates a new **snapshot** — an immutable, complete picture of the table at that moment. Snapshots enable time travel queries, rollback, and audit trails. Iceberg also supports **branches** and **tags** for advanced workflows like Write-Audit-Publish (WAP).

## Snapshots

A snapshot is a pointer to a manifest list that describes the full set of data files in the table at commit time.

```text
Table timeline:
  snap-1 (t=10:00) → [manifest-A]                    → 100 files
  snap-2 (t=11:00) → [manifest-A, manifest-B]         → 150 files (50 added)
  snap-3 (t=12:00) → [manifest-A, manifest-B2, man-C] → 180 files (30 added, B rewritten)
                        ^^^^^^^^^^
                        shared — not copied
```

Snapshots share manifests via **structural sharing** — only new/changed manifests are created.

## Time Travel Queries

### SQL Syntax

```sql
-- By snapshot ID
SELECT * FROM prod.db.events VERSION AS OF 10963874102873;

-- By timestamp
SELECT * FROM prod.db.events TIMESTAMP AS OF '2026-02-10 12:00:00';

-- By branch name
SELECT * FROM prod.db.events VERSION AS OF 'audit-branch';

-- By tag name
SELECT * FROM prod.db.events VERSION AS OF 'release-v1';

-- Alternative syntax (FOR SYSTEM_VERSION)
SELECT * FROM prod.db.events FOR SYSTEM_VERSION AS OF 10963874102873;
SELECT * FROM prod.db.events FOR SYSTEM_TIME AS OF '2026-02-10 12:00:00';
```

### PySpark DataFrame API

```python
# By snapshot ID
df = spark.read.option("snapshot-id", 10963874102873).format("iceberg").load("prod.db.events")

# By timestamp (milliseconds)
df = spark.read.option("as-of-timestamp", "1707566400000").format("iceberg").load("prod.db.events")

# By tag
df = spark.read.option("tag", "release-v1").format("iceberg").load("prod.db.events")

# By branch
df = spark.read.option("branch", "audit-branch").format("iceberg").load("prod.db.events")
```

## Rollback

```sql
-- Rollback to a specific snapshot
CALL catalog.system.rollback_to_snapshot('prod.db.events', 10963874102873);

-- Rollback to a timestamp
CALL catalog.system.rollback_to_timestamp('prod.db.events', TIMESTAMP '2026-02-10 12:00:00');

-- Cherry-pick a snapshot (apply changes from one snapshot)
CALL catalog.system.set_current_snapshot('prod.db.events', 10963874102873);
```

## Branches & Tags

Branches and tags provide named references to snapshots.

```sql
-- Create a tag (immutable reference to a snapshot)
ALTER TABLE prod.db.events CREATE TAG `release-v1` AS OF VERSION 10963874102873;

-- Create a tag with retention
ALTER TABLE prod.db.events CREATE TAG `release-v1` AS OF VERSION 10963874102873
  RETAIN 180 DAYS;

-- Create a branch (mutable, can receive writes)
ALTER TABLE prod.db.events CREATE BRANCH `audit-branch`;

-- Create branch from specific snapshot
ALTER TABLE prod.db.events CREATE BRANCH `staging`
  AS OF VERSION 10963874102873
  RETAIN 7 DAYS;

-- Write to a branch
INSERT INTO prod.db.events.branch_audit-branch VALUES (1, 'test', current_timestamp());

-- Fast-forward main to match branch
CALL catalog.system.fast_forward('prod.db.events', 'main', 'audit-branch');

-- Drop branch/tag
ALTER TABLE prod.db.events DROP BRANCH `audit-branch`;
ALTER TABLE prod.db.events DROP TAG `release-v1`;
```

## Write-Audit-Publish (WAP) Pattern

```text
1. Create branch:    ALTER TABLE t CREATE BRANCH 'staging'
2. Write to branch:  INSERT INTO t.branch_staging SELECT ...
3. Audit branch:     SELECT * FROM t VERSION AS OF 'staging'  (validate data)
4. Publish:          CALL system.fast_forward('t', 'main', 'staging')
5. Cleanup:          ALTER TABLE t DROP BRANCH 'staging'
```

WAP ensures bad data never reaches the main branch. Quality checks run on the staging branch before publishing.

## Inspecting Snapshots

```sql
SELECT * FROM prod.db.events.snapshots;   -- all snapshots
SELECT * FROM prod.db.events.history;     -- snapshot history
SELECT * FROM prod.db.events.manifests;   -- manifest files
SELECT * FROM prod.db.events.files;       -- data files
```

## Common Mistakes

### Wrong
Keeping all snapshots forever — metadata grows, query planning slows.

### Correct
Expire old snapshots regularly:
```sql
CALL catalog.system.expire_snapshots('prod.db.events', TIMESTAMP '2026-02-01 00:00:00');
```

## Related

- [Table Format](../concepts/table-format.md) — snapshot structure in metadata
- [Table Maintenance](../patterns/table-maintenance.md) — expire snapshots, cleanup
- [Spark Integration](../patterns/spark-integration.md) — time travel in Spark
