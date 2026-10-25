#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

RUNNING=$(on "$NAMENODE" "sudo -u $HADOOP_USER jps")
grep -qw NameNode <<< "$RUNNING" || { echo "no hdfs - run ../hw1/deploy.sh" >&2; exit 1; }
grep -qw ResourceManager <<< "$RUNNING" || { echo "no yarn - run ../hw2/deploy.sh" >&2; exit 1; }

PACKAGES="openjdk-11-jdk-headless postgresql"
if ! dpkg -s $PACKAGES > /dev/null 2>&1; then
    sudo apt-get -o DPkg::Lock::Timeout=300 update -qq
    sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_SUSPEND=1 \
        apt-get -o DPkg::Lock::Timeout=300 install -y -qq $PACKAGES > /dev/null
fi
JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")

unpack() {
    local tarball="/tmp/${1##*/}"
    if [ ! -f "$tarball" ]; then
        wget -q --show-progress -O "$tarball.part" "https://dlcdn.apache.org/$1" \
            || wget -q --show-progress -O "$tarball.part" "https://archive.apache.org/dist/$1"
        mv "$tarball.part" "$tarball"
    fi
    sudo mkdir -p "$2"
    sudo tar -xzf "$tarball" -C "$2" --strip-components=1
}

[ -x "$HADOOP_HOME/bin/hadoop" ] || unpack "hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz" "$HADOOP_HOME"
[ -x "$HIVE_HOME/bin/hive" ] || unpack "hive/hive-$HIVE_VERSION/apache-hive-$HIVE_VERSION-bin.tar.gz" "$HIVE_HOME"

on "$NAMENODE" "tar -C $HADOOP_HOME/etc/hadoop -c core-site.xml hdfs-site.xml yarn-site.xml mapred-site.xml" \
    | sudo tar -C "$HADOOP_HOME/etc/hadoop" -x --no-same-owner

sudo tee /etc/profile.d/hive.sh > /dev/null << EOF
export JAVA_HOME=$JAVA_HOME
export HADOOP_HOME=$HADOOP_HOME
export HIVE_HOME=$HIVE_HOME
export PATH=\$PATH:\$HADOOP_HOME/bin:\$HIVE_HOME/bin
EOF

id "$HADOOP_USER" > /dev/null 2>&1 || sudo useradd -m -s /bin/bash "$HADOOP_USER"
sudo mkdir -p "$HIVE_HOME/logs"
sudo chown -R "$HADOOP_USER:$HADOOP_USER" "$HADOOP_HOME" "$HIVE_HOME"

DB_PASS=$(openssl rand -hex 16)
sudo -iu postgres psql -q -v ON_ERROR_STOP=1 << EOF
SELECT 'CREATE ROLE $DB_USER LOGIN' WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '$DB_USER')\gexec
ALTER ROLE $DB_USER PASSWORD '$DB_PASS';
SELECT 'CREATE DATABASE $DB_NAME OWNER $DB_USER' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$DB_NAME')\gexec
EOF

sed -e "s|__DB_NAME__|$DB_NAME|g" -e "s|__DB_USER__|$DB_USER|g" -e "s|__DB_PASS__|$DB_PASS|g" conf/hive-site.xml \
    | sudo install -m 600 -o "$HADOOP_USER" -g "$HADOOP_USER" /dev/stdin "$HIVE_HOME/conf/hive-site.xml"
sed -e "s|__HADOOP_USER__|$HADOOP_USER|g" -e "s|__JAVA_HOME__|$JAVA_HOME|g" \
    -e "s|__HADOOP_HOME__|$HADOOP_HOME|g" -e "s|__HIVE_HOME__|$HIVE_HOME|g" "conf/hive@.service" \
    | sudo tee /etc/systemd/system/hive@.service > /dev/null

as_hadoop hdfs dfs -mkdir -p /tmp /user/hive/warehouse
as_hadoop hdfs dfs -chmod g+w /tmp /user/hive/warehouse
quiet as_hadoop schematool -dbType postgres -initOrUpgradeSchema

sudo systemctl daemon-reload
sudo systemctl enable -q hive@metastore hive@hiveserver2
for s in metastore:9083 hiveserver2:10000; do
    sudo systemctl restart "hive@${s%:*}"
    wait_port "${s#*:}" || { echo "no ${s%:*} - journalctl -u hive@${s%:*}" >&2; exit 1; }
done

./load.sh
./check.sh
