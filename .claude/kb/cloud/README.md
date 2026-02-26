# Cloud Knowledge Base

> **Last Updated:** 2026-02-06
> **Maintained By:** Claude Code Lab Team

## Overview

Cloud infrastructure enables scalable, reliable application deployment without managing physical hardware. This category covers cloud provider services, deployment patterns, and best practices for building production systems.

## Philosophy

**Build cloud applications that are:**
- **Serverless-first**: Pay per use, auto-scale, no infrastructure management
- **Event-driven**: Decouple components with pub/sub and message queues
- **Observable**: Structured logging, metrics, and distributed tracing
- **Cost-optimized**: Right-size resources, leverage spot instances, monitor spending

**Avoid:**
- ❌ Always-on VMs for intermittent workloads (use serverless)
- ❌ Tight coupling between services (use event buses)
- ❌ Unmonitored cloud spending (set budgets and alerts)
- ❌ Single-region deployments for critical systems (use multi-region)

## Cloud Providers

### ☁️ GCP (Google Cloud Platform)

**Path:** [gcp/](gcp/)

**What it does:** Google's cloud platform with strong data/ML offerings and serverless compute.

**When to use GCP:**
- BigQuery-based analytics workloads
- TensorFlow/Vertex AI for ML
- Strong preference for Kubernetes (GKE is best-in-class)
- Integration with Google Workspace
- Cost-sensitive serverless workloads (Cloud Run is affordable)

**Key services covered:**
| Service | Use Case | Alternatives |
|---------|----------|--------------|
| **Cloud Run** | Containerized serverless apps | Lambda (AWS), Container Apps (Azure) |
| **Pub/Sub** | Event streaming and messaging | SNS+SQS (AWS), Event Grid (Azure) |
| **Cloud Functions** | Event-driven functions | Lambda, Azure Functions |
| **BigQuery** | Serverless data warehouse | Redshift, Synapse |
| **GCS (Cloud Storage)** | Object storage | S3, Blob Storage |
| **Cloud Scheduler** | Cron-based job scheduling | EventBridge, Logic Apps |

**Strengths:**
- ✅ Best serverless pricing (Cloud Run pay-per-request)
- ✅ BigQuery performance and ease-of-use
- ✅ Generous free tier
- ✅ GKE (Kubernetes) management
- ✅ Fast global network

**Considerations:**
- ⚠️ Smaller ecosystem than AWS
- ⚠️ Fewer managed services overall
- ⚠️ Documentation can be less comprehensive

### 🔵 AWS (Amazon Web Services)

**Path:** [aws/](aws/)

**What it does:** The most mature cloud provider with the largest ecosystem of managed services.

**When to use AWS:**
- Largest selection of managed services
- Enterprise compliance requirements (GovCloud, etc.)
- Mature ecosystem and tooling
- Strong third-party integrations

**Key services covered:**
| Service | Use Case | GCP Equivalent |
|---------|----------|----------------|
| **S3** | Object storage, data lake foundation | GCS |
| **Glue** | Serverless ETL, Data Catalog, crawlers | Dataflow + Data Catalog |
| **Athena** | Serverless SQL on S3 | BigQuery |
| **Lambda** | Event-driven functions | Cloud Functions |
| **Redshift** | Data warehouse | BigQuery |
| **Lake Formation** | Data lake governance | Dataplex |

**Strengths:**
- Most services and regions of any provider
- Strongest compliance certifications (GovCloud, HIPAA)
- Largest ecosystem of third-party integrations
- Mature IaC tooling (CloudFormation, CDK, SAM)

**Considerations:**
- Pricing complexity requires careful monitoring
- Service overlap can make architecture decisions harder
- Some services have steep learning curves

**Related Technologies:**
- See [gcp/](gcp/) for equivalent GCP services

### 🔷 Azure (Microsoft Cloud)

**Status:** Placeholder - Knowledge base content coming soon

**Why Azure?**
Azure is optimal for organizations invested in Microsoft technologies (Windows Server, .NET, Active Directory) and requiring hybrid cloud capabilities.

**When to use Azure:**
- Microsoft/Windows-centric workloads
- Hybrid cloud with on-premises Active Directory
- .NET application hosting
- Enterprise Microsoft 365 integration

**Related Technologies:**
- See [gcp/](gcp/) for equivalent GCP services

## Cloud Provider Comparison Matrix

