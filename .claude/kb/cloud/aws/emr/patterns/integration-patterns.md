# Integration Patterns

> **Purpose**: Integrating EMR with Glue Catalog, Step Functions, Airflow, Dagster, and Lake Formation
> **MCP Validated**: 2026-03-01

## When to Use

- Orchestrating EMR jobs in data pipelines
- Using Glue Data Catalog as a shared metastore
- Applying Lake Formation security to EMR workloads
- Triggering EMR jobs from external events

## Glue Data Catalog Integration

Use Glue as the Hive metastore for cross-service catalog sharing:

```json
[
  {
    "Classification": "spark-hive-site",
    "Properties": {
      "hive.metastore.client.factory.class":
        "com.amazonaws.glue.catalog.metastore.AWSGlueDataCatalogHiveClientFactory"
    }
  },
  {
    "Classification": "hive-site",
    "Properties": {
      "hive.metastore.client.factory.class":
        "com.amazonaws.glue.catalog.metastore.AWSGlueDataCatalogHiveClientFactory"
    }
  }
]
```

Benefits:
- Tables visible in Athena, Redshift Spectrum, Glue ETL, EMR
- Crawlers auto-discover schemas
- Lake Formation governs access
- Data Catalog Views (cross-engine SQL views, Glue 5.0+)

## Step Functions Orchestration

```json
{
  "StartAt": "CreateCluster",
  "States": {
    "CreateCluster": {
      "Type": "Task",
      "Resource": "arn:aws:states:::elasticmapreduce:createCluster.sync",
      "Parameters": {
        "Name": "ETL Pipeline",
        "ReleaseLabel": "emr-7.12.0",
        "Applications": [{"Name": "Spark"}],
        "Instances": {
          "MasterInstanceType": "m5.xlarge",
          "SlaveInstanceType": "m5.2xlarge",
          "InstanceCount": 5,
          "KeepJobFlowAliveWhenNoSteps": true
        },
        "ServiceRole": "EMR_DefaultRole",
        "JobFlowRole": "EMR_EC2_DefaultRole"
      },
      "ResultPath": "$.ClusterId",
      "Next": "SubmitSparkStep"
    },
    "SubmitSparkStep": {
      "Type": "Task",
      "Resource": "arn:aws:states:::elasticmapreduce:addStep.sync",
      "Parameters": {
        "ClusterId.$": "$.ClusterId.ClusterId",
        "Step": {
          "Name": "Spark ETL",
          "ActionOnFailure": "CONTINUE",
          "HadoopJarStep": {
            "Jar": "command-runner.jar",
            "Args": ["spark-submit", "--deploy-mode", "cluster",
                     "s3://scripts/etl.py"]
          }
        }
      },
      "Next": "TerminateCluster"
    },
    "TerminateCluster": {
      "Type": "Task",
      "Resource": "arn:aws:states:::elasticmapreduce:terminateCluster.sync",
      "Parameters": {
        "ClusterId.$": "$.ClusterId.ClusterId"
      },
      "End": true
    }
  }
}
```

## Airflow Integration

```python
from airflow.providers.amazon.aws.operators.emr import (
    EmrCreateJobFlowOperator,
    EmrAddStepsOperator,
    EmrTerminateJobFlowOperator,
)
from airflow.providers.amazon.aws.sensors.emr import EmrStepSensor

# Create cluster
create_cluster = EmrCreateJobFlowOperator(
    task_id="create_emr_cluster",
    job_flow_overrides={
        "Name": "airflow-spark",
        "ReleaseLabel": "emr-7.12.0",
        "Applications": [{"Name": "Spark"}],
        "Instances": {
            "MasterInstanceType": "m5.xlarge",
            "SlaveInstanceType": "m5.2xlarge",
            "InstanceCount": 5,
            "KeepJobFlowAliveWhenNoSteps": True,
        },
    },
)

# Submit step
add_step = EmrAddStepsOperator(
    task_id="add_spark_step",
    job_flow_id="{{ task_instance.xcom_pull(task_ids='create_emr_cluster') }}",
    steps=[{
        "Name": "Spark ETL",
        "ActionOnFailure": "CONTINUE",
        "HadoopJarStep": {
            "Jar": "command-runner.jar",
            "Args": ["spark-submit", "--deploy-mode", "cluster",
                     "s3://scripts/etl.py"],
        },
    }],
)

# Wait for step completion
watch_step = EmrStepSensor(
    task_id="watch_step",
    job_flow_id="{{ task_instance.xcom_pull(task_ids='create_emr_cluster') }}",
    step_id="{{ task_instance.xcom_pull(task_ids='add_spark_step')[0] }}",
)

# Terminate cluster
terminate = EmrTerminateJobFlowOperator(
    task_id="terminate_cluster",
    job_flow_id="{{ task_instance.xcom_pull(task_ids='create_emr_cluster') }}",
)

create_cluster >> add_step >> watch_step >> terminate
```

## Dagster Integration

Use `dagster-aws` package with `emr_pyspark_step_launcher` to run Spark assets as EMR steps. Dagster handles cluster lifecycle and step monitoring.

## EMR Serverless with Step Functions

Use `arn:aws:states:::emr-serverless:startJobRun.sync` resource in Step Functions to submit Serverless job runs with synchronous completion tracking.

## S3 Event-Triggered EMR

```python
# Lambda triggered by S3 event -> starts EMR Serverless job
import boto3

def handler(event, context):
    client = boto3.client("emr-serverless")
    bucket = event["Records"][0]["s3"]["bucket"]["name"]
    key = event["Records"][0]["s3"]["object"]["key"]

    client.start_job_run(
        applicationId="app-xxxxx",
        executionRoleArn="arn:aws:iam::role/EMRServerlessRole",
        jobDriver={
            "sparkSubmit": {
                "entryPoint": "s3://scripts/process_file.py",
                "entryPointArguments": [f"s3://{bucket}/{key}"],
            }
        },
    )
```

## Configuration

| Integration | EMR Mode | Key Service |
|------------|----------|-------------|
| Step Functions | EC2, Serverless | `states:::elasticmapreduce:*` |
| Airflow | EC2 | `apache-airflow-providers-amazon` |
| Dagster | EC2 | `dagster-aws` |
| EventBridge | EC2, Serverless | Event rules + Lambda |
| Glue Catalog | All | Hive metastore config |

## See Also

- [Spark Submit Patterns](spark-submit-patterns.md) -- Job submission methods
- [Spark on EMR](../concepts/spark-on-emr.md) -- Glue Catalog setup
- [Dagster KB](../../../../data-engineering/orchestration/dagster/) -- Dagster fundamentals
- [AWS Glue KB](../../glue/) -- Glue Data Catalog
