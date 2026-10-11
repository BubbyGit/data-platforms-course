#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

TARBALL="hadoop-$HADOOP_VERSION.tar.gz"
HADOOP_KEY="/home/$HADOOP_USER/.ssh/id_ed25519"

if [ ! -f "/tmp/$TARBALL" ]; then
    wget -q --show-progress -O "/tmp/$TARBALL.part" \
        "https://dlcdn.apache.org/hadoop/common/hadoop-$HADOOP_VERSION/$TARBALL" \
    || wget -q --show-progress -O "/tmp/$TARBALL.part" \
        "https://archive.apache.org/dist/hadoop/common/hadoop-$HADOOP_VERSION/$TARBALL"
    mv "/tmp/$TARBALL.part" "/tmp/$TARBALL"
fi

HOSTS_LINES=""
for h in $NODES; do
    ip=$(getent hosts "$h" | awk 'NR==1 {print $1}') || { echo "no ip - $h" >&2; exit 1; }
    HOSTS_LINES+="$ip $h"$'\n'
done

for h in $NODES; do
    echo "$h"
    on "$h" "mkdir -p /tmp/hdfs_setup"
    scp $SSH_OPTS -qr cluster.conf node_setup.sh conf "$SSH_USER@$h:/tmp/hdfs_setup/"
    echo "$HOSTS_LINES" | on "$h" "cat > /tmp/hdfs_setup/hosts.cluster"
    if ! on "$h" "test -x $HADOOP_HOME/bin/hdfs"; then
        scp $SSH_OPTS -q "/tmp/$TARBALL" "$SSH_USER@$h:/tmp/"
    fi
    on "$h" "sudo bash /tmp/hdfs_setup/node_setup.sh && rm -rf /tmp/hdfs_setup"
done

on "$NAMENODE" "sudo test -f $HADOOP_KEY || sudo -u $HADOOP_USER ssh-keygen -q -t ed25519 -N '' -f $HADOOP_KEY"
PUBKEY=$(on "$NAMENODE" "sudo cat $HADOOP_KEY.pub")
for h in $NODES; do
    echo "$PUBKEY" | on "$h" "sudo -u $HADOOP_USER tee /home/$HADOOP_USER/.ssh/authorized_keys > /dev/null \
        && sudo chmod 600 /home/$HADOOP_USER/.ssh/authorized_keys"
done

if ! on "$NAMENODE" "sudo test -d $HADOOP_DATA/namenode/current"; then
    as_hadoop "hdfs namenode -format -nonInteractive" 2>&1 | grep -E 'successfully formatted|ERROR|FATAL'
fi

RUNNING=$(as_hadoop "jps")
grep -qw NameNode <<< "$RUNNING" || as_hadoop "start-dfs.sh"

./check.sh
