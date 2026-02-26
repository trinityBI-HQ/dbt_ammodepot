# Kubernetes Deployment Pattern

> **Purpose**: Production deployment of Dagster on Kubernetes with Helm
> **MCP Validated**: 2026-02-19

## When to Use

- Production self-hosted deployment
- Need horizontal scaling for runs
- Container isolation for jobs
- Data residency requirements (vs Dagster Cloud)

## Implementation

```yaml
# values.yaml - Helm chart configuration
dagsterWebserver:
  replicaCount: 2
  resources:
    requests: { cpu: 250m, memory: 512Mi }
    limits: { cpu: 1000m, memory: 2Gi }

dagsterDaemon:
  enabled: true
  resources:
    requests: { cpu: 250m, memory: 512Mi }

postgresql:
  enabled: true
  postgresqlDatabase: dagster
  persistence: { enabled: true, size: 10Gi }

runLauncher:
  type: K8sRunLauncher
  config:
    k8sRunLauncher:
      envSecrets: [{ name: dagster-secrets }]
      runK8sConfig:
        containerConfig:
          resources:
            requests: { cpu: 500m, memory: 1Gi }
            limits: { cpu: 2000m, memory: 4Gi }

dagster-user-deployments:
  enabled: true
  deployments:
    - name: my-project
      image: { repository: my-registry/dagster-project, tag: v1.0.0 }
      dagsterApiGrpcArgs: ["-m", "my_project.definitions"]
      port: 3030
      envSecrets: [{ name: dagster-secrets }]
```

## Configuration

| Component | Purpose | Scaling |
|-----------|---------|---------|
| Webserver | UI and GraphQL API | Horizontal (replicas) |
| Daemon | Schedules, sensors | Single instance only |
| User deployments | Code locations (gRPC) | Per deployment |
| Run launcher | Spawns K8s Jobs | Per run |

## Dockerfile for User Code

```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY pyproject.toml .
RUN pip install --no-cache-dir .
COPY src/ src/
COPY dbt_project/ dbt_project/
RUN cd dbt_project && dbt parse --profiles-dir .
CMD ["dagster", "api", "grpc", "-h", "0.0.0.0", "-p", "3030", "-m", "my_project.definitions"]
```

## Helm Commands

```bash
helm repo add dagster https://dagster-io.github.io/helm
helm install dagster dagster/dagster --namespace dagster --create-namespace -f values.yaml
helm upgrade dagster dagster/dagster --namespace dagster -f values.yaml
```

## Secrets Management

```yaml
apiVersion: v1
kind: Secret
metadata: { name: dagster-secrets, namespace: dagster }
type: Opaque
stringData:
  SNOWFLAKE_ACCOUNT: "xxx"
  SNOWFLAKE_PASSWORD: "xxx"
```

## Resource Isolation per Run

```python
@dg.asset(
    op_tags={
        "dagster-k8s/config": {
            "container_config": {
                "resources": {
                    "requests": {"cpu": "2", "memory": "4Gi"},
                    "limits": {"cpu": "4", "memory": "8Gi"},
                }
            }
        }
    }
)
def heavy_computation():
    pass
```

## Example Usage

```bash
kubectl port-forward svc/dagster-webserver 3000:80 -n dagster
kubectl logs -f deployment/dagster-daemon -n dagster
```

## Anti-Patterns

| Don't | Do |
|-------|-----|
| Run daemon with multiple replicas | Single daemon instance only |
| Store secrets in values.yaml | Use K8s Secrets |
| Skip resource limits | Always set requests and limits |
| Use latest tag in production | Pin specific image tags |

## See Also

- [dagster-cloud](../concepts/dagster-cloud.md)
- [definitions](../concepts/definitions.md)
- [project-structure](../patterns/project-structure.md)
