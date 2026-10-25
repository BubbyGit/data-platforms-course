#!/bin/bash
set -uo pipefail
source "$(dirname "$0")/common.sh"

OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT

for s in metastore hiveserver2; do
    echo "hive@$s - $(systemctl is-active "hive@$s")"
done

wait_port 10000
hql -e "SELECT count(*), count(DISTINCT to_date(pickup)) FROM taxi.trips_raw" > "$OUT/raw" 2> /dev/null &
hql -e "SELECT count(*), count(DISTINCT pickup_date) FROM taxi.trips" > "$OUT/trips" 2> /dev/null &
wait
read -r RAW_ROWS RAW_DAYS < "$OUT/raw"
read -r ROWS DAYS < "$OUT/trips"
PARTS=$(hql -e "SHOW PARTITIONS taxi.trips" 2> /dev/null | wc -l)

echo "trips_raw - ${RAW_ROWS:-0} rows, ${RAW_DAYS:-0} days"
echo "trips - ${ROWS:-0} rows, ${DAYS:-0} days, $PARTS partitions"

ERRORS=$(grep -HE ' ERROR ' "$HIVE_HOME"/logs/*.log | grep -v AlreadyExistsException)
[ -z "$ERRORS" ] || echo "$ERRORS"

systemctl is-active -q hive@metastore hive@hiveserver2 \
    && [ "${RAW_ROWS:-0}" -gt 0 ] && [ "$ROWS" = "$RAW_ROWS" ] \
    && [ "$DAYS" = "$RAW_DAYS" ] && [ "$PARTS" = "$RAW_DAYS" ] && [ -z "$ERRORS" ]