| Factor | GCP | AWS | Azure |
|--------|-----|-----|-------|
| **Serverless Compute** | Cloud Run (containers) | Lambda (functions) | Container Apps |
| **Messaging** | Pub/Sub | SNS + SQS | Service Bus + Event Grid |
| **Object Storage** | GCS | S3 | Blob Storage |
| **Data Warehouse** | BigQuery | Redshift | Synapse Analytics |
| **Kubernetes** | ✅ GKE (best) | EKS | AKS |
| **ML Platform** | Vertex AI | SageMaker | Azure ML |
| **Pricing** | $$ Competitive | $$$ Premium | $$ Competitive |
| **Free Tier** | ✅ Generous | ✅ Good | ✅ Good |
| **Global Reach** | ✅ Extensive | ✅ Most regions | ✅ Extensive |
| **Maturity** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |

## Service Equivalents Across Providers

| Service Category | GCP | AWS | Azure |
|------------------|-----|-----|-------|
| **Compute (VMs)** | Compute Engine | EC2 | Virtual Machines |
| **Serverless Functions** | Cloud Functions | Lambda | Functions |
| **Serverless Containers** | Cloud Run | Fargate + ALB | Container Apps |
| **Container Orchestration** | GKE | EKS | AKS |
| **Object Storage** | Cloud Storage (GCS) | S3 | Blob Storage |
| **Block Storage** | Persistent Disk | EBS | Managed Disks |
| **Message Queue** | Pub/Sub | SQS | Queue Storage |
| **Event Streaming** | Pub/Sub | Kinesis | Event Hubs |
| **Relational DB** | Cloud SQL | RDS | SQL Database |
| **NoSQL DB** | Firestore, Bigtable | DynamoDB | Cosmos DB |
| **Data Warehouse** | BigQuery | Redshift | Synapse |
| **API Gateway** | API Gateway | API Gateway | API Management |
| **CDN** | Cloud CDN | CloudFront | Front Door |
| **Load Balancer** | Cloud Load Balancing | ELB/ALB | Load Balancer |
| **DNS** | Cloud DNS | Route 53 | DNS |
| **IAM** | Cloud IAM | IAM | Azure AD / Entra ID |
| **Secrets Management** | Secret Manager | Secrets Manager | Key Vault |
| **Monitoring** | Cloud Monitoring | CloudWatch | Monitor |
| **Logging** | Cloud Logging | CloudWatch Logs | Log Analytics |

## Decision Frameworks

### Choosing a Cloud Provider

| Scenario | Recommended Provider | Rationale |
|----------|---------------------|-----------|
| Startup building data-intensive app | **GCP** | BigQuery, affordable Cloud Run, ML tools |
| Enterprise with existing MS investment | **Azure** | Hybrid cloud, Active Directory integration |
| Need broadest service selection | **AWS** | Most mature ecosystem, most services |
| ML/AI workloads | **GCP** (Vertex AI) or **AWS** (SageMaker) | Both strong; GCP better for TensorFlow |
| Kubernetes-centric architecture | **GCP** (GKE) | Best Kubernetes management experience |
| Government/compliance workloads | **AWS GovCloud** | Most mature compliance certifications |
| Global edge computing | **AWS** (Lambda@Edge) | Most edge locations |

### Single-Cloud vs Multi-Cloud vs Hybrid

| Approach | Pros | Cons | When to Use |
|----------|------|------|-------------|
| **Single-Cloud** | Simplicity, deep integration, cost-effective | Vendor lock-in, single point of failure | Most startups and SMBs |
| **Multi-Cloud** | Avoid lock-in, leverage best-of-breed | Complexity, higher costs, skill requirements | Large enterprises with specific needs per provider |
| **Hybrid** | On-prem + cloud flexibility | Complex networking, latency, security challenges | Regulated industries, gradual migration |

**Recommendation:** Start with single-cloud (simpler, faster). Consider multi-cloud only when:
- Regulatory requirements mandate data sovereignty
- Specific services are needed from multiple providers
- Risk mitigation justifies the complexity cost

## Common Cloud Patterns

### Event-Driven Serverless

**GCP Example:**
```
GCS Upload → Pub/Sub → Cloud Run → BigQuery
```

**Why:** Decoupled, auto-scaling, pay-per-use

**AWS Equivalent:**
```
S3 Upload → SNS/SQS → Lambda → Redshift
```

