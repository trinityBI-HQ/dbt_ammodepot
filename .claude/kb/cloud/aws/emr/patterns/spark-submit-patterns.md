# Spark Submit Patterns

> **Purpose**: Methods for submitting and orchestrating Spark jobs on EMR
> **MCP Validated**: 2026-03-01

## When to Use

- Submitting Spark applications to EMR clusters (EC2, EKS, Serverless)
- Orchestrating multi-step ETL pipelines
- Choosing between Step API, spark-submit, and notebook-based execution

## Submission Methods

| Method | Mode | Best For |
|--------|------|----------|
| EMR Steps API | EC2 | Automated pipelines, orchestration |
| spark-submit (SSH) | EC2 | Interactive development, debugging |
| EMR Serverless job runs | Serverless | Batch jobs, no cluster management |
| EMR on EKS job runs | EKS | Kubernetes-native teams |
| EMR Studio notebooks | All | Interactive exploration, prototyping |

## EMR Steps API

```bash
# Add a Spark step to a running cluster
aws emr add-steps \
  --cluster-id j-XXXXXXXXXXXXX \
  --steps '[{
    "Name": "Sales ETL",
    "ActionOnFailure": "CONTINUE",
    "HadoopJarStep": {
      "Jar": "command-runner.jar",
      "Args": [
        "spark-submit",
        "--deploy-mode", "cluster",
        "--master", "yarn",
        "--conf", "spark.executor.instances=20",
        "--conf", "spark.executor.memory=8g",
        "--conf", "spark.executor.cores=4",
        "--py-files", "s3://scripts/utils.zip",
        "s3://scripts/sales_etl.py",
        "--date", "2026-03-01",
        "--output", "s3://data-lake/gold/sales/"
      ]
    }
  }]'
```

### ActionOnFailure Options

| Action | Behavior |
|--------|----------|
| `TERMINATE_CLUSTER` | Stop cluster on step failure |
| `TERMINATE_JOB_FLOW` | Same as above (alias) |
| `CANCEL_AND_WAIT` | Cancel remaining steps, keep cluster |
| `CONTINUE` | Run next step regardless |

## spark-submit via SSH

```bash
# SSH to master node
aws emr ssh --cluster-id j-XXXXX --key-pair-file ~/key.pem

# Submit in cluster mode (driver on YARN)
spark-submit \
  --deploy-mode cluster \
  --master yarn \
  --num-executors 20 \
  --executor-cores 4 \
  --executor-memory 8g \
  --driver-memory 4g \
  --conf spark.sql.adaptive.enabled=true \
  --conf spark.dynamicAllocation.enabled=true \
  --packages org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:1.10.0 \
  s3://scripts/etl.py

# Submit in client mode (driver on master -- for debugging)
spark-submit \
  --deploy-mode client \
  --master yarn \
  s3://scripts/debug_job.py
```

## EMR Serverless Job Run

```bash
aws emr-serverless start-job-run \
  --application-id app-xxxxx \
  --execution-role-arn arn:aws:iam::role/EMRServerlessRole \
  --job-driver '{
    "sparkSubmit": {
      "entryPoint": "s3://scripts/etl.py",
      "entryPointArguments": ["--date", "2026-03-01"],
      "sparkSubmitParameters": "--conf spark.executor.cores=4 --conf spark.executor.memory=16g --conf spark.dynamicAllocation.enabled=true"
    }
  }' \
  --configuration-overrides '{
    "monitoringConfiguration": {
      "s3MonitoringConfiguration": {
        "logUri": "s3://logs/emr-serverless/"
      }
    }
  }'
```

## EMR on EKS Job Run

```bash
aws emr-containers start-job-run \
  --virtual-cluster-id vc-xxxxx \
  --name daily-etl \
  --execution-role-arn arn:aws:iam::role/EMRJobRole \
  --release-label emr-7.12.0-latest \
  --job-driver '{
    "sparkSubmitJobDriver": {
      "entryPoint": "s3://scripts/etl.py",
      "sparkSubmitParameters": "--conf spark.executor.instances=10 --conf spark.kubernetes.executor.request.cores=2"
    }
  }' \
  --configuration-overrides '{
    "applicationConfiguration": [{
      "classification": "spark-defaults",
      "properties": {
        "spark.dynamicAllocation.enabled": "true"
      }
    }]
  }'
```

## Multi-Step Pipeline

```bash
# Chain multiple steps -- executed sequentially
aws emr add-steps --cluster-id j-XXXXX --steps '[
  {
    "Name": "Step 1: Extract",
    "ActionOnFailure": "CANCEL_AND_WAIT",
    "HadoopJarStep": {
      "Jar": "command-runner.jar",
      "Args": ["spark-submit", "--deploy-mode", "cluster",
               "s3://scripts/extract.py"]
    }
  },
  {
    "Name": "Step 2: Transform",
    "ActionOnFailure": "CANCEL_AND_WAIT",
    "HadoopJarStep": {
      "Jar": "command-runner.jar",
      "Args": ["spark-submit", "--deploy-mode", "cluster",
               "s3://scripts/transform.py"]
    }
  },
  {
    "Name": "Step 3: Load",
    "ActionOnFailure": "TERMINATE_CLUSTER",
    "HadoopJarStep": {
      "Jar": "command-runner.jar",
      "Args": ["spark-submit", "--deploy-mode", "cluster",
               "s3://scripts/load.py"]
    }
  }
]'
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `--deploy-mode` | client | `client` (driver on master) or `cluster` (driver on YARN) |
| `--master` | yarn | Resource manager (`yarn`, `local[*]`) |
| `--num-executors` | dynamic | Fixed executor count (disable dynamic allocation) |
| `--packages` | -- | Maven coordinates for JAR dependencies |
| `--py-files` | -- | Python .zip/.egg files to distribute |

## See Also

- [Cluster Architecture](../concepts/cluster-architecture.md) -- Node topology
- [EMR Serverless](../concepts/emr-serverless.md) -- Serverless job runs
- [Integration Patterns](integration-patterns.md) -- Orchestration with Step Functions
