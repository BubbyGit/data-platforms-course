# ДЗ 3. Hive

Hive 4.0.0-alpha-2 поставил на edge-ноду поверх hdfs и yarn из hw1 и hw2. metastore и hiveserver2 крутятся отдельными сервисами через systemd, метаданные лежатт в postgresql там же на edge, так что embedded derby нет и подключаться можно сразу нескольким клиентам. на team-04-nn hive не ставил, там и так мало памяти.

запускать на edge-ноде после `hw2/deploy.sh`. версии и пути лежат в `cluster.conf`, пароль к базе скрипт генерирует сам. в конце он грузит данные и запускает проверку
```
cd data-platforms-course/hw3 && ./deploy.sh
```

руками то же самое. ставлю `openjdk-11-jdk-headless` и `postgresql`, завожу пользователя `hadoop`. hadoop 3.4.0 распаковываю в `/opt/hadoop` и забираю с team-04-nn `core-site.xml`, `hdfs-site.xml`, `yarn-site.xml` и `mapred-site.xml`. hive распаковываю в `/opt/hive`, драйвер postgres в нём уже есть. в postgres создаю роль `hive` с паролем и базу `metastore`. в `/opt/hive/conf` кладуу `conf/hive-site.xml` с подставленным паролем и правами 600, в `/etc/systemd/system` кладу `conf/hive@.service`. в hdfs создаю `/tmp`, `/user/hive/warehouse` и `/data/taxis`, схему делаю через `sudo -iu hadoop schematool -dbType postgres -initSchema` и запускаю `sudo systemctl enable --now hive@metastore hive@hiveserver2`.

у edge есть внешний ip, поэтому postgres, metastore (9083), hiveserver2 (10000) и его веб-интерфейс (10002) слушают только localhost. со своей машины хожу через `ssh -L 10000:localhost:10000 team@EDGE_IP`. doAs выключил, прокси-пользователей в hadoop нет, так что все запросы идут от `hadoop`. `hive.metastore.event.db.notification.api.auth` тоже выключил, без этого hiveserver2 не стартует.

данные грузит `./load.sh`: поездки такси нью-йорка за март 2019 из seaborn-data, 6433 строки. csv ложится в `/data/taxis`, поверх него внешняя таблица `taxi.trips_raw`, а `load.hql` через `INSERT OVERWRITE` с динамическими партициями переливает её в `taxi.trips` (orc, партиция на каждый день `pickup_date`). заголовок срезаю ещё до hdfs, alpha-2 в mapreduce-запросах всё равно читал его как строку, несмотря на `skip.header.line.count`. руками
```
wget -qO- https://raw.githubusercontent.com/mwaskom/seaborn-data/master/taxis.csv | tail -n +2 | sudo -iu hadoop hdfs dfs -put -f - /data/taxis/taxis.csv
sudo -iu hadoop beeline -u jdbc:hive2://localhost:10000 --hivevar data_dir=/data/taxis -f /dev/stdin < load.hql
```

проверка через `./check.sh`: показывает статус сервисов, запускает два beeline одновременно, сравнивает строки и дни в `trips_raw` и `trips` с числом партиций и смотрит ошибки в `/opt/hive/logs`. руками можно открыть beeline в двух терминалах и сделать `SHOW PARTITIONS taxi.trips`. удалить всё можно через `./cleanup.sh`
