# Deployment Patterns

> **Purpose**: Docker Compose, Kubernetes/Helm, bare metal, and production deployment of OpenMetadata
> **MCP Validated**: 2026-02-19

## When to Use

- Setting up OpenMetadata for development, staging, or production
- Choosing between Docker Compose (quick start) and Kubernetes (production)
- Deploying with managed cloud services (AWS RDS, Cloud SQL, managed ES)

## Docker Compose (Development / POC)

```yaml
# docker-compose.yml (simplified)
version: "3.9"
services:
  mysql:
    image: mysql:8
    environment:
      MYSQL_ROOT_PASSWORD: password
      MYSQL_DATABASE: openmetadata_db
    volumes:
      - mysql_data:/var/lib/mysql
    ports:
      - "3306:3306"

  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.10.2
    environment:
      discovery.type: single-node
      ES_JAVA_OPTS: "-Xms512m -Xmx512m"
      xpack.security.enabled: "false"
    volumes:
      - es_data:/usr/share/elasticsearch/data
    ports:
      - "9200:9200"

  openmetadata-server:
    image: docker.io/openmetadata/server:1.6.1
    environment:
      OPENMETADATA_CLUSTER_NAME: openmetadata
      DB_HOST: mysql
      DB_PORT: 3306
      OM_DATABASE: openmetadata_db
      DB_USER: openmetadata_user
      DB_USER_PASSWORD: openmetadata_password
      ELASTICSEARCH_HOST: elasticsearch
      ELASTICSEARCH_PORT: 9200
    ports:
      - "8585:8585"
      - "8586:8586"
    depends_on:
      - mysql
      - elasticsearch

  openmetadata-ingestion:
    image: docker.io/openmetadata/ingestion:1.6.1
    environment:
      AIRFLOW__API__AUTH_BACKENDS: "airflow.api.auth.backend.basic_auth"
    ports:
      - "8080:8080"
    depends_on:
      - openmetadata-server

volumes:
  mysql_data:
  es_data:
```

```bash
# Quick start with official CLI
pip install openmetadata-ingestion
metadata docker --start
# Access UI at http://localhost:8585
# Default credentials: admin@open-metadata.org / admin
```

## Kubernetes / Helm (Production)

```bash
# Add Helm repository
helm repo add open-metadata https://helm.open-metadata.org/
helm repo update

# Create namespace
kubectl create namespace openmetadata

# Create secrets
kubectl create secret generic mysql-secrets \
  --from-literal=openmetadata-mysql-password=<password> \
  --namespace openmetadata

kubectl create secret generic airflow-secrets \
  --from-literal=openmetadata-airflow-password=<password> \
  --namespace openmetadata

# Install dependencies (MySQL, Elasticsearch, Airflow)
helm install openmetadata-dependencies open-metadata/openmetadata-dependencies \
  --namespace openmetadata

# Install OpenMetadata server
helm install openmetadata open-metadata/openmetadata \
  --namespace openmetadata \
  --set openmetadata.config.elasticsearch.host=elasticsearch \
  --set openmetadata.config.database.host=mysql
```

## Production Configuration

| Setting | Development | Production |
|---------|------------|------------|
| MySQL | Docker container | AWS RDS / Cloud SQL |
| Elasticsearch | Single node | 3+ node cluster / OpenSearch |
| Ingestion | Embedded Airflow | External Airflow / Dagster |
| Auth | Default JWT | SSO (Okta, Azure AD, Google) |
| SSL | Disabled | Enabled (TLS termination) |
| Resources | 4 GB RAM minimum | 8+ GB RAM, 4+ CPUs |
| Backup | None | Automated MySQL + ES snapshots |

## SSO Authentication Setup

```yaml
# values.yaml for Helm (Okta example)
openmetadata:
  config:
    authentication:
      provider: "okta"
      publicKeyUrls:
        - "https://<your-org>.okta.com/oauth2/default/v1/keys"
      authority: "https://<your-org>.okta.com/oauth2/default"
      clientId: "<okta-client-id>"
      callbackUrl: "http://localhost:8585/callback"
```

## Health Check

```bash
# Verify server is running
curl http://localhost:8585/api/v1/system/version

# Check Elasticsearch connectivity
curl http://localhost:9200/_cluster/health

# Verify Airflow (ingestion)
curl http://localhost:8080/api/v1/health
```

## Resource Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| OpenMetadata Server | 2 CPU, 2 GB | 4 CPU, 4 GB |
| MySQL | 1 CPU, 1 GB | 2 CPU, 4 GB |
| Elasticsearch | 1 CPU, 2 GB | 2 CPU, 4 GB |
| Airflow (ingestion) | 1 CPU, 2 GB | 2 CPU, 4 GB |

## See Also

- [Architecture](../concepts/architecture.md)
- [Ingestion Patterns](../patterns/ingestion-patterns.md)
- [Kubernetes KB](../../../devops-sre/containerization/kubernetes/)
- [Docker Compose KB](../../../devops-sre/containerization/docker-compose/)
