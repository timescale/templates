CREATE MATERIALIZED VIEW rates_materialized_30_seconds
WITH (timescaledb.continuous, timescaledb.materialized_only = true) AS SELECT time_bucket('00:00:30'::interval, rates."timestamp") AS bucket_30_seconds,
    rates."from",
    rates."to",
    candlestick_agg(rates."timestamp", rates.ask, (1)::double precision) AS ask_candlestick_30_seconds,
    candlestick_agg(rates."timestamp", rates.bid, (1)::double precision) AS bid_candlestick_30_seconds,
    candlestick_agg(rates."timestamp", ((rates.ask + rates.bid) / (2)::double precision), (1)::double precision) AS mid_candlestick_30_seconds
   FROM rates
  GROUP BY (time_bucket('00:00:30'::interval, rates."timestamp")), rates."from", rates."to";

CREATE MATERIALIZED VIEW rates_materialized_10_minutes
WITH (timescaledb.continuous, timescaledb.materialized_only = true) AS SELECT time_bucket('00:10:00'::interval, rates_materialized_30_seconds.bucket_30_seconds) AS bucket_10_minutes,
    rates_materialized_30_seconds."from",
    rates_materialized_30_seconds."to",
    rollup(rates_materialized_30_seconds.ask_candlestick_30_seconds) AS ask_candlestick_10_minutes,
    rollup(rates_materialized_30_seconds.bid_candlestick_30_seconds) AS bid_candlestick_10_minutes,
    rollup(rates_materialized_30_seconds.mid_candlestick_30_seconds) AS mid_candlestick_10_minutes
   FROM rates_materialized_30_seconds
  GROUP BY (time_bucket('00:10:00'::interval, rates_materialized_30_seconds.bucket_30_seconds)), rates_materialized_30_seconds."from", rates_materialized_30_seconds."to";

CREATE MATERIALIZED VIEW rates_materialized_1_hour
WITH (timescaledb.continuous, timescaledb.materialized_only = true) AS SELECT time_bucket('01:00:00'::interval, rates_materialized_10_minutes.bucket_10_minutes) AS bucket_1_hour,
    rates_materialized_10_minutes."from",
    rates_materialized_10_minutes."to",
    rollup(rates_materialized_10_minutes.ask_candlestick_10_minutes) AS ask_candlestick_1_hour,
    rollup(rates_materialized_10_minutes.bid_candlestick_10_minutes) AS bid_candlestick_1_hour,
    rollup(rates_materialized_10_minutes.mid_candlestick_10_minutes) AS mid_candlestick_1_hour
   FROM rates_materialized_10_minutes
  GROUP BY (time_bucket('01:00:00'::interval, rates_materialized_10_minutes.bucket_10_minutes)), rates_materialized_10_minutes."from", rates_materialized_10_minutes."to";

CREATE MATERIALIZED VIEW rates_materialized_6_hours
WITH (timescaledb.continuous, timescaledb.materialized_only = true) AS SELECT time_bucket('06:00:00'::interval, rates_materialized_1_hour.bucket_1_hour) AS bucket_6_hours,
    rates_materialized_1_hour."from",
    rates_materialized_1_hour."to",
    rollup(rates_materialized_1_hour.ask_candlestick_1_hour) AS ask_candlestick_6_hours,
    rollup(rates_materialized_1_hour.bid_candlestick_1_hour) AS bid_candlestick_6_hours,
    rollup(rates_materialized_1_hour.mid_candlestick_1_hour) AS mid_candlestick_6_hours
   FROM rates_materialized_1_hour
  GROUP BY (time_bucket('06:00:00'::interval, rates_materialized_1_hour.bucket_1_hour)), rates_materialized_1_hour."from", rates_materialized_1_hour."to";

CREATE MATERIALIZED VIEW rates_materialized_2_days
WITH (timescaledb.continuous, timescaledb.materialized_only = true) AS SELECT time_bucket('2 days'::interval, rates_materialized_6_hours.bucket_6_hours) AS bucket_2_days,
    rates_materialized_6_hours."from",
    rates_materialized_6_hours."to",
    rollup(rates_materialized_6_hours.ask_candlestick_6_hours) AS ask_candlestick_2_days,
    rollup(rates_materialized_6_hours.bid_candlestick_6_hours) AS bid_candlestick_2_days,
    rollup(rates_materialized_6_hours.mid_candlestick_6_hours) AS mid_candlestick_2_days
   FROM rates_materialized_6_hours
  GROUP BY (time_bucket('2 days'::interval, rates_materialized_6_hours.bucket_6_hours)), rates_materialized_6_hours."from", rates_materialized_6_hours."to";
10:10
CREATE TABLE public.rates (
    "timestamp" timestamp with time zone NOT NULL,
    "from" text NOT NULL,
    "to" text NOT NULL,
    ask double precision NOT NULL,
    bid double precision NOT NULL
);
