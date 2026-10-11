#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
source ./cluster.conf

if ! command -v java > /dev/null || ! command -v jps > /dev/null; then
    export DEBIAN_FRONTEND=noninteractive NEEDRESTART_SUSPEND=1
    apt-get -o DPkg::Lock::Timeout=300 update -qq
    apt-get -o DPkg::Lock::Timeout=300 install -y -qq openjdk-11-jdk-headless > /dev/null
fi
JAVA_HOME=$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")

[ -f /etc/hosts.orig ] || cp /etc/hosts /etc/hosts.orig
sed -i -E 's/^127\.0\.1\.1[[:space:]]/#&/' /etc/hosts
while read -r ip name; do
    [ -n "$name" ] || continue
    grep -qE "^[^#].*[[:space:]]$name([[:space:]]|\$)" /etc/hosts || echo "$ip $name" >> /etc/hosts
done < hosts.cluster

id "$HADOOP_USER" > /dev/null 2>&1 || useradd -m -s /bin/bash "$HADOOP_USER"
install -d -m 700 -o "$HADOOP_USER" -g "$HADOOP_USER" "/home/$HADOOP_USER/.ssh"

if [ ! -x "$HADOOP_HOME/bin/hdfs" ]; then
    mkdir -p "$HADOOP_HOME"
    tar -xzf "/tmp/hadoop-$HADOOP_VERSION.tar.gz" -C "$HADOOP_HOME" --strip-components=1
    rm -f "/tmp/hadoop-$HADOOP_VERSION.tar.gz"
fi
mkdir -p "$HADOOP_DATA"

cat > /etc/profile.d/hadoop.sh << EOF
export JAVA_HOME=$JAVA_HOME
export HADOOP_HOME=$HADOOP_HOME
export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin
EOF

CONF_DIR="$HADOOP_HOME/etc/hadoop"
grep -q '^export JAVA_HOME=' "$CONF_DIR/hadoop-env.sh" \
    || echo "export JAVA_HOME=$JAVA_HOME" >> "$CONF_DIR/hadoop-env.sh"
for f in core-site.xml hdfs-site.xml; do
    sed -e "s|__NAMENODE__|$NAMENODE|g" \
        -e "s|__SECONDARY_NAMENODE__|$SECONDARY_NAMENODE|g" \
        -e "s|__HADOOP_DATA__|$HADOOP_DATA|g" \
        "conf/$f" > "$CONF_DIR/$f"
done
echo "$DATANODES" | xargs -n1 > "$CONF_DIR/workers"

chown -R "$HADOOP_USER:$HADOOP_USER" "$HADOOP_HOME" "$HADOOP_DATA"

su - "$HADOOP_USER" -c "hadoop version" | sed -n 1p