### Microservices on Kubernetes

**Pattern:**
```
API Gateway → GKE/EKS/AKS (microservices) → Cloud SQL/RDS
                ↓
          Service Mesh (Istio)
```

**Why:** Portable, scalable, supports complex deployments

### Serverless Data Pipeline

**Pattern:**
```
API → Cloud Function/Lambda → Pub/Sub/SQS → Cloud Run/Fargate → Data Warehouse
```

**Why:** No infrastructure management, scales to zero

### Fan-Out Processing

**Pattern:**
```
Single Message → Pub/Sub/SNS → Multiple Subscribers (Cloud Run/Lambda)
                                      ↓
                            Parallel processing (image resize, analysis, etc.)
```

**Why:** Process single event in multiple ways concurrently

## Cost Optimization Strategies

### Compute
✅ Use serverless (Cloud Run, Lambda) for variable workloads
✅ Leverage spot/preemptible instances for batch processing (70% savings)
✅ Right-size VMs (start small, scale up as needed)
✅ Use sustained use discounts (GCP) or Reserved Instances (AWS)
✅ Scale to zero when possible (Cloud Run auto-scales down)

### Storage
✅ Use lifecycle policies (move old data to cold storage)
✅ Enable compression (GCS, S3)
✅ Delete unused snapshots and backups
✅ Use regional storage for non-HA workloads

### Networking
✅ Minimize cross-region traffic (expensive)
✅ Use Cloud CDN / CloudFront for static assets
✅ Optimize API payload sizes
✅ Batch requests when possible

### Monitoring
✅ Set budget alerts
✅ Review cost reports weekly
✅ Tag resources for cost attribution
✅ Use cost anomaly detection

## Best Practices

### Architecture
✅ Design for failure (redundancy, retries, circuit breakers)
✅ Use managed services over self-hosted (less ops burden)
✅ Implement health checks and readiness probes
✅ Separate dev/staging/prod environments

### Security
✅ Principle of least privilege (IAM)
✅ Enable encryption at rest and in transit
✅ Use secrets management (Secret Manager, Key Vault)
✅ Regularly rotate credentials
✅ Enable audit logging

### Observability
✅ Structured logging (JSON format)
✅ Centralized log aggregation
✅ Distributed tracing (Cloud Trace, X-Ray)
✅ Set up alerting for critical metrics

### Deployment
✅ Infrastructure as Code (Terraform, CloudFormation)
✅ Blue-green or canary deployments
✅ Automated rollback on failure
✅ Immutable infrastructure (no SSH, rebuild instead)

## Anti-Patterns

❌ **Always-on compute**: Running EC2/GCE 24/7 for sporadic workloads → Use serverless
❌ **Tight coupling**: Direct service-to-service calls → Use pub/sub or API gateway
❌ **Unencrypted data**: Storing sensitive data without encryption → Enable encryption at rest
❌ **Ignoring costs**: No budget monitoring → Set alerts and review regularly
❌ **Manual deployments**: Clicking through console → Use IaC and CI/CD
❌ **Single region**: Deploying only to one region → Multi-region for HA

## Migration Patterns

### Lift-and-Shift
- Move VMs to cloud with minimal changes
- **Pros:** Fast, low risk
- **Cons:** Doesn't leverage cloud benefits
- **When:** Quick migration, legacy apps

### Refactor
- Redesign for cloud-native (serverless, managed services)
- **Pros:** Cost-effective, scalable
- **Cons:** Time-consuming, requires rewrite
- **When:** Modernizing applications

### Replatform
- Minor optimizations (e.g., RDS instead of self-managed DB)
- **Pros:** Balance of speed and benefit
- **Cons:** Partial cloud optimization
- **When:** Pragmatic middle ground

## Related Knowledge

- **DevOps/SRE**: See [devops-sre/](../devops-sre/) for Terraform, CI/CD pipelines
- **Data Engineering**: See [data-engineering/](../data-engineering/) for data pipelines on cloud
- **AI/ML**: See [ai-ml/](../ai-ml/) for deploying LLM applications on Cloud Run/Lambda

## Agents

Specialized agents for cloud tasks:
- `/lambda-builder` - AWS Lambda Python handlers
- `/aws-deployer` - SAM CLI deployments
- `/ci-cd-specialist` - Azure DevOps, Terraform, cloud deployments

---

**Design for failure • Automate everything • Monitor relentlessly**
