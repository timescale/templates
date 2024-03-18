-- continuous aggregates for stats_aggs of the value
\set value_expr ':payload_name'
\set cagg_1m stats_agg_1m_:hypertable
\set hcagg_1h stats_agg_1h_:hypertable
\set hcagg_1d stats_agg_1d_:hypertable
\set hcagg_1m stats_agg_1M_:hypertable


CREATE MATERIALIZED VIEW :cagg_1m
WITH (timescaledb.continuous, timescaledb.materialized_only=true) AS
   select time_bucket('1m', time) as bucket,
   :segment,
   stats_agg(:value_expr)
FROM :hypertable GROUP BY 1, 2
WITH NO DATA;

CREATE MATERIALIZED VIEW :hcagg_1h WITH (timescaledb.continuous) AS
SELECT time_bucket('1h', bucket) as bucket,
  :segment,
  rollup(stats_agg) AS stats_agg
  FROM :cagg_1m GROUP BY 1, 2
WITH NO DATA;

CREATE MATERIALIZED VIEW :hcagg_1d WITH (timescaledb.continuous) AS
SELECT time_bucket('1d', bucket) as bucket,
  :segment,
  rollup(stats_agg) as stats_agg
  FROM :hcagg_1h GROUP BY 1, 2
WITH NO DATA;

CREATE MATERIALIZED VIEW :hcagg_1m WITH (timescaledb.continuous) AS
SELECT time_bucket('1d', bucket) as bucket,
  :segment,
  rollup(stats_agg) as stats_agg
  FROM :hcagg_1d GROUP BY 1, 2
WITH NO DATA;
