# ECS Fargate Deployment — dbt-core

Runs `dbt build` every 10 minutes on ECS Fargate Spot. Replaces dbt Cloud (~$663/mo → ~$3/mo).

## Architecture

```
EventBridge (rate: 10 min)
    │
    ▼
ECS Fargate Spot (0.5 vCPU, 1 GB)
    │  ← Secrets Manager (RSA key)
    │  ← ECR (Docker image)
    │
    ▼
Snowflake (ETL_WH, TRANSFORMER_ROLE)
    │
    ▼
CloudWatch Logs (14-day retention)
```

## Prerequisites

- AWS CLI configured with appropriate permissions
- Docker installed locally
- The Snowflake RSA private key file (`dbt_rsa_key.p8`)

## Setup (One-Time)

Replace `ACCOUNT_ID` with your AWS account ID in all commands below.

### Step 1: Create ECR Repository

```bash
aws ecr create-repository \
    --repository-name ammodepot/dbt \
    --region us-east-1 \
    --image-scanning-configuration scanOnPush=true
```

Set lifecycle policy (keep last 5 images):

```bash
aws ecr put-lifecycle-policy \
    --repository-name ammodepot/dbt \
    --lifecycle-policy-text '{
        "rules": [{
            "rulePriority": 1,
            "description": "Keep last 5 images",
            "selection": {
                "tagStatus": "any",
                "countType": "imageCountMoreThan",
                "countNumber": 5
            },
            "action": {"type": "expire"}
        }]
    }'
```

### Step 2: Create Secrets Manager Secret

```bash
aws secretsmanager create-secret \
    --name ammodepot/dbt/snowflake \
    --description "Snowflake SVC_DBT RSA key for dbt ECS task" \
    --secret-string '{
        "SNOWFLAKE_PRIVATE_KEY": "<paste PEM content here>",
        "SNOWFLAKE_PRIVATE_KEY_PASSPHRASE": "<passphrase>"
    }'
```

To get the PEM content: `cat dbt_rsa_key.p8 | jq -Rs .` (outputs escaped string).

### Step 3: Create CloudWatch Log Group

```bash
aws logs create-log-group \
    --log-group-name /ecs/ammodepot-dbt \
    --region us-east-1

aws logs put-retention-policy \
    --log-group-name /ecs/ammodepot-dbt \
    --retention-in-days 14
```

### Step 4: Create Security Group

```bash
aws ec2 create-security-group \
    --group-name ammodepot-dbt-fargate-sg \
    --description "dbt Fargate task - outbound HTTPS only" \
    --vpc-id <VPC_ID>

# Outbound HTTPS only (inbound is blocked by default)
aws ec2 authorize-security-group-egress \
    --group-id <SG_ID> \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0
```

### Step 5: Create IAM Roles

**Task Execution Role** (pulls image, reads secrets, writes logs):

```bash
aws iam create-role \
    --role-name ecsTaskExecutionRole-dbt \
    --assume-role-policy-document file://ecs/iam-policies/task-execution-trust.json

aws iam put-role-policy \
    --role-name ecsTaskExecutionRole-dbt \
    --policy-name dbt-task-execution \
    --policy-document file://ecs/iam-policies/task-execution-role.json
```

**Task Role** (empty — container only talks to Snowflake):

```bash
aws iam create-role \
    --role-name ecsTaskRole-dbt \
    --assume-role-policy-document file://ecs/iam-policies/task-execution-trust.json
```

**EventBridge Role** (triggers ECS tasks):

```bash
aws iam create-role \
    --role-name eventbridge-ecs-dbt \
    --assume-role-policy-document file://ecs/iam-policies/eventbridge-trust.json

aws iam put-role-policy \
    --role-name eventbridge-ecs-dbt \
    --policy-name dbt-eventbridge \
    --policy-document file://ecs/iam-policies/eventbridge-role.json
```

### Step 6: Create ECS Cluster

```bash
aws ecs create-cluster \
    --cluster-name ammodepot-dbt \
    --capacity-providers FARGATE_SPOT FARGATE \
    --default-capacity-provider-strategy capacityProvider=FARGATE_SPOT,weight=1,base=0 \
    --setting name=containerInsights,value=enabled
```

### Step 7: Build and Push Docker Image

```bash
./scripts/deploy-ecs.sh
```

### Step 8: Register Task Definition

Edit `ecs/task-definition.json` — replace all `ACCOUNT_ID` placeholders, then:

```bash
aws ecs register-task-definition \
    --cli-input-json file://ecs/task-definition.json
```

### Step 9: Test — Manual Run

```bash
aws ecs run-task \
    --cluster ammodepot-dbt \
    --task-definition ammodepot-dbt-build \
    --launch-type FARGATE \
    --network-configuration '{
        "awsvpcConfiguration": {
            "subnets": ["PRIVATE_SUBNET_ID"],
            "securityGroups": ["SECURITY_GROUP_ID"],
            "assignPublicIp": "DISABLED"
        }
    }'
```

Check CloudWatch Logs → `/ecs/ammodepot-dbt` for output.

### Step 10: Create EventBridge Schedule

Edit `ecs/eventbridge-rule.json` — replace placeholders, then:

```bash
aws events put-rule \
    --name ammodepot-dbt-build-schedule \
    --schedule-expression "rate(10 minutes)" \
    --state ENABLED

aws events put-targets \
    --rule ammodepot-dbt-build-schedule \
    --targets file://ecs/eventbridge-rule.json
```

### Step 11: Verify and Cutover

1. Watch 3-5 scheduled runs in CloudWatch
2. Confirm all 99 models pass
3. Remove local crontab: `crontab -r`
4. Pause/cancel dbt Cloud job

## Deploying Updates

After changing dbt models, push a new image:

```bash
git push origin main
./scripts/deploy-ecs.sh
```

The next scheduled run (within 10 min) picks up the new image automatically.

## Cost

| Resource | Monthly |
|---|---|
| Fargate Spot (0.5 vCPU, 1 GB, ~3.5 min × 4,320 runs) | ~$1.50 |
| CloudWatch Logs (14-day retention) | ~$0.50 |
| Secrets Manager (1 secret) | ~$0.45 |
| ECR (< 1 GB) | ~$0.10 |
| EventBridge | Free |
| **Total** | **~$2.55/mo** |

## Troubleshooting

**Task fails to start:**
- Check CloudWatch Logs → `/ecs/ammodepot-dbt`
- Verify Secrets Manager secret exists and has correct key names
- Verify security group allows outbound 443

**dbt build fails:**
- Same debugging as local: check model SQL, Snowflake connectivity
- Run manually: `aws ecs run-task ...` and watch logs

**Spot interruption:**
- Task is idempotent — next run (10 min) succeeds
- If frequent, change capacity provider to FARGATE (on-demand)

**Key rotation:**
- Update Secrets Manager secret — no image rebuild needed
