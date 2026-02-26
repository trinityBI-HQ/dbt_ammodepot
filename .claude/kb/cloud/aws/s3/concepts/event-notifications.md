# Event Notifications

> **Purpose**: S3 event-driven architecture with Lambda, SQS, SNS, and EventBridge
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

S3 can publish notifications when objects are created, deleted, restored, or replicated. Events can be routed to Lambda functions, SQS queues, SNS topics, or Amazon EventBridge. EventBridge is the recommended approach for new architectures due to its advanced filtering and multi-target routing.

## Event Destinations

| Destination | Latency | Filtering | Multi-target | Best For |
|-------------|---------|-----------|-------------|----------|
| Lambda | Low | Prefix/suffix only | No | Direct processing |
| SQS | Low | Prefix/suffix only | No | Queue-based processing |
| SNS | Low | Prefix/suffix only | Fan-out | Multi-subscriber notification |
| EventBridge | Low | Advanced rules | Yes | Complex routing, filtering |

## Supported Event Types

| Event | Trigger |
|-------|---------|
| `s3:ObjectCreated:*` | PUT, POST, COPY, multipart upload complete |
| `s3:ObjectRemoved:*` | DELETE, DeleteMarkerCreated |
| `s3:ObjectRestore:*` | Glacier restore initiated/completed |
| `s3:Replication:*` | Replication failed/completed |
| `s3:LifecycleTransition` | Object transitioned between storage classes |
| `s3:ObjectTagging:*` | Tags added/deleted |

## The Pattern: Lambda Trigger

```python
# Lambda handler for S3 events
import boto3
import json
import urllib.parse

s3 = boto3.client("s3")

def handler(event, context):
    for record in event["Records"]:
        bucket = record["s3"]["bucket"]["name"]
        key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])
        size = record["s3"]["object"]["size"]
        event_name = record["eventName"]

        print(f"Event: {event_name}, Bucket: {bucket}, Key: {key}")

        # Download and process the object
        response = s3.get_object(Bucket=bucket, Key=key)
        content = response["Body"].read()
        # ... process content ...
```

## EventBridge Configuration (Recommended)

```python
# Enable EventBridge notifications on bucket
s3.put_bucket_notification_configuration(
    Bucket="my-bucket",
    NotificationConfiguration={
        "EventBridgeConfiguration": {},
    },
)
```

```json
{
  "Comment": "EventBridge rule for S3 object creation",
  "Source": ["aws.s3"],
  "DetailType": ["Object Created"],
  "Detail": {
    "bucket": { "name": ["my-bucket"] },
    "object": { "key": [{ "prefix": "uploads/" }] }
  }
}
```

## Terraform: S3 + Lambda Notification

```hcl
resource "aws_s3_bucket_notification" "trigger" {
  bucket = aws_s3_bucket.data.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "incoming/"
    filter_suffix       = ".csv"
  }
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.data.arn
}
```

## EventBridge vs Native Notifications

| Feature | Native (Lambda/SQS/SNS) | EventBridge |
|---------|------------------------|-------------|
| Filtering | Prefix + suffix only | Advanced content-based |
| Multiple targets | One per event config | Unlimited rules |
| Same-prefix routing | One Lambda per prefix | Multiple targets |
| Replay | No | Yes (event archive) |
| Cross-account | Complex | Built-in |

## Common Mistakes

### Wrong

```python
# Two Lambda triggers on the same prefix (S3 rejects this)
notification = {
    "LambdaFunctionConfigurations": [
        {"Events": ["s3:ObjectCreated:*"], "Filter": {"Key": {"FilterRules": [{"Name": "prefix", "Value": "data/"}]}}},
        {"Events": ["s3:ObjectCreated:*"], "Filter": {"Key": {"FilterRules": [{"Name": "prefix", "Value": "data/"}]}}},
    ]
}
```

### Correct

```python
# Use EventBridge for multiple targets on the same prefix
notification = {"EventBridgeConfiguration": {}}
# Then create multiple EventBridge rules targeting different Lambdas
```

## Related

- [buckets-objects](buckets-objects.md)
- [security-access](security-access.md)
- [../patterns/data-lake-pattern](../patterns/data-lake-pattern.md)
