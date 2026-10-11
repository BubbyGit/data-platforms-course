#!/bin/bash
set -uo pipefail
source "$(dirname "$0")/common.sh"

EXPECTED=$(echo $DATANODES | wc -w)

live_datanodes() {
    as_hadoop "hdfs dfsadmin -report" 2> /dev/null | sed -n 's/^Live datanodes (\([0-9]*\)).*/\1/p'
}

LIVE=0
for i in $(seq 1 20); do
    LIVE=$(live_datanodes)
    LIVE=${LIVE:-0}
    [ "$LIVE" -ge "$EXPECTED" ] && break
    sleep 3
done

for h in $NODES; do
    echo "$h - $(on "$h" "sudo -u $HADOOP_USER jps" | grep -v Jps | awk '{print $2}' | sort | xargs)"
done

as_hadoop "hdfs dfsadmin -report" 2> /dev/null | grep -E '^(Live datanodes|Dead datanodes|Name:)'

as_hadoop "hdfs dfs -put -f /etc/hostname /check.txt" \
    && as_hadoop "hdfs dfs -cat /check.txt" \
    && as_hadoop "hdfs dfs -rm -skipTrash /check.txt"
WRITE_OK=$?

ERRORS=$(for h in $NODES; do
    on "$h" "grep -HE ' (ERROR|FATAL) ' $HADOOP_HOME/logs/*.log" | grep -v 'RECEIVED SIGNAL' | sed "s/^/$h: /"
done)
[ -z "$ERRORS" ] || echo "$ERRORS"

echo "live - $LIVE/$EXPECTED"
[ "$LIVE" -eq "$EXPECTED" ] && [ "$WRITE_OK" -eq 0 ] && [ -z "$ERRORS" ]
