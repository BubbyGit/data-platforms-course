CREATE DATABASE IF NOT EXISTS taxi;

CREATE EXTERNAL TABLE IF NOT EXISTS taxi.trips_raw (
    pickup TIMESTAMP,
    dropoff TIMESTAMP,
    passengers INT,
    distance DOUBLE,
    fare DOUBLE,
    tip DOUBLE,
    tolls DOUBLE,
    total DOUBLE,
    color STRING,
    payment STRING,
    pickup_zone STRING,
    dropoff_zone STRING,
    pickup_borough STRING,
    dropoff_borough STRING
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
LOCATION '${hivevar:data_dir}';

CREATE TABLE IF NOT EXISTS taxi.trips (
    pickup TIMESTAMP,
    dropoff TIMESTAMP,
    passengers INT,
    distance DOUBLE,
    fare DOUBLE,
    tip DOUBLE,
    tolls DOUBLE,
    total DOUBLE,
    color STRING,
    payment STRING,
    pickup_zone STRING,
    dropoff_zone STRING,
    pickup_borough STRING,
    dropoff_borough STRING
)
PARTITIONED BY (pickup_date DATE)
STORED AS ORC;

INSERT OVERWRITE TABLE taxi.trips PARTITION (pickup_date)
SELECT *, to_date(pickup) FROM taxi.trips_raw;
