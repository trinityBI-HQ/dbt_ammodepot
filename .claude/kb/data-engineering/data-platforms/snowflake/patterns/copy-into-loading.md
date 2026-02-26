# COPY INTO Data Loading

> **Purpose**: Bulk data loading from staged files into Snowflake tables
> **MCP Validated**: 2026-02-19

## When to Use

- Batch ETL/ELT processes with scheduled loads (hourly, daily)
- Historical data migrations (terabytes of archived data)
- Loading files delivered on fixed schedules from third-party systems
- High-throughput bulk ingestion where you control warehouse sizing

## Implementation

```sql
-- Create file format for reuse
CREATE FILE FORMAT csv_format
  TYPE = 'CSV'
  FIELD_DELIMITER = ','
  SKIP_HEADER = 1
  NULL_IF = ('', 'NULL', 'null')
  EMPTY_FIELD_AS_NULL = TRUE
  ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE;

CREATE FILE FORMAT json_format
  TYPE = 'JSON'
  STRIP_OUTER_ARRAY = TRUE
  ALLOW_DUPLICATE = FALSE;

-- Basic COPY INTO from stage
COPY INTO target_table
FROM @my_stage/data/
FILE_FORMAT = csv_format
PATTERN = '.*[.]csv'
ON_ERROR = 'CONTINUE';  -- Options: ABORT_STATEMENT, CONTINUE, SKIP_FILE

-- COPY with transformation
COPY INTO orders (order_id, customer_id, amount, order_date)
FROM (
  SELECT
    $1::NUMBER,           -- Column position reference
    $2::NUMBER,
    $3::DECIMAL(10,2),
    TO_DATE($4, 'YYYY-MM-DD')
  FROM @my_stage/orders/
)
FILE_FORMAT = csv_format;

-- Load JSON into VARIANT column
COPY INTO events (event_time, payload)
FROM (
  SELECT
    CURRENT_TIMESTAMP(),
    $1
  FROM @json_stage/events/
)
FILE_FORMAT = json_format;

-- Load specific files
COPY INTO target_table
FROM @my_stage
FILES = ('file1.csv', 'file2.csv', 'file3.csv')
FILE_FORMAT = csv_format;

-- Validate before loading (dry run)
COPY INTO target_table
FROM @my_stage
FILE_FORMAT = csv_format
VALIDATION_MODE = 'RETURN_ERRORS';
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `ON_ERROR` | `ABORT_STATEMENT` | Error handling: CONTINUE, SKIP_FILE, SKIP_FILE_n |
| `SIZE_LIMIT` | None | Max bytes to load per statement |
| `PURGE` | FALSE | Delete files after successful load |
| `FORCE` | FALSE | Reload previously loaded files |
| `MATCH_BY_COLUMN_NAME` | NONE | Match columns by name (CASE_SENSITIVE/INSENSITIVE) |

## Example Usage

```sql
-- Production ETL pattern with error handling
BEGIN
  COPY INTO raw.orders
  FROM @s3_stage/orders/
  FILE_FORMAT = csv_format
  PATTERN = '.*2024-01.*[.]csv'
  ON_ERROR = 'SKIP_FILE_3';  -- Skip file after 3 errors

  -- Log load metadata
  INSERT INTO etl.load_history
  SELECT 'orders', CURRENT_TIMESTAMP(), $1, $2
  FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
END;

-- Incremental load with metadata tracking
COPY INTO staging.events
FROM @events_stage
FILE_FORMAT = json_format
ON_ERROR = 'CONTINUE'
VALIDATION_MODE = NULL  -- Actually load (not just validate)
RETURN_FAILED_ONLY = TRUE;
```

## See Also

- [snowpipe-streaming](../patterns/snowpipe-streaming.md)
- [stages](../concepts/stages.md)
