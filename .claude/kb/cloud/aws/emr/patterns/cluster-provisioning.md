# Cluster Provisioning

> **Purpose**: Terraform and AWS CLI patterns for creating EMR clusters with bootstrap actions
> **MCP Validated**: 2026-03-01

## When to Use

- Deploying reproducible EMR clusters via IaC
- Configuring bootstrap actions for cluster initialization
- Setting up instance fleets with Spot and managed scaling

## Terraform: aws_emr_cluster

```hcl
resource "aws_emr_cluster" "spark" {
  name          = "spark-analytics"
  release_label = "emr-7.12.0"
  applications  = ["Spark", "Hive"]
  service_role  = aws_iam_role.emr_service.arn

  ec2_attributes {
    instance_profile                  = aws_iam_instance_profile.emr_ec2.arn
    subnet_id                         = var.private_subnet_id
    emr_managed_master_security_group = aws_security_group.emr_master.id
    emr_managed_slave_security_group  = aws_security_group.emr_core.id
    key_name                          = var.key_pair_name
  }

  master_instance_group {
    instance_type  = "m5.xlarge"
    instance_count = 1
  }

  core_instance_group {
    instance_type  = "m5.2xlarge"
    instance_count = 4
    ebs_config {
      size                 = 500
      type                 = "gp3"
      volumes_per_instance = 2
    }
  }

  # Bootstrap: install Python packages
  bootstrap_action {
    name = "install-python-deps"
    path = "s3://my-bootstrap/install_deps.sh"
    args = ["pandas", "pyarrow", "boto3"]
  }

  # Spark and Hive configurations
  configurations_json = jsonencode([
    {
      Classification = "spark-defaults"
      Properties = {
        "spark.dynamicAllocation.enabled"    = "true"
        "spark.sql.adaptive.enabled"         = "true"
        "spark.serializer"                   = "org.apache.spark.serializer.KryoSerializer"
        "spark.sql.catalog.glue_catalog"     = "org.apache.iceberg.spark.SparkCatalog"
        "spark.sql.catalog.glue_catalog.catalog-impl" = "org.apache.iceberg.aws.glue.GlueCatalog"
      }
    },
    {
      Classification = "spark-hive-site"
      Properties = {
        "hive.metastore.client.factory.class" =
          "com.amazonaws.glue.catalog.metastore.AWSGlueDataCatalogHiveClientFactory"
      }
    }
  ])

  # Managed scaling
  auto_termination_policy {
    idle_timeout = 3600
  }

  tags = {
    Environment = var.environment
    Team        = "data-engineering"
  }

  lifecycle {
    ignore_changes = [configurations_json]
  }
}

# Managed scaling policy
resource "aws_emr_managed_scaling_policy" "spark" {
  cluster_id = aws_emr_cluster.spark.id

  compute_limits {
    unit_type                       = "Instances"
    minimum_capacity_units          = 4
    maximum_capacity_units          = 50
    maximum_ondemand_capacity_units = 10
    maximum_core_capacity_units     = 10
  }
}
```

## Terraform: Instance Fleets

```hcl
resource "aws_emr_instance_fleet" "task" {
  cluster_id = aws_emr_cluster.spark.id
  name       = "task-fleet"

  instance_type_configs {
    instance_type     = "m5.2xlarge"
    weighted_capacity = 8
  }
  instance_type_configs {
    instance_type     = "m5a.2xlarge"
    weighted_capacity = 8
  }
  instance_type_configs {
    instance_type     = "m6i.2xlarge"
    weighted_capacity = 8
  }
  instance_type_configs {
    instance_type     = "r5.2xlarge"
    weighted_capacity = 8
  }
  instance_type_configs {
    instance_type     = "c5.2xlarge"
    weighted_capacity = 8
  }

  target_spot_capacity    = 40
  target_on_demand_capacity = 0

  launch_specifications {
    spot_specification {
      allocation_strategy      = "capacity-optimized"
      timeout_action           = "SWITCH_TO_ON_DEMAND"
      timeout_duration_minutes = 10
    }
  }
}
```

## AWS CLI: Create Cluster

```bash
aws emr create-cluster \
  --name "spark-analytics" \
  --release-label emr-7.12.0 \
  --applications Name=Spark Name=Hive \
  --instance-groups \
    InstanceGroupType=MASTER,InstanceType=m5.xlarge,InstanceCount=1 \
    InstanceGroupType=CORE,InstanceType=m5.2xlarge,InstanceCount=4 \
  --ec2-attributes \
    KeyName=my-key,SubnetId=subnet-xxxxx,\
    InstanceProfile=EMR_EC2_DefaultRole \
  --service-role EMR_DefaultRole \
  --configurations file://spark-config.json \
  --bootstrap-actions Path=s3://bootstrap/install.sh,Args=[arg1,arg2] \
  --auto-termination-policy IdleTimeout=3600 \
  --managed-scaling-policy file://scaling-policy.json \
  --region us-east-1
```

## Bootstrap Actions

```bash
#!/bin/bash
# install_deps.sh -- Bootstrap action for Python packages
set -euo pipefail

sudo pip3 install pandas pyarrow boto3 great-expectations
sudo yum install -y htop tmux

# Configure Spark defaults
cat >> /etc/spark/conf/spark-defaults.conf <<EOF
spark.hadoop.fs.s3a.fast.upload true
spark.hadoop.fs.s3a.fast.upload.buffer disk
EOF
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `release_label` | -- | EMR version (use `emr-7.12.0`) |
| `auto_termination_policy` | None | Idle timeout in seconds |
| `keep_job_flow_alive` | true | Cluster stays up after steps complete |
| `termination_protection` | false | Prevent accidental termination |
| `log_uri` | None | S3 path for cluster logs |

## See Also

- [Cluster Architecture](../concepts/cluster-architecture.md) -- Node types, fleets
- [Cost Optimization](cost-optimization.md) -- Spot, Graviton, scaling
- [Terraform KB](../../../../devops-sre/iac/terraform/) -- Terraform fundamentals
