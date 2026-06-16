-- 1. Create tables
CREATE TABLE "Transactions"
(
    id             BIGINT GENERATED ALWAYS AS IDENTITY,
    created_at     TIMESTAMPTZ    NOT NULL,
    amount         NUMERIC(15, 2) NOT NULL,
    state          SMALLINT       NOT NULL,
    operation_guid UUID           NOT NULL,
    payload        JSONB          NOT NULL,
    client_id      bigint GENERATED ALWAYS AS ((payload ->> 'client_id')::bigint) STORED,
    operation_type text GENERATED ALWAYS AS (payload ->> 'operation_type') STORED,

    CONSTRAINT pk_transactions PRIMARY KEY (created_at, id)
) PARTITION BY RANGE (created_at);

ALTER TABLE "Transactions"
    ADD CONSTRAINT chk_payload_structure CHECK (
        Payload ? 'account_number' AND
        payload ? 'client_id' AND
        payload ? 'operation_type' AND
        payload ->> 'operation_type' IN ('online', 'offline')
    );

CREATE TABLE transactions_y2026m01 PARTITION OF "Transactions" FOR VALUES FROM ('2026-01-01 00:00:00+00') TO ('2026-02-01 00:00:00+00');
CREATE TABLE transactions_y2026m02 PARTITION OF "Transactions" FOR VALUES FROM ('2026-02-01 00:00:00+00') TO ('2026-03-01 00:00:00+00');
CREATE TABLE transactions_y2026m03 PARTITION OF "Transactions" FOR VALUES FROM ('2026-03-01 00:00:00+00') TO ('2026-04-01 00:00:00+00');
CREATE TABLE transactions_y2026m04 PARTITION OF "Transactions" FOR VALUES FROM ('2026-04-01 00:00:00+00') TO ('2026-05-01 00:00:00+00');
CREATE TABLE transactions_y2026m05 PARTITION OF "Transactions" FOR VALUES FROM ('2026-05-01 00:00:00+00') TO ('2026-06-01 00:00:00+00');
CREATE TABLE transactions_y2026m06 PARTITION OF "Transactions" FOR VALUES FROM ('2026-06-01 00:00:00+00') TO ('2026-07-01 00:00:00+00');
CREATE TABLE transactions_y2026m07 PARTITION OF "Transactions" FOR VALUES FROM ('2026-07-01 00:00:00+00') TO ('2026-08-01 00:00:00+00');
CREATE TABLE transactions_default PARTITION OF "Transactions" DEFAULT;
CREATE OR REPLACE PROCEDURE create_next_month_partition() AS $$
DECLARE
    v_start DATE := DATE_TRUNC('month', NOW() + INTERVAL '1 month');
    v_end   DATE := v_start + INTERVAL '1 month';
    v_name TEXT := 'transactions_y' || TO_CHAR(v_start, 'YYYY"m"MM');
BEGIN
    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS %I PARTITION OF "Transactions" FOR VALUES FROM (%L) TO (%L)',
        v_name, v_start, v_end
    );
END;
$$ LANGUAGE plpgsql;

CREATE INDEX idx_transactions_guid ON "Transactions" (operation_guid);
CREATE INDEX idx_transaction_state0 ON "Transactions" (id) WHERE state = 0;
CREATE INDEX idx_transactions_client_type ON "Transactions" (client_id, operation_type) WHERE state = 1;

-- 3. Create for tracking unique operation_guid
CREATE TABLE "TransactionGuids"
(
    operation_guid UUID PRIMARY KEY,
    created_at     TIMESTAMPTZ NOT NULL
);

-- 6. Create for mv_client_totals
CREATE TABLE "ClientsTotal"
(
    client_id bigint,
    operation_type text,
    total_amount numeric(18,2) NOT NULL DEFAULT 0,
    PRIMARY KEY (client_id, operation_type)
);

-- 7. Add replication
CREATE PUBLICATION pub_transactions FOR TABLE "Transactions";