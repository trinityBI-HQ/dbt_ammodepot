# Helm & Kustomize

> **Purpose**: Package management and configuration customization for Kubernetes manifests
> **MCP Validated**: 2026-02-19

## When to Use

- Distributing reusable application packages (Helm)
- Managing environment-specific overlays without templating (Kustomize)
- Deploying third-party applications (Helm charts)
- GitOps workflows with declarative configuration

## Helm Chart Structure

```
my-chart/
├── Chart.yaml              # Chart metadata (name, version, dependencies)
├── values.yaml             # Default configuration values
├── charts/                 # Chart dependencies
├── templates/
│   ├── _helpers.tpl        # Template helper functions
│   ├── deployment.yaml     # Deployment template
│   ├── service.yaml        # Service template
│   ├── ingress.yaml        # Ingress template
│   ├── configmap.yaml      # ConfigMap template
│   ├── hpa.yaml            # HPA template
│   └── NOTES.txt           # Post-install instructions
└── .helmignore             # Files to ignore
```

**Chart.yaml:**

```yaml
apiVersion: v2
name: my-app
version: 1.2.0            # Chart version
appVersion: "2.0.0"        # Application version
description: My application chart
dependencies:
- name: postgresql
  version: "12.x.x"
  repository: https://charts.bitnami.com/bitnami
  condition: postgresql.enabled
```

**Template example (templates/deployment.yaml):**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "my-app.fullname" . }}
  labels:
    {{- include "my-app.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "my-app.selectorLabels" . | nindent 6 }}
  template:
    spec:
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        resources:
          {{- toYaml .Values.resources | nindent 12 }}
```

**Helm commands:**

```bash
helm install my-release ./my-chart -f values-prod.yaml
helm upgrade my-release ./my-chart -f values-prod.yaml
helm rollback my-release 1          # Rollback to revision 1
helm template my-release ./my-chart # Render locally (dry run)
helm lint ./my-chart                # Validate chart
helm diff upgrade my-release ./my-chart  # Preview changes (plugin)
```

## Kustomize Structure

```
k8s/
├── base/
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── configmap.yaml
└── overlays/
    ├── dev/
    │   ├── kustomization.yaml
    │   └── patch-replicas.yaml
    ├── staging/
    │   ├── kustomization.yaml
    │   └── patch-resources.yaml
    └── prod/
        ├── kustomization.yaml
        ├── patch-replicas.yaml
        └── patch-resources.yaml
```

**Base kustomization.yaml:**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- service.yaml
- configmap.yaml
commonLabels:
  app: my-app
```

**Production overlay kustomization.yaml:**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../../base
namespace: production
namePrefix: prod-
patches:
- path: patch-replicas.yaml
- target:
    kind: Deployment
    name: my-app
  patch: |
    - op: replace
      path: /spec/template/spec/containers/0/resources/limits/memory
      value: 1Gi
```

**Apply:** `kubectl apply -k overlays/prod/`

## Configuration

| Feature | Helm | Kustomize |
|---------|------|-----------|
| Templating | Go templates | Patches/overlays |
| Package distribution | Chart repos, OCI | Git repos |
| Dependencies | Chart dependencies | Bases/components |
| Rollback | Built-in (`helm rollback`) | Git revert |
| Learning curve | Higher (Go templates) | Lower (plain YAML) |
| Best for | Third-party apps, reusable packages | In-house apps, GitOps |

## Example Usage

```bash
# Helm: Install NGINX Ingress Controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress ingress-nginx/ingress-nginx \
  --namespace ingress --create-namespace \
  --set controller.replicaCount=2

# Kustomize: Deploy to production
kubectl apply -k overlays/prod/
kubectl diff -k overlays/prod/    # Preview changes
```

## See Also

- [Deployment Strategies](deployment-strategies.md) — Release patterns
- [Production Best Practices](production-best-practices.md) — Manifest standards
- [Workloads](../concepts/workloads.md) — Underlying resource types
