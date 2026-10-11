#!/bin/bash
set -uo pipefail
source "$(dirname "$0")/common.sh"

read -r -p "rm $HADOOP_HOME $HADOOP_DATA [y/N] " answer
[ "$answer" = "y" ] || exit 0

as_hadoop "stop-dfs.sh" 2> /dev/null

for h in $NODES; do
    echo "$h"
    on "$h" "sudo pkill -u $HADOOP_USER; sudo rm -rf $HADOOP_HOME $HADOOP_DATA /etc/profile.d/hadoop.sh; sudo userdel -r $HADOOP_USER 2> /dev/null; true"
done
