-- continuous aggregates for average value
\set value_expr payload->>'temperature'

DO $$
  DECLARE timeframes TEXT[] = '{"1m", "1h", "1d", "1mon", "1y"}' ;
  DECLARE count INT;
  DECLARE last_view regclass;
  BEGIN
  FOR count IN 1..array_length(timeframes) LOOP
    if count == 1 then
        last_view = :hypertable:cagg_timeframe
        CREATE MATERIALIZED VIEW :last_view
        WITH (timescaledb.continuous, timescaledb.materialized_only=false) AS
            select time_bucket(timeframes[count], time) as bucket,
            :segment,
            stats_aggs(:value_expr)
        FROM :hypertable group by 1, 2;
    else
        create view :hypertable_:h_frame
        WITH (timescaledb.continuous)
        AS
        select time_bucket(timeframes[count], bucket) as bucket,
        :segment,
        rollup(stats_aggs) as stats_aggs from :last_view group by 1, 2;
    end if;
    END LOOP;
 END; 
$$

