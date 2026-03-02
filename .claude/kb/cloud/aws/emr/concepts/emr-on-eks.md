# EMR on EKS

> **Purpose**: Running EMR Spark workloads on existing Amazon EKS clusters
> **Confidence**: 0.95
> **MCP Validated**: 2026-03-01

## Overview

EMR on EKS lets you run Apache Spark jobs on Amazon EKS clusters without provisioning dedicated EMR infrastructure. Jobs run in Kubernetes pods, sharing compute with other K8s workloads. This is ideal for organizations that have already invested in EKS and want to consolidate big data processing onto their existing Kubernetes platform.

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Virtual Cluster** | Logical EMR cluster mapped to an EKS namespace |
| **Job Run** | A Spark application submitted to a virtual cluster |
| **Managed Endpoint** | Interactive HTTPS endpoint for notebooks (EMR Studio) |
| **Pod Template** | Customizes driver/executor pods (resources, tolerations, volumes) |

## Architecture

```
EKS Cluster
├── Namespace: spark-prod
│   └── Virtual Cluster: vc-prod
│       ├── Job Run: daily-etl (driver pod + executor pods)
│       └── Job Run: hourly-agg (driver pod + executor pods)
├── Namespace: spark-dev
│   └── Virtual Cluster: vc-dev
│       └── Managed Endpoint (EMR Studio notebooks)
└── Namespace: app-services
    └── (other K8s workloads)
```

## Setup Flow

```bash
# 1. Create EKS namespace
kubectl create namespace spark-prod

# 2. Register EKS cluster with EMR
aws emr-containers create-virtual-cluster \
  --name vc-prod \
  --container-provider '{
    "id": "my-eks-cluster",
    "type": "EKS",
    "info": {"eksInfo": {"namespace": "spark-prod"}}
  }'

# 3. Create IAM role for job execution
# Trust policy: emr-containers.amazonaws.com
# Permissions: S3 access, Glue Catalog, CloudWatch Logs

# 4. Submit a job
aws emr-containers start-job-run \
  --virtual-cluster-id vc-xxxxx \
  --name daily-etl \
  --execution-role-arn arn:aws:iam::role/EMRJobRole \
  --release-label emr-7.12.0-latest \
  --job-driver '{
    "sparkSubmitJobDriver": {
      "entryPoint": "s3://scripts/etl.py",
      "sparkSubmitParameters": "--conf spark.executor.instances=10"
    }
  }'
```

## Pod Templates

Customize Spark driver and executor pods:

```yaml
# pod-template.yaml
apiVersion: v1
kind: Pod
spec:
  nodeSelector:
    node-type: spark-compute
  tolerations:
    - key: "spark"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"
  containers:
    - name: spark-kubernetes-executor
      resources:
        requests:
          memory: "8Gi"
          cpu: "2"
        limits:
          memory: "10Gi"
          cpu: "4"
      volumeMounts:
        - name: spark-local
          mountPath: /data
  volumes:
    - name: spark-local
      emptyDir:
        sizeLimit: 100Gi
```

## When to Use EMR on EKS

| Scenario | EMR on EKS | EMR on EC2 | EMR Serverless |
|----------|:----------:|:----------:|:--------------:|
| Existing EKS infrastructure | Best | -- | -- |
| Multi-tenant Spark | Best | OK | Limited |
| Fine-grained K8s controls | Best | -- | -- |
| Simplest setup | -- | OK | Best |
| No K8s expertise | -- | Best | Best |
| HBase/Presto long-running | -- | Best | -- |

## Cost Benefits

- **No idle clusters**: Jobs run as pods, terminated when complete
- **Shared infrastructure**: EKS nodes serve multiple workloads
- **Spot via Karpenter/CAS**: Existing K8s node auto-scaling handles Spot
- **Graviton nodes**: Use `arm64` node groups for Spark executors

## Limitations

- Spark only (no Hive, HBase, Presto)
- No HDFS (S3 only via EMRFS)
- Requires EKS expertise for pod templates and node management
- Managed endpoints require ALB setup

## Common Mistakes

### Wrong

```bash
# Running EMR on EKS without namespace isolation
# All jobs share default namespace -- no multi-tenancy
```

### Correct

```bash
# Separate namespaces per team/environment
kubectl create namespace spark-prod
kubectl create namespace spark-staging
# Each namespace gets its own virtual cluster
```

## Related

- [Cluster Architecture](cluster-architecture.md) -- EMR on EC2 comparison
- [Spark Submit Patterns](../patterns/spark-submit-patterns.md) -- Job submission
- [Integration Patterns](../patterns/integration-patterns.md) -- Orchestration
