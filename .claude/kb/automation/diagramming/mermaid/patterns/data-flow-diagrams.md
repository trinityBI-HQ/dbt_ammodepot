# Data Flow Diagrams

> **Purpose**: Patterns for visualizing ETL pipelines, data flows, and data platform architectures
> **MCP Validated**: 2026-02-17

## When to Use

- Documenting ETL/ELT pipeline architecture
- Visualizing medallion architecture layers
- Mapping data lineage across systems
- Communicating data platform design

## Medallion Architecture

```mermaid
flowchart LR
    subgraph Sources
        API[APIs]
        DB[(OLTP)]
        Files[Files]
    end
    subgraph Bronze["Bronze Layer"]
        B1[(Raw API)]
        B2[(Raw DB)]
        B3[(Raw Files)]
    end
    subgraph Silver["Silver Layer"]
        S1[(Cleaned Customers)]
        S2[(Cleaned Orders)]
    end
    subgraph Gold["Gold Layer"]
        G1[(Revenue Metrics)]
        G2[(Customer 360)]
    end
    API --> B1
    DB --> B2
    Files --> B3
    B1 & B2 --> S1 & S2
    S1 & S2 --> G1
    S1 --> G2
    classDef bronze fill:#CD7F32,stroke:#8B4513,color:#fff
    classDef silver fill:#C0C0C0,stroke:#808080,color:#000
    classDef gold fill:#FFD700,stroke:#DAA520,color:#000
    class B1,B2,B3 bronze
    class S1,S2 silver
    class G1,G2 gold
```

## ELT Pipeline with dbt

```mermaid
flowchart LR
    Airbyte[Airbyte Sync] -->|incremental| Raw[(Raw Schema)]
    Raw --> Staging[Staging]
    Staging --> Intermediate[Intermediate]
    Intermediate --> Marts[Mart Models]
    Marts --> BI[BI Dashboard]
    classDef dbt fill:#FF694B,stroke:#C44127,color:#fff
    class Staging,Intermediate,Marts dbt
```

## Dagster Asset Graph

```mermaid
flowchart TD
    subgraph Ingestion
        raw_customers[raw_customers]
        raw_orders[raw_orders]
    end
    subgraph Transform
        stg_customers[stg_customers]
        stg_orders[stg_orders]
        fct_orders[fct_orders]
    end
    subgraph Output
        metrics[customer_metrics]
        revenue[daily_revenue]
    end
    raw_customers --> stg_customers
    raw_orders --> stg_orders
    stg_customers & stg_orders --> fct_orders
    fct_orders --> metrics & revenue
    classDef ingestion fill:#4CAF50,stroke:#2E7D32,color:#fff
    classDef transform fill:#2196F3,stroke:#1565C0,color:#fff
    classDef output fill:#9C27B0,stroke:#6A1B9A,color:#fff
    class raw_customers,raw_orders ingestion
    class stg_customers,stg_orders,fct_orders transform
    class metrics,revenue output
```

## Streaming Pipeline

```mermaid
flowchart LR
    subgraph Producers
        App[Application]
        IoT[IoT Devices]
        CDC[CDC Connector]
    end
    subgraph Processing
        Kafka{{Kafka}}
        Flink[Flink Jobs]
    end
    subgraph Storage
        Lake[(Data Lake)]
        OLAP[(OLAP Store)]
    end
    App & IoT & CDC --> Kafka --> Flink
    Flink -->|batch| Lake
    Flink -->|aggregated| OLAP
```

## Data Quality Pipeline

```mermaid
flowchart TB
    Source[(Source)] --> Ingest[Ingest]
    Ingest --> Validate{Great Expectations}
    Validate -->|Pass| Transform[Transform]
    Validate -->|Fail| Quarantine[(Quarantine)]
    Transform --> Test{dbt Tests}
    Test -->|Pass| Gold[(Gold Layer)]
    Test -->|Fail| Fix[Fix]
    Fix --> Transform
    Gold --> Monitor[Elementary]
    classDef check fill:#FF9800,stroke:#E65100,color:#000
    classDef fail fill:#f44336,stroke:#c62828,color:#fff
    classDef pass fill:#4CAF50,stroke:#2E7D32,color:#fff
    class Validate,Test check
    class Quarantine,Fix fail
    class Gold pass
```

## Data Lineage (ER Diagram)

```mermaid
erDiagram
    RAW_CUSTOMERS ||--|| STG_CUSTOMERS : transforms
    RAW_ORDERS ||--|| STG_ORDERS : transforms
    STG_CUSTOMERS ||--o{ FCT_ORDERS : joins
    STG_ORDERS ||--|| FCT_ORDERS : enriches
    FCT_ORDERS ||--o{ RPT_REVENUE : aggregates
```

## Tips

| Tip | Rationale |
|-----|-----------|
| Use LR for pipelines | Data flows naturally left-to-right |
| Color-code by layer | Instant visual identification |
| Use cylinders for storage | Universal database symbol |
| Show quality checkpoints | Makes validation explicit |

## See Also

- [Architecture Diagrams](architecture-diagrams.md) - System-level patterns
- [Dagster KB](../../../data-engineering/orchestration/dagster/) - Orchestration
- [Great Expectations KB](../../../data-engineering/data-quality/) - Data quality
