# Snowpipe Streaming

> **Purpose**: Continuous, serverless data ingestion with sub-minute latency
> **MCP Validated**: 2026-02-19

## When to Use

- Near real-time analytics requiring data within minutes
- Continuous data streams (clickstream, IoT sensors, application logs)
- Event-driven ingestion triggered by cloud storage notifications
- High-concurrency loads where many files arrive continuously

## Implementation

```sql
-- Create target table
CREATE TABLE raw.events (
  event_id NUMBER AUTOINCREMENT,
  event_time TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
  payload VARIANT
);

-- Create pipe for auto-ingest
CREATE PIPE events_pipe
  AUTO_INGEST = TRUE
  AS
  COPY INTO raw.events (payload)
  FROM (
    SELECT $1
    FROM @events_stage
  )
  FILE_FORMAT = (TYPE = 'JSON');

-- Get notification channel for cloud setup
SHOW PIPES LIKE 'events_pipe';
-- Use notification_channel value to configure S3/GCS/Azure notifications

-- Manual refresh for historical data (files from last 7 days)
ALTER PIPE events_pipe REFRESH;

-- Refresh specific prefix
ALTER PIPE events_pipe REFRESH PREFIX = '2024/01/15/';

-- Check pipe status
SELECT SYSTEM$PIPE_STATUS('events_pipe');

-- Monitor load history
SELECT *
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
  TABLE_NAME => 'events',
  START_TIME => DATEADD(hours, -24, CURRENT_TIMESTAMP())
));
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `AUTO_INGEST` | FALSE | Enable cloud event notifications |
| `AWS_SNS_TOPIC` | None | SNS topic for S3 event notifications |
| `INTEGRATION` | None | Notification integration name |
| `ERROR_INTEGRATION` | None | Error notification integration |

## Example Usage

```sql
-- Production Snowpipe with error handling
CREATE NOTIFICATION INTEGRATION snowpipe_errors
  TYPE = QUEUE
  NOTIFICATION_PROVIDER = AWS_SNS
  ENABLED = TRUE
  AWS_SNS_TOPIC_ARN = 'arn:aws:sns:us-east-1:123456789:snowpipe-errors'
  AWS_SNS_ROLE_ARN = 'arn:aws:iam::123456789:role/snowflake-sns';

CREATE PIPE events_pipe
  AUTO_INGEST = TRUE
  ERROR_INTEGRATION = snowpipe_errors
  AS
  COPY INTO raw.events (event_time, user_id, action, payload)
  FROM (
    SELECT
      TO_TIMESTAMP_NTZ($1:timestamp::STRING),
      $1:user_id::NUMBER,
      $1:action::STRING,
      $1
    FROM @events_stage
  )
  FILE_FORMAT = (TYPE = 'JSON' STRIP_OUTER_ARRAY = TRUE);

-- Pause pipe for maintenance
ALTER PIPE events_pipe SET PIPE_EXECUTION_PAUSED = TRUE;

-- Resume pipe
ALTER PIPE events_pipe SET PIPE_EXECUTION_PAUSED = FALSE;

-- Clean up staged files (Snowpipe cannot auto-purge)
REMOVE @events_stage PATTERN = '.*processed.*';
```

## Best Practices

| Practice | Recommendation |
|----------|----------------|
| File Size | 100-250 MB per file for optimal processing |
| File Format | Use compressed formats (gzip, snappy) |
| Event Filtering | Enable cloud event filtering to reduce costs |
| Historical Data | Use COPY INTO for files older than 7 days |
| Monitoring | Set up error notifications and check COPY_HISTORY |

## See Also

- [copy-into-loading](../patterns/copy-into-loading.md)
- [stages](../concepts/stages.md)
