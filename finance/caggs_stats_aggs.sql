CREATE MATERIALIZED VIEW _stats_1m
WITH (timescaledb.continuous, timescaledb.materialized_only=false) AS
SELECT time_bucket('1m', time) AS bucket,
       origin,
       stats_agg(time, price) AS stats
FROM ticks
GROUP BY 1, 2 WITH NO DATA;

CREATE VIEW ohlcv_1m AS
  SELECT bucket,
    origin,
    open(stats),
    high(stats),
    low(stats),
    close(stats),
    volume(stats),
    vwap(stats)
FROM _ohlcv_1m ;

CREATE MATERIALIZED VIEW _ohlcv_1h
WITH (timescaledb.continuous) AS
SELECT time_bucket('1h', bucket) AS bucket,
       origin,
       rollup(stats) as stats
FROM _ohlcv_1m
GROUP BY 1, 2 WITH NO DATA;

CREATE VIEW ohlcv_1h AS
  SELECT bucket,
    origin,
    open(stats),
    high(stats),
    low(stats),
    close(stats),
    volume(stats),
    vwap(stats)
FROM _ohlcv_1h;

CREATE MATERIALIZED VIEW _ohlcv_1d
WITH (timescaledb.continuous) AS
SELECT time_bucket('1d', bucket) AS bucket,
       origin,
       rollup(stats) as stats
FROM _ohlcv_1h
GROUP BY 1, 2 WITH NO DATA;

CREATE VIEW ohlcv_1d AS
  SELECT bucket,
    origin,
    open(stats),
    high(stats),
    low(stats),
    close(stats),
    volume(stats),
    vwap(stats)
FROM _ohlcv_1d ;


SELECT add_continuous_aggregate_policy('_ohlcv_1m',
  start_offset => INTERVAL '2 min',
  end_offset => INTERVAL '1 m',
  schedule_interval => INTERVAL '1 m');

SELECT add_continuous_aggregate_policy('_ohlcv_1h',
  start_offset => INTERVAL '2 hours',
  end_offset => INTERVAL '1 h',
  schedule_interval => INTERVAL '1 s');

SELECT add_continuous_aggregate_policy('_ohlcv_1d',
  start_offset => INTERVAL '36 hours',
  end_offset => INTERVAL '12 hours',
  schedule_interval => INTERVAL '1 s');


SELECT add_job('refresh_all_caggs', '1 sec');
