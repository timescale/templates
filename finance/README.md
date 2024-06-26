# Timescale Finance

To test the finance model just use this shortcut:

```
git clone git@github.com:timescale/templates.git
cd templates/finance
psql $PG_URI -f main.sql
```

The provided SQL files in your instance will set up the database schema and some
utilities.

The [main.sql](./main.sql)  load all features in the order, or you can choose to load:

* [schema.sql](./schema.sql) setup the `schema` hypertable with compression settings
 and add continuous aggregates and utility view to track `ohlcv_1m` and `ohlcv_1h`.

* [caggs_candlesticks.sql](./caggs_candlesticks.sql) will create Hierarchical Continuous
Aggregates with the `candlestick_agg` function to track minute, hourly, dayly and monthly.

* [track_last_symbol_price](./track_last_symbol_price.sql) will track `last`
 `last_price` on `symbols` table too.

* [pairs.sql](./pairs.sql) allows you to `track_pairs` of trades and pipe it
    `schema` back to `schema` table.

* [cleanup.sql](./cleanup.sql) will remove all structures from the DB.


For creating a concise, informative README.md in markdown style that guides users through setting up the finance segment focusing on the schema file, here is a draft:

---

# Finance Setup

This guide provides a step-by-step walkthrough for setting up the finance segment using the TimescaleDB [schema.sql](./schema.sql) file. The file is designed to manage and analyze financial market data effectively.

## Prerequisites

- PostgreSQL installed
- TimescaleDB extension enabled in your PostgreSQL database

## Features

The `schema.sql` file sets up the following features:

* storage of time-series data in a hypertable
* compression settings for efficient storage
* continuous aggregates for Open-High-Low-Close-Volume (OHLCV) data
* utility views for easy access to OHLCV data

### The `schema` Table

Create a new table `schema` to store the time, symbol, price, and volume of trades. This table is defined to handle time-series data efficiently.

```sql
CREATE TABLE IF NOT EXISTS schema (
    time TIMESTAMPTZ NOT NULL,
    symbol TEXT NOT NULL,
    price NUMERIC NOT NULL,
    volume NUMERIC NOT NULL
);
```

### Convert `schema` Table to a Hypertable

Utilize TimescaleDB's functionality to turn the `schema` table into a hypertable for scalable time-series data storage.

```sql
SELECT create_hypertable('schema', by_range('time', INTERVAL '1 day'));
```

### Enable Compression

Configure compression settings for the `schema` table to optimize storage and improve query performance.

```sql
ALTER TABLE schema SET (timescaledb.compress, timescaledb.compress_segmentby = 'symbol', timescaledb.compress_orderby = 'time', timescaledb.compress_chunk_time_interval = '1 week');
```

### Add Compression Policy

Apply a compression policy to automatically compress data older than one week.

```sql
SELECT add_compression_policy('schema', INTERVAL '1 week');
```

### Create Materialized Views for OHLCV Data

Set up materialized views to calculate Open-High-Low-Close-Volume (OHLCV) data at 1-minute, 1-hour, and 1-day intervals using the `candlestick_agg` function.

#### 1-Minute Interval

```sql
CREATE MATERIALIZED VIEW _ohlcv_1m
WITH (timescaledb.continuous, timescaledb.materialized_only=false) AS
SELECT time_bucket('1m', time) AS bucket,
       symbol,
       candlestick_agg(time, price, volume) AS candlestick
FROM schema
GROUP BY 1, 2 WITH NO DATA;
```

#### 1-Hour and 1-Day Intervals

Repeat the process for 1-hour and 1-day intervals by aggregating from the finer granularity views.

```sql
-- 1-Hour Interval
CREATE MATERIALIZED VIEW _ohlcv_1h
WITH (timescaledb.continuous) AS ...

-- 1-Day Interval
CREATE MATERIALIZED VIEW _ohlcv_1d
WITH (timescaledb.continuous) AS ...
```

### Create Views for Easy Access

