# OperationFlow — PostgreSQL Test Assignment

A financial transaction processing system built on PostgreSQL 16, featuring range partitioning, scheduled jobs, a materialized view with incremental updates, and logical replication.

## Architecture

```
┌─────────────────────────┐     logical replication     ┌──────────────────────────┐
│   postgres_master:5432  │ ─────────────────────────── │  postgres_replica:5433   │
│                         │                             │                          │
│  "Transactions"         │                             │  "Transactions" (copy)   │
│   ├── y2026m01..m07     │                             │   ├── y2026m01..m07      │
│   └── default           │                             │   └── default            │
│                         │                             │                          │
│  "ClientsTotal"         │                             └──────────────────────────┘
│  mv_client_totals       │
└─────────────────────────┘
          ▲
          │ CALL every 3s / 5s
┌─────────────────────────┐
│   pg_timetable worker   │
└─────────────────────────┘
```

## Requirements vs Implementation

| # | Requirement | Implementation |
|---|-------------|---------------|
| 1 | Partitioned table T1 | `"Transactions"` PARTITION BY RANGE (created_at), monthly partitions + default |
| 2 | Generate ≥ 100 000 rows over 3–5 months | `generate_test_transactions(100000, '2026-01-01', '5 months')` |
| 3 | Uniqueness on operation_guid | `"TransactionGuids"` table (PRIMARY KEY) used as an insert guard |
| 4 | Insert a row every 5 s with state=0 | pg_timetable → `insert_pending_transaction()` |
| 5 | Flip state 0→1 every 3 s based on second parity | pg_timetable → `update_transaction_states()` |
| 6 | Running totals by client_id + operation_type in a MV | `"ClientsTotal"` + `mv_client_totals`, updated via `UPDATE … RETURNING` CTE |
| 7 | Replicate to a second instance | Logical replication: PUBLICATION + SUBSCRIPTION |

## Project Structure

```
.
├── compose.yaml
├── db/
│   ├── init-scripts/
│   │   ├── 01-init-schema.sql   # tables, partitions, indexes, publication
│   │   ├── 02-init-schema.sql   # row generator function + 100k seed
│   │   ├── 04-init-schema.sql   # insert procedure (every 5 s)
│   │   ├── 05-init-schema.sql   # state-flip procedure (every 3 s)
│   │   └── 06-init-schema.sql   # materialized view
│   ├── init-replica/
│   │   └── init-replica.sh      # replica schema copy + subscription setup
│   └── timetable-jobs.sql       # pg_timetable job registration
└── .env
```

## Getting Started

### Prerequisites

- Docker + Docker Compose
- `.env` file in the project root:

```env
DB_USER=postgres
DB_PASSWORD=your_password
DB_NAME=OperationFlow
DB_PORT=5048
```

### Start

```bash
chmod +x db/init-replica/init-replica.sh
docker compose up -d
```

The first start takes ~1–2 minutes (seeding 100 000 rows).

### Stop and Clean Up

```bash
# stop containers only
docker compose down

# full reset including data volumes
docker compose down
docker volume rm test-task-with-postgre_operation_flow_db_data
docker volume rm test-task-with-postgre_operation_flow_replica_data
```

## Connections

| Service | Host | Port | Database |
|---------|------|------|----------|
| Master  | localhost | 5048 (or DB_PORT from .env) | OperationFlow |
| Replica | localhost | 5433 | OperationFlow |

