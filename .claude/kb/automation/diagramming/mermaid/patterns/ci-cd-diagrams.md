# CI/CD Diagrams

> **Purpose**: Patterns for visualizing CI/CD pipelines, deployment flows, and release processes
> **MCP Validated**: 2026-02-17

## When to Use

- Documenting CI/CD pipeline stages
- Visualizing deployment strategies (blue-green, canary)
- Communicating release processes to the team
- Mapping environment promotion flows

## GitHub Actions Pipeline

```mermaid
flowchart LR
    subgraph CI["CI Pipeline"]
        Checkout[Checkout] --> Install[Install]
        Install --> Lint[Lint] --> Test[Test] --> Build[Build]
    end
    subgraph CD["CD Pipeline"]
        Staging[Staging] --> Smoke[Smoke Tests]
        Smoke --> Approve{Approval}
        Approve -->|Yes| Prod[Production]
        Approve -->|No| Stop[Stop]
    end
    Build --> Staging
    classDef ci fill:#2196F3,stroke:#1565C0,color:#fff
    classDef cd fill:#4CAF50,stroke:#2E7D32,color:#fff
    classDef gate fill:#9C27B0,stroke:#6A1B9A,color:#fff
    class Checkout,Install,Lint,Test,Build ci
    class Staging,Smoke,Prod cd
    class Approve gate
```

## Multi-Environment Promotion

```mermaid
flowchart LR
    Dev[Development] -->|merge| CI{CI Pass?}
    CI -->|Yes| Staging[Staging]
    CI -->|No| Fix[Fix]
    Staging -->|QA| UAT[UAT]
    UAT -->|Approved| Prod[Production]
    style Dev fill:#90CAF9,stroke:#1565C0
    style Staging fill:#FFE082,stroke:#F9A825
    style UAT fill:#CE93D8,stroke:#7B1FA2
    style Prod fill:#A5D6A7,stroke:#2E7D32
```

## Docker Build and Push

```mermaid
flowchart TB
    subgraph Build
        Code[Source] --> Docker[docker build] --> Image[Image]
    end
    subgraph Test
        Image --> Unit[Unit Tests]
        Image --> Sec[Security Scan]
    end
    subgraph Deploy
        Unit & Sec --> Registry[(Registry)]
        Registry --> K8s[Kubernetes]
    end
    classDef build fill:#42A5F5,stroke:#1565C0,color:#fff
    classDef test fill:#FF7043,stroke:#D84315,color:#fff
    classDef deploy fill:#66BB6A,stroke:#2E7D32,color:#fff
    class Code,Docker,Image build
    class Unit,Sec test
    class K8s deploy
```

## Terraform Deployment

```mermaid
flowchart LR
    Code[IaC Changes] --> Init[init]
    Init --> Validate[validate]
    Validate --> Plan[plan]
    Plan --> Review{PR Review}
    Review -->|Approved| Apply[apply]
    Review -->|Changes| Code
    Apply --> Verify[Verify]
    classDef plan fill:#FFF9C4,stroke:#F9A825,color:#000
    classDef apply fill:#C8E6C9,stroke:#2E7D32,color:#000
    class Code,Init,Validate,Plan plan
    class Apply,Verify apply
```

## Blue-Green Deployment

```mermaid
flowchart TB
    LB[Load Balancer]
    subgraph Blue["Blue (Current)"]
        B1[Instance 1]
        B2[Instance 2]
    end
    subgraph Green["Green (New)"]
        G1[Instance 1]
        G2[Instance 2]
    end
    LB -->|100%| Blue
    LB -.->|0%| Green
    Green --> Health{Healthy?}
    Health -->|Yes| Switch[Switch Traffic]
    Health -->|No| Rollback[Rollback]
    style Blue fill:#2196F3,stroke:#1565C0,color:#fff
    style Green fill:#4CAF50,stroke:#2E7D32,color:#fff
```

## Canary Deployment

```mermaid
flowchart LR
    LB[Load Balancer]
    subgraph Stable["Stable (v1)"]
        S1[Pod 1]
        S2[Pod 2]
    end
    subgraph Canary["Canary (v2)"]
        C1[Pod 1]
    end
    LB -->|90%| Stable
    LB -->|10%| Canary
    Canary --> Monitor{Metrics OK?}
    Monitor -->|Yes| Promote[100%]
    Monitor -->|No| Rollback[Rollback]
    style Stable fill:#2196F3,stroke:#1565C0,color:#fff
    style Canary fill:#FF9800,stroke:#E65100,color:#000
```

## Release Sequence

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant GH as GitHub
    participant CI as CI Pipeline
    participant Prod as Production
    Dev->>GH: Create PR
    GH->>CI: Trigger checks
    CI-->>GH: Checks passed
    Dev->>GH: Merge to main
    GH->>CI: Build & deploy
    CI->>Prod: Deploy
    Prod-->>Dev: Health check OK
```

## Rollback Decision

```mermaid
flowchart TD
    Alert[Alert] --> Rate{Error > 5%?}
    Rate -->|Yes| Sev{P1?}
    Rate -->|No| Monitor[Monitor]
    Sev -->|Yes| Auto[Auto Rollback]
    Sev -->|No| Manual{Decision}
    Manual -->|Rollback| Roll[Rollback]
    Manual -->|Hotfix| Fix[Hotfix]
    Auto & Roll & Fix --> Verify[Post-Mortem]
    classDef alert fill:#f44336,stroke:#c62828,color:#fff
    classDef safe fill:#4CAF50,stroke:#2E7D32,color:#fff
    class Alert alert
    class Verify safe
```

## Tips

| Tip | Rationale |
|-----|-----------|
| Use LR for pipeline stages | Linear flow reads naturally |
| Color-code CI vs CD vs gates | Instant visual distinction |
| Include failure paths | Documents rollback procedures |
| Show approval gates | Clarifies human checkpoints |

## See Also

- [Architecture Diagrams](architecture-diagrams.md) - Infrastructure patterns
- [GitHub KB](../../../devops-sre/version-control/github/) - GitHub Actions
- [Kubernetes KB](../../../devops-sre/containerization/kubernetes/) - K8s deployments
