-- 4. Insert pending transaction
CREATE OR REPLACE PROCEDURE insert_pending_transaction()
AS $$
BEGIN
    WITH data_to_insert AS (
        SELECT * 
        FROM generate_random_transaction_rows
         (
            1,
            0::SMALLINT,
            NOW(),
            '0 seconds'::interval
         )
    ),
    insert_guids AS (
        INSERT INTO "TransactionGuids" (operation_guid, created_at)
        SELECT r_operation_guid, r_created_at FROM data_to_insert
    )

    INSERT INTO "Transactions" (created_at, amount, state, operation_guid, payload)
    SELECT r_created_at, r_amount, r_state, r_operation_guid, r_payload FROM data_to_insert;
END;
$$ LANGUAGE plpgsql;