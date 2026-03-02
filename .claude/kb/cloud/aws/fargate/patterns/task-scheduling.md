# Task Scheduling

> **Purpose**: Run scheduled and one-off Fargate tasks using EventBridge rules and direct task runs
> **MCP Validated**: 2026-03-01

## When to Use

- Running batch jobs on a schedule (daily ETL, hourly reports)
- Executing one-off data processing tasks
- Replacing cron jobs with serverless containers
- Running tasks that exceed Lambda's 15-minute or 10 GB memory limits

## Implementation

### Terraform: EventBridge Scheduled Task

```hcl
# EventBridge rule with cron schedule
resource "aws_cloudwatch_event_rule" "daily_etl" {
  name                = "daily-etl-job"
  description         = "Run ETL task daily at 2 AM UTC"
  schedule_expression = "cron(0 2 * * ? *)"
}

# IAM role for EventBridge to run ECS tasks
resource "aws_iam_role" "eventbridge_ecs" {
  name = "eventbridge-ecs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "eventbridge_ecs" {
  name = "eventbridge-run-task"
  role = aws_iam_role.eventbridge_ecs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecs:RunTask"]
        Resource = [aws_ecs_task_definition.etl.arn]
        Condition = {
          ArnLike = {
            "ecs:cluster" = aws_ecs_cluster.main.arn
          }
        }
      },
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = [
          aws_iam_role.task_execution.arn,
          aws_iam_role.task_role.arn
        ]
      }
    ]
  })
}

# EventBridge target: ECS task
resource "aws_cloudwatch_event_target" "etl_task" {
  rule     = aws_cloudwatch_event_rule.daily_etl.name
  arn      = aws_ecs_cluster.main.arn
  role_arn = aws_iam_role.eventbridge_ecs.arn

  ecs_target {
    launch_type         = "FARGATE"
    task_definition_arn = aws_ecs_task_definition.etl.arn
    task_count          = 1
    platform_version    = "LATEST"

    network_configuration {
      subnets          = var.private_subnets
      security_groups  = [aws_security_group.etl_task.id]
      assign_public_ip = false
    }
  }

  input = jsonencode({
    containerOverrides = [{
      name    = "etl"
      command = ["python", "run_etl.py", "--date", "today"]
    }]
  })
}
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `schedule_expression` | -- | `cron()` or `rate()` expression |
| `task_count` | 1 | Number of tasks to launch per trigger |
| `platform_version` | "LATEST" | Fargate platform version |
| `containerOverrides` | -- | Override command, env vars at runtime |

## Schedule Expression Syntax

| Expression | Runs |
|------------|------|
| `rate(1 hour)` | Every hour |
| `rate(5 minutes)` | Every 5 minutes |
| `cron(0 2 * * ? *)` | Daily at 2:00 AM UTC |
| `cron(0 9 ? * MON-FRI *)` | Weekdays at 9:00 AM UTC |
| `cron(0 0 1 * ? *)` | First day of every month |
| `cron(0/15 * * * ? *)` | Every 15 minutes |

## One-Off Task Runs

```bash
# Run a task manually via AWS CLI
aws ecs run-task \
  --cluster production \
  --task-definition etl-job:5 \
  --launch-type FARGATE \
  --network-configuration '{
    "awsvpcConfiguration": {
      "subnets": ["subnet-abc123"],
      "securityGroups": ["sg-def456"],
      "assignPublicIp": "DISABLED"
    }
  }' \
  --overrides '{
    "containerOverrides": [{
      "name": "etl",
      "command": ["python", "backfill.py", "--start", "2026-01-01"],
      "environment": [
        {"name": "BATCH_SIZE", "value": "1000"}
      ]
    }]
  }'
```

## Monitoring Scheduled Tasks

```bash
# List recent task runs for a task definition
aws ecs list-tasks \
  --cluster production \
  --family etl-job \
  --desired-status STOPPED

# Check task exit code and stop reason
aws ecs describe-tasks \
  --cluster production \
  --tasks arn:aws:ecs:us-east-1:123456789012:task/production/abc123 \
  --query 'tasks[0].{status:lastStatus,stopCode:stopCode,reason:stoppedReason}'
```

## Example Usage

### CloudWatch Alarm on Task Failure

```hcl
resource "aws_cloudwatch_metric_alarm" "etl_failure" {
  alarm_name          = "etl-task-failure"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FailedInvocations"
  namespace           = "AWS/Events"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    RuleName = aws_cloudwatch_event_rule.daily_etl.name
  }
}
```

## Anti-Patterns

| Don't | Do |
|-------|-----|
| Use Lambda for jobs > 15 min or > 10 GB | Use Fargate scheduled tasks |
| Forget to set stop timeout | Set `stopTimeout` in container definition (default 30s) |
| Run scheduled tasks in public subnets | Use private subnets with NAT Gateway |
| Skip monitoring on scheduled tasks | Add CloudWatch alarms for FailedInvocations |
| Hardcode dates in container command | Pass dates via `containerOverrides` or environment |

## See Also

- [service-deployment](service-deployment.md)
- [../concepts/task-definitions](../concepts/task-definitions.md)
- [../concepts/pricing-model](../concepts/pricing-model.md)
- [CloudWatch KB](../../cloudwatch/)
