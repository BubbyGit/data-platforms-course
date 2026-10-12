#!/bin/bash
set -uo pipefail
source "$(dirname "$0")/common.sh"

EXPECTED=$(echo $DATANODES | wc -w)
EXAMPLES="$HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-*.jar"

live_nodemanagers() {
    as_hadoop "yarn node -list" 2> /dev/null | sed -n 's/^Total Nodes:\([0-9]*\).*/\1/p'
}

LIVE=0
for i in $(seq 1 20); do
    LIVE=$(live_nodemanagers)
    LIVE=${LIVE:-0}
    [ "$LIVE" -ge "$EXPECTED" ] && break
    sleep 3
done

for h in $NODES; do
    echo "$h - $(on "$h" "sudo -u $HADOOP_USER jps" | grep -v Jps | awk '{print $2}' | sort | xargs)"
done

as_hadoop "yarn jar $EXAMPLES pi 2 10" 2> /dev/null | grep 'Estimated value'
JOB_OK=$?

UI_OK=0
for ui in $UIS; do
    code=$(curl -s -L -o /dev/null -w '%{http_code}' --resolve "$ui:127.0.0.1" "http://$ui/")
    echo "$ui - $code"
    [ "$code" = 200 ] || UI_OK=1
done

ERRORS=$(for h in $NODES; do
    on "$h" "grep -HE ' (ERROR|FATAL) ' $HADOOP_HOME/logs/*-{resourcemanager,nodemanager,historyserver}-*.log" 2> /dev/null \
        | grep -vE 'RECEIVED SIGNAL|InterruptedException' | sed "s/^/$h: /"
done)
[ -z "$ERRORS" ] || echo "$ERRORS"

echo "live - $LIVE/$EXPECTED"
[ "$LIVE" -eq "$EXPECTED" ] && [ "$JOB_OK" -eq 0 ] && [ "$UI_OK" -eq 0 ] && [ -z "$ERRORS" ]
