# CI/CD Pipeline

> **Purpose**: Automated container build, push to ECR, and deploy to ECS Fargate via GitHub Actions
> **MCP Validated**: 2026-03-01

## When to Use

- Automating container image builds and deployments to ECS Fargate
- Implementing continuous delivery with automated rollback
- Managing task definition updates alongside code changes
- Deploying across multiple environments (dev, staging, production)

## Implementation

### GitHub Actions: Build and Deploy to ECS Fargate

```yaml
name: Deploy to ECS Fargate

on:
  push:
    branches: [main]

permissions:
  id-token: write
  contents: read

env:
  AWS_REGION: us-east-1
  ECR_REPOSITORY: my-api
  ECS_CLUSTER: production
  ECS_SERVICE: api-service
  TASK_DEFINITION: .aws/task-definition.json
  CONTAINER_NAME: api

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/github-actions-deploy
          aws-region: ${{ env.AWS_REGION }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build, tag, and push image
        id: build-image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          echo "image=$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG" >> $GITHUB_OUTPUT

      - name: Render new task definition
        id: task-def
        uses: aws-actions/amazon-ecs-render-task-definition@v1
        with:
          task-definition: ${{ env.TASK_DEFINITION }}
          container-name: ${{ env.CONTAINER_NAME }}
          image: ${{ steps.build-image.outputs.image }}

      - name: Deploy to ECS
        uses: aws-actions/amazon-ecs-deploy-task-definition@v2
        with:
          task-definition: ${{ steps.task-def.outputs.task-definition }}
          service: ${{ env.ECS_SERVICE }}
          cluster: ${{ env.ECS_CLUSTER }}
          wait-for-service-stability: true
          wait-for-minutes: 10
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `wait-for-service-stability` | false | Wait for ECS service to stabilize |
| `wait-for-minutes` | 30 | Timeout for stability check |
| `force-new-deployment` | false | Force deployment even if task def unchanged |
| `codedeploy-appspec` | -- | AppSpec file for CodeDeploy blue/green |

## IAM: OIDC Role for GitHub Actions

The deploy role needs: `ecr:*` (image push), `ecs:UpdateService`, `ecs:RegisterTaskDefinition`, `ecs:Describe*`, and `iam:PassRole` (to `ecs-tasks.amazonaws.com`). Use OIDC federation -- never static access keys.

```hcl
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

resource "aws_iam_role" "github_actions" {
  name = "github-actions-deploy"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
        StringLike   = { "token.actions.githubusercontent.com:sub" = "repo:my-org/my-repo:ref:refs/heads/main" }
      }
    }]
  })
}
```

## Task Definition File

Store `.aws/task-definition.json` in your repo. The `amazon-ecs-render-task-definition` action replaces the image `PLACEHOLDER` with the newly built URI. See `concepts/task-definitions.md` for the full JSON schema.

## Example Usage

### Multi-Environment Deployment

```yaml
jobs:
  deploy-staging:
    uses: ./.github/workflows/deploy.yml
    with:
      cluster: staging
      service: api-service
    secrets: inherit

  deploy-production:
    needs: deploy-staging
    uses: ./.github/workflows/deploy.yml
    with:
      cluster: production
      service: api-service
    secrets: inherit
    environment: production
```

## Anti-Patterns

| Don't | Do |
|-------|-----|
| Use long-lived IAM access keys in GitHub | Use OIDC federation (no static credentials) |
| Tag images as `latest` only | Tag with commit SHA for traceability |
| Skip `wait-for-service-stability` | Enable it to catch deployment failures |
| Store task definition only in Terraform | Keep a `.aws/task-definition.json` for CI/CD |
| Deploy directly to production | Use staging environment gate with approval |

## See Also

- [service-deployment](service-deployment.md)
- [auto-scaling](auto-scaling.md)
- [../concepts/task-definitions](../concepts/task-definitions.md)
- [IAM KB](../../iam/)
