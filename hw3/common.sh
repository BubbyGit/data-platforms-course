cd "$(dirname "${BASH_SOURCE[0]}")"
source ./cluster.conf

SSH_OPTS="-i $SSH_KEY -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR"
HIVE_URL="jdbc:hive2://localhost:10000"

on() {
    local host=$1
    shift
    ssh $SSH_OPTS "$SSH_USER@$host" "$@"
}

as_hadoop() {
    sudo -iu "$HADOOP_USER" "$@"
}

hql() {
    as_hadoop beeline -u "$HIVE_URL" --silent=true --showHeader=false --outputformat=tsv2 "$@"
}

quiet() {
    "$@" 2>&1 | sed '/^$/d; /^SLF4J: /d'
}

wait_port() {
    for i in $(seq 1 60); do
        (: < "/dev/tcp/localhost/$1") 2> /dev/null && return
        sleep 2
    done
    return 1
}
