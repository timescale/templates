-- continuous aggregates for stats_aggs of the value
\set cagg_1m stats_agg_minute_:hypertable
\set hcagg_1h stats_agg_hour_:hypertable
\set hcagg_1d stats_agg_day_:hypertable
\set hcagg_1m stats_agg_month_:hypertable

\set func_expr stats_agg(':payload_name')
\set rollup_expr rollup(stats_agg) AS stats_agg


CREATE MATERIALIZED VIEW :cagg_1m
WITH (timescaledb.continuous, timescaledb.materialized_only=true) AS
   SELECT time_bucket('1m', time) as bucket,
     :segment,
     :func_expr
FROM :hypertable GROUP BY 1, 2
WITH NO DATA;

CREATE MATERIALIZED VIEW :hcagg_1h WITH (timescaledb.continuous) AS
  SELECT time_bucket('1h', bucket) as bucket,
    :segment,
    :rollup_expr
  FROM :cagg_1m GROUP BY 1, 2
WITH NO DATA;

CREATE MATERIALIZED VIEW :hcagg_1d WITH (timescaledb.continuous) AS
  SELECT time_bucket('1d', bucket) as bucket,
    :segment,
    :rollup_expr
  FROM :hcagg_1h GROUP BY 1, 2
WITH NO DATA;

CREATE MATERIALIZED VIEW :hcagg_1m WITH (timescaledb.continuous) AS
  SELECT time_bucket('1m', bucket) as bucket,
    :segment,
    :rollup_expr
  FROM :hcagg_1d GROUP BY 1, 2
WITH NO DATA;
