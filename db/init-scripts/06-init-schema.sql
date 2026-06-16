-- 6. Create mv_client_totals
CREATE MATERIALIZED VIEW mv_client_totals AS
SELECT client_id, operation_type, total_amount FROM "ClientsTotal";

CREATE UNIQUE INDEX uq_mv_client_totals ON mv_client_totals (client_id, operation_type);