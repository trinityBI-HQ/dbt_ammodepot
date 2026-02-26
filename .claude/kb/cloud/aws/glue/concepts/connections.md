# Connections

> **Purpose**: Network and credential configuration for external data stores
> **Confidence**: 0.95
> **MCP Validated**: 2026-02-19

## Overview

Glue Connections store connection properties (URLs, credentials, VPC config) for data stores. Jobs and crawlers reference connections to access JDBC databases, streaming sources, and resources in private VPCs. Connections enable Glue to reach data behind firewalls.

## Connection Types

| Type | Use Case | Examples |
|------|----------|---------|
| **JDBC** | Relational databases | RDS, Aurora, Redshift, on-prem DBs |
| **NETWORK** | VPC-only resources | Private S3 endpoints, internal APIs |
| **KAFKA** | Streaming sources | Amazon MSK, self-managed Kafka |
| **MONGODB** | Document databases | MongoDB Atlas, DocumentDB |
| **CUSTOM** | Custom connectors | Marketplace or self-built connectors |

## The Pattern

```python
import boto3

glue = boto3.client("glue")

# JDBC connection to RDS PostgreSQL
glue.create_connection(
    ConnectionInput={
        "Name": "rds-postgres-sales",
        "ConnectionType": "JDBC",
        "ConnectionProperties": {
            "JDBC_CONNECTION_URL": "jdbc:postgresql://mydb.cluster-xyz.us-east-1.rds.amazonaws.com:5432/sales",
            "USERNAME": "glue_reader",
            "PASSWORD": "secret",  # Better: use Secrets Manager
        },
        "PhysicalConnectionRequirements": {
            "SubnetId": "subnet-abc123",
            "SecurityGroupIdList": ["sg-xyz789"],
            "AvailabilityZone": "us-east-1a",
        },
    }
)
```

## VPC Networking

Glue jobs using connections run inside the specified VPC:

```
┌─── VPC ───────────────────────────────┐
│  ┌── Private Subnet ──────────────┐   │
│  │  Glue Job (ENI attached)       │   │
│  │    ↓                           │   │
│  │  RDS / Redshift / ElastiCache  │   │
│  └────────────────────────────────┘   │
│  Security Group: Allow Glue → DB port │
│  NAT Gateway (if S3/internet needed)  │
└───────────────────────────────────────┘
```

**Requirements:**
- Subnet must have available IP addresses for ENIs
- Security group must allow self-referencing ingress (Glue-to-Glue)
- NAT Gateway or S3 VPC endpoint for S3 access from private subnets
- DNS resolution must be enabled in VPC

## Secrets Manager Integration

```python
# Reference Secrets Manager instead of inline credentials
connection_properties = {
    "JDBC_CONNECTION_URL": "jdbc:postgresql://...",
    "SECRET_ID": "arn:aws:secretsmanager:us-east-1:123:secret:glue/rds-creds",
}
```

## Kafka Connection

```python
glue.create_connection(
    ConnectionInput={
        "Name": "msk-connection",
        "ConnectionType": "KAFKA",
        "ConnectionProperties": {
            "KAFKA_BOOTSTRAP_SERVERS": "b-1.msk.us-east-1.amazonaws.com:9092",
            "KAFKA_SSL_ENABLED": "true",
        },
        "PhysicalConnectionRequirements": {
            "SubnetId": "subnet-abc123",
            "SecurityGroupIdList": ["sg-kafka"],
        },
    }
)
```

## Using Connections in Jobs

```python
# In ETL script -- read from JDBC via connection
dyf = glue_ctx.create_dynamic_frame.from_catalog(
    database="sales_db",
    table_name="jdbc_orders",  # Table defined with connection
    additional_options={
        "hashfield": "order_id",       # Parallel reads
        "hashpartitions": "10",        # 10 parallel JDBC connections
    },
)
```

## Common Mistakes

### Wrong

```python
# No VPC endpoint -- Glue in VPC can't reach S3
# Job fails with timeout errors accessing S3
```

### Correct

```
# Add S3 VPC Gateway Endpoint to route table
# Or add NAT Gateway for all external access
aws ec2 create-vpc-endpoint \
  --vpc-id vpc-xxx \
  --service-name com.amazonaws.us-east-1.s3 \
  --route-table-ids rtb-xxx
```

## Related

- [ETL Jobs](../concepts/etl-jobs.md)
- [Integration Patterns](../patterns/integration-patterns.md)
