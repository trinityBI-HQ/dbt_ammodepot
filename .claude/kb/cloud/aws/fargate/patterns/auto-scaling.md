# Auto-Scaling

> **Purpose**: Configure Application Auto Scaling for ECS Fargate with target tracking, step scaling, and scheduled scaling
> **MCP Validated**: 2026-03-01

## When to Use

- Handling variable traffic patterns on API services
- Scaling batch workers based on queue depth
- Reducing costs during off-peak hours with scheduled scaling
- Maintaining SLA targets with predictable scale-out behavior

## Implementation

### Terraform: Target Tracking Scaling

```hcl
# Register the ECS service as a scalable target
resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = 20
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.api.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Scale based on average CPU utilization
resource "aws_appautoscaling_policy" "cpu" {
  name               = "cpu-target-tracking"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Scale based on average memory utilization
resource "aws_appautoscaling_policy" "memory" {
  name               = "memory-target-tracking"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = 80.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Scale based on ALB request count per target
resource "aws_appautoscaling_policy" "requests" {
  name               = "request-count-tracking"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label = "${aws_lb.main.arn_suffix}/${aws_lb_target_group.app.arn_suffix}"
    }
    target_value       = 1000.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `min_capacity` | -- | Minimum number of tasks (never scale below) |
| `max_capacity` | -- | Maximum number of tasks (cost safety) |
| `target_value` | -- | Target metric value to maintain |
| `scale_out_cooldown` | 300 | Seconds to wait after scale-out before next |
| `scale_in_cooldown` | 300 | Seconds to wait after scale-in before next |

## Predefined Metrics

| Metric | Type | Best For |
|--------|------|----------|
| `ECSServiceAverageCPUUtilization` | CPU | Compute-bound workloads |
| `ECSServiceAverageMemoryUtilization` | Memory | Memory-bound workloads |
| `ALBRequestCountPerTarget` | Requests | Request-driven APIs behind ALB |

## Step Scaling

For fine-grained control when metrics fluctuate unpredictably:

```hcl
resource "aws_appautoscaling_policy" "step_scale_out" {
  name               = "step-scale-out"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      metric_interval_upper_bound = 20
      scaling_adjustment          = 2
    }

    step_adjustment {
      metric_interval_lower_bound = 20
      scaling_adjustment          = 4
    }
  }
}
```

## Scheduled Scaling

Scale proactively for known traffic patterns (e.g., business hours):

```hcl
# Scale up for business hours (Mon-Fri 8 AM UTC)
resource "aws_appautoscaling_scheduled_action" "scale_up" {
  name               = "scale-up-business-hours"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace
  schedule           = "cron(0 8 ? * MON-FRI *)"

  scalable_target_action {
    min_capacity = 5
    max_capacity = 20
  }
}

# Scale down for off-hours (Mon-Fri 8 PM UTC)
resource "aws_appautoscaling_scheduled_action" "scale_down" {
  name               = "scale-down-off-hours"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace
  schedule           = "cron(0 20 ? * MON-FRI *)"

  scalable_target_action {
    min_capacity = 2
    max_capacity = 5
  }
}
```

## Example Usage

```bash
# Check current scaling policies
aws application-autoscaling describe-scaling-policies \
  --service-namespace ecs \
  --resource-id service/production/api-service

# Manually set desired count (overrides auto-scaling temporarily)
aws ecs update-service --cluster production --service api-service --desired-count 10
```

For custom metrics (e.g., SQS queue depth), use `customized_metric_specification` with `metric_name`, `namespace`, and `statistic` instead of `predefined_metric_specification`.

## Anti-Patterns

| Don't | Do |
|-------|-----|
| Set same scale-in and scale-out cooldowns | Use shorter scale-out (60s) and longer scale-in (300s) |
| Scale on CPU alone for I/O-bound services | Use ALBRequestCountPerTarget or custom metrics |
| Set min_capacity to 0 for APIs | Keep min >= 2 for HA (use scheduled scaling for dev) |
| Forget max_capacity cost guard | Set max to prevent runaway scaling costs |
| Use only one scaling metric | Combine CPU + request count for comprehensive coverage |

## See Also

- [service-deployment](service-deployment.md)
- [task-scheduling](task-scheduling.md)
- [../concepts/pricing-model](../concepts/pricing-model.md)
- [../concepts/task-definitions](../concepts/task-definitions.md)
- [CloudWatch KB](../../cloudwatch/)
