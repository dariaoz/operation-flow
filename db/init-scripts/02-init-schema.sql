-- 2. Create generate random transactions
CREATE OR REPLACE FUNCTION generate_random_transaction_rows(
    rows_count INT, 
    p_state SMALLINT,
    p_start_date TIMESTAMPTZ, 
    p_range INTERVAL
)
RETURNS TABLE (
    r_created_at TIMESTAMPTZ,
    r_amount NUMERIC(15, 2),
    r_state SMALLINT,
    r_operation_guid UUID,
    r_payload JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT p_start_date + (random() * p_range)          AS r_created_at,
           ROUND((10 + random() * 4990):: numeric, 2)   AS r_amount,
           p_state                                      AS r_state,
           gen_random_uuid() AS r_operation_guid,
           jsonb_build_object(
                   'account_number', 'UA' || (1000000000 + floor(random() * 9000000000))::text,
                   'client_id', floor(random() * 1000)::int + 1,
                   'operation_type', CASE WHEN random() < 0.8 THEN 'online' ELSE 'offline' END
           )                                            AS r_payload
    FROM generate_series(1, rows_count) AS i;
END;
$$ LANGUAGE plpgsql;

-- create generate_test_transactions()
CREATE OR REPLACE PROCEDURE generate_test_transactions(
    rows_count INT, 
    p_start_date TIMESTAMPTZ,
    p_range INTERVAL)
AS $$
DECLARE
    success_rows INT;
    pending_rows INT;
BEGIN
    success_rows := floor(rows_count * 0.05);
    pending_rows := rows_count - success_rows;
    
    WITH insert_data AS (
        SELECT * FROM generate_random_transaction_rows(pending_rows, 0::SMALLINT, p_start_date, p_range)
        UNION ALL
        SELECT * FROM generate_random_transaction_rows(success_rows, 1::SMALLINT, p_start_date, p_range)
    ),
    insert_guids AS (
        INSERT INTO "TransactionGuids" (operation_guid, created_at)
        SELECT r_operation_guid, r_created_at FROM insert_data
    ),
    insert_transactions AS (
        INSERT INTO "Transactions" (created_at, amount, state, operation_guid, payload)
        SELECT r_created_at, r_amount, r_state, r_operation_guid, r_payload FROM insert_data
        RETURNING client_id, operation_type, amount, state
    )
    INSERT INTO "ClientsTotal" (client_id, operation_type, total_amount)
    SELECT client_id, operation_type, sum(amount)
      FROM insert_transactions
     WHERE state = 1
     GROUP BY client_id, operation_type
        ON CONFLICT (client_id, operation_type) DO
            UPDATE SET total_amount = "ClientsTotal".total_amount + EXCLUDED.total_amount;
END;
$$
LANGUAGE plpgsql;

CALL generate_test_transactions(100000, '2026-01-01 00:00:00+00', '5 months'::interval);