Generate views on top of the materialized views to simplify access to the calculated OHLCV data.

```sql
CREATE VIEW ohlcv_1m AS ...
CREATE VIEW ohlcv_1h AS ...
CREATE VIEW ohlcv_1d AS ...
```

This views are just wrappers around the materialized views, so you can query them as if they were tables.
Because the candlesschema are stored as a struct and need special functions to access the data,
the views are useful to simplify the access.

Note that candlestick_agg is a custom function that aggregates the data into a single row with the open, high, low, close, and volume. You have functions like `high_at`, `low_at`, `open_at`, `close_at` to access inner time series data that are not included in this view.

### Schedule Continuous Aggregate Policies

Automate the refreshing of continuous aggregates to ensure data is up-to-date.

```sql
SELECT add_continuous_aggregate_policy('_ohlcv_1m', ...);
SELECT add_continuous_aggregate_policy('_ohlcv_1h', ...);
SELECT add_continuous_aggregate_policy('_ohlcv_1d', ...);
```

## Downsampling with LTTB for Large Finance Datasets

LTTB is the Largest Triangle Three Buckets algorithm that downsamples a time series
to a smaller set of points while preserving the visual appearance of the data.
This can be useful for plotting large datasets or reducing the number of points for faster processing.

```sql
SELECT symbol, (lttb(time, price, 10)->unnest()).*
    FROM crypto_ticks
    WHERE
      time > now() - interval '1 hour'
    AND
      symbol = 'BTC/USD'
    GROUP BY 1
    ORDER BY 1 desc;
```

## Downsample with ASAP Smooth for Large Finance Datasets

ASAP (As Smooth As Possible) is a smoothing algorithm that downsamples a time series.
The main difference is that it focuses on preserving the shape of the data rather than
the visual appearance. This can be useful for smoothing out noisy data.

```sql
select symbol, (asap_smooth(time, price, 10)->unnest()).*
    from crypto_ticks
    where
      time > now() - interval '1 hour'
    and
      symbol ~ '^(ETH|BTC)/USD$'
    group by 1
    ORDER BY 1 desc;
```

## Histogram

Histogram allows you to create a histogram of the price data within a given range.
This can be useful for visualizing the distribution of prices within a specific time frame.
This example, we're collecting the daily max and min price and creating a histogram with 8 bins.

```sql
with daily as (
    select
      low(candlestick) as min,
      high(candlestick) as max
    from ohlc_1day
    where
      symbol = 'ETH/USD'
    and
      ts > now() - interval '1 day'
    order by ts desc limit 1
)
select count(*), histogram(price, daily.min, daily.max,8)
from daily, crypto_ticks
WHERE
  symbol = 'ETH/USD'
and
  time > now() - interval '1 day';
```

## Percentile Aggregation

Percentile aggregation allows you to calculate the 25th, 50th, 75th, and 99th
percentiles of the price data within a given time frame.

With the following query, we're calculating the percentiles for the last month of data.

```sql
WITH one_month AS (
  SELECT time_bucket('1 day'::interval, time) AS bucket,
    percentile_agg( price) 
  FROM crypto_ticks 
  WHERE symbol = 'BTC/USD'
    AND time > now() - interval '1 month'
  GROUP BY 1 ORDER BY 1
)
SELECT bucket as x,
  approx_percentile(0.25, percentile_agg) AS y,
  approx_percentile(0.5, percentile_agg) AS y_median,
  approx_percentile(0.75, percentile_agg) AS y_q3,
  approx_percentile(0.99, percentile_agg) AS y_99
FROM one_month;
```

You can also persist the percentile_agg and extract any discrete percentile
distribution later.

## Contribute

If you have any ideas that would be widely useful for other folks on finance,
feel free to contribute to this template by submitting a pull request.

If you have any questions or suggestions, feel free to reach out the
[TimescaleDB community][community] and join our `#discussion-finance-market-data`
channel on [Slack](https://timescaledb.slack.com/).


[community]: https://timescale.com/community

