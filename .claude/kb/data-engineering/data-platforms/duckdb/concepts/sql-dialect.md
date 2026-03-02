# DuckDB SQL Dialect

> **Purpose**: PostgreSQL-compatible SQL with DuckDB-specific extensions for friendlier, more expressive queries
> **Confidence**: 0.95
> **MCP Validated**: 2026-03-01

## Overview

DuckDB's SQL dialect is PostgreSQL-compatible at its core, with significant extensions that reduce boilerplate and improve readability. Key additions include QUALIFY for filtering window functions, PIVOT/UNPIVOT for reshaping data, EXCLUDE/REPLACE for column manipulation, COLUMNS() for regex-based column selection, nested types (LIST, STRUCT, MAP), lambda functions, and "Friendly SQL" shortcuts like GROUP BY ALL and FROM-first syntax.

## The Pattern

```sql
-- Friendly SQL: GROUP BY ALL infers grouping columns
select department, region, sum(revenue) as total_revenue
from sales
group by all;

-- FROM-first syntax (SELECT is optional for exploration)
from sales select department, sum(revenue) where year = 2025 group by all;

-- QUALIFY: filter window function results directly
select customer_id, order_date, amount,
    row_number() over (partition by customer_id order by order_date desc) as rn
from orders
qualify rn = 1;

-- EXCLUDE: all columns except specified ones
select * exclude (internal_id, _ab_cdc_deleted_at) from customers;

-- REPLACE: override a column expression in SELECT *
select * replace (amount * 1.1 as amount) from orders;

-- COLUMNS(): regex-based column selection with transformations
select min(columns('.*_amount')), max(columns('.*_amount')) from invoices;
```

## Nested Types

```sql
-- LIST: ordered array
select [1, 2, 3] as nums;
select list_aggregate([10, 20, 30], 'sum') as total;  -- 60

-- STRUCT: named fields
select {'name': 'Alice', 'age': 30} as person;
select person.name from (select {'name': 'Alice'} as person);

-- MAP: key-value pairs
select map {'key1': 'value1', 'key2': 'value2'} as m;
select element_at(m, 'key1') from (select map {'key1': 'val'} as m);

-- Lambda functions on lists
select list_transform([1, 2, 3], x -> x * 2) as doubled;  -- [2, 4, 6]
select list_filter([1, 2, 3, 4], x -> x > 2) as filtered;  -- [3, 4]
```

## PIVOT / UNPIVOT

```sql
-- PIVOT: long to wide
pivot sales on product_name using sum(revenue);

-- UNPIVOT: wide to long
unpivot monthly_sales on jan, feb, mar into name month value revenue;

-- UNPIVOT with COLUMNS expression (dynamic)
unpivot monthly_sales on columns(* exclude (id, name))
    into name month value revenue;
```

## Quick Reference

| Feature | Syntax | Notes |
|---------|--------|-------|
| GROUP BY ALL | `GROUP BY ALL` | Infers columns from SELECT |
| ORDER BY ALL | `ORDER BY ALL` | Orders by all SELECT columns left-to-right |
| QUALIFY | `QUALIFY expr` | Filters window function results |
| EXCLUDE | `* EXCLUDE (col)` | Remove columns from SELECT * |
| REPLACE | `* REPLACE (expr AS col)` | Override column in SELECT * |
| COLUMNS | `COLUMNS('regex')` | Select columns matching regex |
| FROM-first | `FROM t SELECT ...` | Put FROM before SELECT |
| SAMPLE | `FROM t USING SAMPLE 10%` | Random sampling |
| ASOF JOIN | `ASOF JOIN t2 ON ...` | Join on nearest key match |
| LATERAL JOIN | `t1, LATERAL (subquery)` | Correlated subquery as join |
| CREATE OR REPLACE | `CREATE OR REPLACE TABLE` | Idempotent DDL |

## Common Mistakes

### Wrong

```sql
-- Redundant GROUP BY (PostgreSQL style)
select department, region, count(*) as cnt
from employees
group by department, region;
```

### Correct

```sql
-- DuckDB Friendly SQL
select department, region, count(*) as cnt
from employees
group by all;
```

## Related

- [architecture](../concepts/architecture.md)
- [data-import-export](../concepts/data-import-export.md)
- [local-analytics](../patterns/local-analytics.md)
