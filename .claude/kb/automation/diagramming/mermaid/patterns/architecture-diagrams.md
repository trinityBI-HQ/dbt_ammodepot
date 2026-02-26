# Architecture Diagrams

> **Purpose**: Reusable patterns for visualizing software architecture with Mermaid
> **MCP Validated**: 2026-02-17

## When to Use

- Documenting system context and boundaries
- Visualizing microservice interactions
- Communicating infrastructure to stakeholders
- Architecture Decision Records (ADRs)

## C4 Context Diagram

```mermaid
C4Context
    title System Context - Data Platform
    Person(analyst, "Data Analyst", "Queries data")
    Person(engineer, "Data Engineer", "Builds pipelines")
    System(platform, "Data Platform", "Processes data")
    System_Ext(crm, "CRM", "Customer data")
    System_Ext(bi, "BI Tool", "Dashboards")
    Rel(analyst, bi, "Views reports")
    Rel(engineer, platform, "Manages pipelines")
    Rel(crm, platform, "Sends events")
    Rel(platform, bi, "Serves curated data")
```

## Microservice Architecture

```mermaid
flowchart TB
    subgraph Client["Client Layer"]
        Web[Web App]
        Mobile[Mobile App]
    end
    subgraph Gateway["API Gateway"]
        GW[Load Balancer]
    end
    subgraph Services["Backend Services"]
        direction LR
        Auth[Auth]
        Users[Users]
        Orders[Orders]
    end
    subgraph Data["Data Layer"]
        direction LR
        PG[(PostgreSQL)]
        Redis[(Redis)]
        MQ[Message Queue]
    end
    Client --> Gateway
    GW --> Auth & Users & Orders
    Auth & Users --> PG
    Users --> Redis
    Orders --> MQ
    classDef service fill:#4CAF50,stroke:#2E7D32,color:#fff
    classDef data fill:#2196F3,stroke:#1565C0,color:#fff
    class Auth,Users,Orders service
    class PG,Redis,MQ data
```

## Event-Driven Architecture

```mermaid
flowchart LR
    subgraph Producers
        P1[Order Service]
        P2[User Service]
    end
    subgraph Broker
        K{{Kafka / Pub/Sub}}
    end
    subgraph Consumers
        C1[Analytics]
        C2[Search Index]
        C3[Notifications]
    end
    P1 -->|order.created| K
    P2 -->|user.updated| K
    K --> C1 & C2 & C3
```

## Infrastructure Diagram

```mermaid
flowchart TB
    subgraph VPC["AWS VPC"]
        subgraph Public["Public Subnet"]
            ALB[ALB]
        end
        subgraph Private["Private Subnet"]
            ECS[ECS Fargate]
            RDS[(RDS PostgreSQL)]
        end
    end
    Internet((Internet)) --> ALB --> ECS --> RDS
    S3[(S3)] --- ECS
    classDef aws fill:#FF9900,stroke:#232F3E,color:#232F3E
    class ALB,ECS,RDS,S3 aws
```

## Service Interaction Sequence

```mermaid
sequenceDiagram
    participant UI as Frontend
    participant GW as API Gateway
    participant API as Order Service
    participant DB as Database
    participant Q as Queue
    UI->>GW: POST /orders
    GW->>API: Create order
    API->>DB: INSERT
    DB-->>API: Order ID
    API->>Q: Publish order.created
    API-->>UI: 201 Created
    Note over Q: Async processing
```

## State Machine: Order Lifecycle

```mermaid
stateDiagram-v2
    [*] --> Pending
    Pending --> Processing : payment confirmed
    Pending --> Cancelled : timeout
    Processing --> Shipped : dispatched
    Shipped --> Delivered : confirmed
    Delivered --> [*]
    Cancelled --> [*]
```

## Tips

| Tip | Rationale |
|-----|-----------|
| Use subgraphs for boundaries | Shows system/network boundaries |
| Apply `classDef` for color coding | Distinguish layers visually |
| Use LR for pipelines, TB for hierarchies | Matches reading patterns |
| Keep diagrams focused | One concern per diagram |

## See Also

- [Data Flow Diagrams](data-flow-diagrams.md) - ETL and pipeline patterns
- [CI/CD Diagrams](ci-cd-diagrams.md) - Deployment pipeline patterns
- [Diagram Types](../concepts/diagram-types.md) - All diagram type references
