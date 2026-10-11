# ДЗ 1. Кластер HDFS

NameNode, Secondary NameNode и три DataNode. Hadoop 3.4.0, Java 11, Ubuntu 24.04.

| Узел | Что работает |
|------|--------------|
| team-04-nn | NameNode, Secondary NameNode, DataNode |
| team-04-00 | DataNode |
| team-04-01 | DataNode |

## Как развернуть скриптом?
Запускаем на edge-ноде. Имена узлов и версия Hadoop лежат в `cluster.conf`.
```
git clone https://github.com/BubbyGit/data-platforms-course.git
cd data-platforms-course/hw1
./deploy.sh
```

## Как развернуть руками?
Шаги 1-5 делаем на всех трех узлах, 6 и 7 на team-04-nn.
1. Ставим Java
```
sudo apt-get update && sudo apt-get install -y openjdk-11-jdk-headless
```
2. Комментируем `127.0.1.1` в `/etc/hosts`, иначе NameNode слушает только на loopback
```
sudo sed -i -E 's/^127\.0\.1\.1[[:space:]]/#&/' /etc/hosts
```
3. Создаем пользователя `hadoop` без sudo и пароля
```
sudo useradd -m -s /bin/bash hadoop
sudo -u hadoop mkdir -m 700 /home/hadoop/.ssh
```
4. Скачиваем и распаковываем Hadoop, задаем переменные окружения
```
wget -P /tmp https://dlcdn.apache.org/hadoop/common/hadoop-3.4.0/hadoop-3.4.0.tar.gz
sudo mkdir -p /opt/hadoop /opt/hadoop_data
sudo tar -xzf /tmp/hadoop-3.4.0.tar.gz -C /opt/hadoop --strip-components=1
echo 'export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64' | sudo tee -a /etc/profile.d/hadoop.sh /opt/hadoop/etc/hadoop/hadoop-env.sh
echo 'export HADOOP_HOME=/opt/hadoop' | sudo tee -a /etc/profile.d/hadoop.sh
echo 'export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin' | sudo tee -a /etc/profile.d/hadoop.sh
```
5. Кладем в `/opt/hadoop/etc/hadoop` конфиги из папки `conf`, подставив в них team-04-nn и `/opt/hadoop_data`. Пишем список DataNode, отдаем все пользователю `hadoop`, проверяем установку
```
printf 'team-04-nn\nteam-04-00\nteam-04-01\n' | sudo tee /opt/hadoop/etc/hadoop/workers
sudo chown -R hadoop:hadoop /opt/hadoop /opt/hadoop_data
sudo -iu hadoop hadoop version
```
6. Делаем ssh-ключ для `hadoop`. Строку из `id_ed25519.pub` кладем в `/home/hadoop/.ssh/authorized_keys` на всех трех узлах
```
sudo -u hadoop ssh-keygen -t ed25519 -N '' -f /home/hadoop/.ssh/id_ed25519
```
7. Форматируем NameNode и запускаем кластер
```
sudo -iu hadoop hdfs namenode -format
sudo -iu hadoop start-dfs.sh
```

## Как проверить?
Скриптом с edge-ноды или руками. `jps` показывает процессы на узле, в отчете должно быть `Live datanodes (3)`.
```
./check.sh
sudo -u hadoop jps
sudo -iu hadoop hdfs dfsadmin -report
```
Веб-интерфейс NameNode открываем через туннель по адресу http://localhost:9870. У DataNode порт 9864.
```
ssh -L 9870:team-04-nn:9870 team@EDGE_IP
```
Останавливаем кластер через `sudo -iu hadoop stop-dfs.sh`, удаляем все через `./cleanup.sh`.
