# Service Deployment

> **Purpose**: Deploy ECS Fargate services with ALB, blue/green and rolling update strategies
> **MCP Validated**: 2026-03-01

## When to Use

- Deploying long-running containerized APIs or web applications
- Requiring load balancing across multiple tasks
- Needing zero-downtime deployments with automated rollback
- Running production services with health check monitoring

## Implementation

### Terraform: ECS Service with ALB

```hcl
# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "production"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "api-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnets
}

resource "aws_lb_target_group" "app" {
  name        = "api-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  deregistration_delay = 30
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ECS Service
resource "aws_ecs_service" "api" {
  name            = "api-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnets
    security_groups  = [aws_security_group.fargate_task.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "api"
    container_port   = 8080
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  lifecycle {
    ignore_changes = [task_definition]
  }
}
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `desired_count` | 1 | Number of task instances to maintain |
| `deployment_maximum_percent` | 200 | Max tasks during deployment (% of desired) |
| `deployment_minimum_healthy_percent` | 100 | Min healthy tasks during deployment |
| `health_check_grace_period_seconds` | 0 | Seconds before health checks begin |
| `deployment_circuit_breaker.enable` | false | Auto-rollback on deployment failure |
| `deregistration_delay` | 300 | Seconds for ALB to drain connections |

## Deployment Strategies

### Rolling Update (Default)

Gradually replaces old tasks with new ones. With 200% max / 100% min, ECS launches new tasks before draining old ones.

```text
Time 0:  [v1] [v1] [v1]         (desired: 3)
Time 1:  [v1] [v1] [v1] [v2]   (new task starting)
Time 2:  [v1] [v1] [v2] [v2]   (old task draining)
Time 3:  [v1] [v2] [v2] [v2]   (continuing rollout)
Time 4:  [v2] [v2] [v2]         (complete)
```

### Blue/Green (ECS Native, July 2025)

ECS-native blue/green maintains two task sets. Traffic shifts after health checks pass.

```hcl
resource "aws_ecs_service" "api" {
  deployment_controller {
    type = "CODE_DEPLOY"
  }
}

resource "aws_codedeploy_deployment_group" "ecs" {
  app_name               = aws_codedeploy_app.ecs.name
  deployment_group_name  = "api-deploy-group"
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  service_role_arn       = aws_iam_role.codedeploy.arn

  ecs_service {
    cluster_name = aws_ecs_cluster.main.name
    service_name = aws_ecs_service.api.name
  }

  blue_green_deployment_config {
    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }

    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route { listener_arns = [aws_lb_listener.https.arn] }
      target_group { name = aws_lb_target_group.blue.name }
      target_group { name = aws_lb_target_group.green.name }
    }
  }
}
```

## Example Usage

```bash
# Force a new deployment (picks up latest image from ECR)
aws ecs update-service \
  --cluster production \
  --service api-service \
  --force-new-deployment

# Update to a new task definition revision
aws ecs update-service \
  --cluster production \
  --service api-service \
  --task-definition api:42
```

## Anti-Patterns

| Don't | Do |
|-------|-----|
| Set `minimum_healthy_percent: 0` in production | Keep at 100% for zero-downtime |
| Skip health checks on target groups | Configure meaningful health check endpoints |
| Use default 300s deregistration delay | Set 30-60s for faster deployments |
| Ignore circuit breaker | Enable with rollback for automatic failure recovery |

## See Also

- [auto-scaling](auto-scaling.md), [cicd-pipeline](cicd-pipeline.md)
- [../concepts/task-definitions](../concepts/task-definitions.md), [../concepts/networking](../concepts/networking.md)
