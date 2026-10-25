#!/bin/bash
set -uo pipefail
source "$(dirname "$0")/common.sh"

read -r -p "rm $HIVE_HOME $HADOOP_HOME, drop $DB_NAME [y/N] " answer
[ "$answer" = "y" ] || exit 0

sudo systemctl disable -q --now hive@hiveserver2 hive@metastore
as_hadoop hdfs dfs -rm -r -f -skipTrash /user/hive "$DATA_DIR"
sudo -iu postgres psql -q -c "DROP DATABASE IF EXISTS $DB_NAME" -c "DROP ROLE IF EXISTS $DB_USER"

sudo rm -f /etc/systemd/system/hive@.service /etc/profile.d/hive.sh
sudo systemctl daemon-reload
sudo pkill -u "$HADOOP_USER"
sudo rm -rf "$HIVE_HOME" "$HADOOP_HOME"
sudo userdel -r "$HADOOP_USER" 2> /dev/null
