# ДЗ 2. YARN и веб-интерфейсы

YARN поставил поверх hdfs из hw1. ResourceManager и JobHistory Server живут на team-04-nn рядом с NameNode, NodeManager на всех трёх узлах. наружу интерфейсы отдаёт nginx на edge-ноде.

запускать на edge-ноде после `hw1/deploy.sh`. логин лежит в `cluster.conf`, пароль скрипт спросит сам
```
cd data-platforms-course/hw2 && ./deploy.sh
```

руками то же самое. на все три узла кладу `conf/yarn-site.xml` и `conf/mapred-site.xml` в `/opt/hadoop/etc/hadoop`, вместо `__NAMENODE__` подставляю team-04-nn. потом на team-04-nn запускаю `sudo -iu hadoop start-yarn.sh` и `sudo -iu hadoop mapred --daemon start historyserver`.

на edge-ноде ставлю nginx через `sudo apt-get update && sudo apt-get install -y nginx` и задаю пароль: `echo "admin:$(openssl passwd -apr1)" | sudo tee /etc/nginx/.htpasswd`. в `/etc/nginx/sites-enabled/hadoop` кладу блок из `conf/nginx-site.conf` на каждый узел и порт, удаляю `/etc/nginx/sites-enabled/default` и делаю `sudo systemctl restart nginx`.

NodeManager дал 2048 МБ и 2 ядра, по умолчанию он считает что на узле 8 ГБ и 8 ядер, а у нас 4 ГБ и 2. пароль на nginx нужен, потому что через открытый 8088 кто угодно может запустить задачу на кластере.

интерфейсы открываются по `http://EDGE_IP:ПОРТ`: NameNode 9870, Secondary NameNode 9868, ResourceManager 8088, JobHistory Server 19888, DataNode 9864, NodeManager 8042. по ip отвечает team-04-nn. nginx различает узлы по имени, так что для остальных узлов и для ссылок между интерфейсами надо дописать у себя в `/etc/hosts` строку `EDGE_IP team-04-nn team-04-00 team-04-01`.

проверка через `./check.sh`: ждёт три NodeManager, запускает pi, опрашивает все интерфейсы через nginx и смотрит ошибки в логах. с самой edge-ноды пароль не нужен, поэтому скрипт его не спрашивает. остановить всё и убрать сайт nginx можно через `./cleanup.sh`
