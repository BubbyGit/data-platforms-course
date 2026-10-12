#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

RUNNING=$(as_hadoop "jps")
grep -qw NameNode <<< "$RUNNING" || { echo "no hdfs - run ../hw1/deploy.sh" >&2; exit 1; }

for h in $NODES; do
    echo "$h"
    for f in yarn-site.xml mapred-site.xml; do
        sed "s|__NAMENODE__|$NAMENODE|g" "conf/$f" \
            | on "$h" "sudo -u $HADOOP_USER tee $HADOOP_HOME/etc/hadoop/$f > /dev/null"
    done
done

grep -qw ResourceManager <<< "$RUNNING" || as_hadoop "start-yarn.sh"
grep -qw JobHistoryServer <<< "$RUNNING" || as_hadoop "mapred --daemon start historyserver"

./publish.sh
./check.sh
