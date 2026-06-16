set -e

echo "Waiting for Master DB to be ready..."
until pg_isready -h postgres_master -p 5432 -U "$POSTGRES_USER" -d "$POSTGRES_DB"; do
  sleep 1
done

echo "Waiting for master schema to be fully initialized..."
export PGPASSWORD="$POSTGRES_PASSWORD"
until psql -h postgres_master -p 5432 -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  -tc "SELECT 1 FROM pg_publication WHERE pubname = 'pub_transactions'" | grep -q 1; do
  echo "Publication not ready yet, retrying..."
  sleep 2
done

echo "Master ready! Copying schema..."
pg_dump \
  -h postgres_master -p 5432 -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  --schema-only \
  -t '"Transactions"' \
  -t 'transactions_y*' \
  -t 'transactions_default' \
  | psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"

echo "Schema copied. Creating subscription..."
psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "
CREATE SUBSCRIPTION sub_transactions
CONNECTION 'host=postgres_master port=5432 user=$POSTGRES_USER password=$POSTGRES_PASSWORD dbname=$POSTGRES_DB'
PUBLICATION pub_transactions;"

echo "Logical replication successfully initialized!"