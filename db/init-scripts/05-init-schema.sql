-- 5. Update transaction states by even seconds
CREATE OR REPLACE PROCEDURE update_transaction_states()
AS $$
DECLARE
    v_parity INT := FLOOR(EXTRACT(epoch from clock_timestamp()))::BIGINT % 2;
BEGIN
    WITH flipped AS (
        UPDATE "Transactions"
           SET state = 1
         WHERE state = 0
           AND id % 2 = v_parity
        RETURNING client_id, operation_type, amount
    )

    INSERT INTO "ClientsTotal" (client_id, operation_type, total_amount)
    SELECT client_id, operation_type, SUM(amount)
      FROM flipped
     GROUP BY client_id, operation_type
    ON CONFLICT (client_id, operation_type) DO
        UPDATE SET total_amount = "ClientsTotal".total_amount + EXCLUDED.total_amount;

    REFRESH MATERIALIZED VIEW mv_client_totals;
END;
$$ LANGUAGE plpgsql;
