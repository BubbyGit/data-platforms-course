#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

as_hadoop hdfs dfs -mkdir -p "$DATA_DIR"
wget -q -O - "$DATA_URL" | tail -n +2 | as_hadoop hdfs dfs -put -f - "$DATA_DIR/${DATA_URL##*/}"
quiet hql --hivevar data_dir="$DATA_DIR" -f /dev/stdin < load.hql
