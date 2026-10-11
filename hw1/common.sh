cd "$(dirname "${BASH_SOURCE[0]}")"
source ./cluster.conf

NODES=$(echo "$NAMENODE $SECONDARY_NAMENODE $DATANODES" | xargs -n1 | sort -u)
SSH_OPTS="-i $SSH_KEY -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR"

on() {
    local host=$1
    shift
    ssh $SSH_OPTS "$SSH_USER@$host" "$@"
}

as_hadoop() {
    on "$NAMENODE" "sudo -iu $HADOOP_USER $*"
}
