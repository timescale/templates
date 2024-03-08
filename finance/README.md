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

* [ticks.sql](./ticks.sql) setup the `ticks` hypertable with compression settings
 and add continuous aggregates and utility view to track `ohlcv_1m` and `ohlcv_1h`.

* [track_last_symbol_price](./track_last_symbol_price.sql) will track `last`
 `last_price` on `symbols` table too.

* [pairs.sql](./pairs.sql) allows you to `track_pairs` of trades and pipe it
    `ticks` back to `ticks` table.

* [cleanup.sql](./cleanup.sql) will remove all structures from the DB.


For creating a concise, informative README.md in markdown style that guides users through setting up the finance segment focusing on the ticks file, here is a draft:

---

# Finance Segment Setup Guide: Ticks File

This guide provides a step-by-step walkthrough for setting up the finance segment using the TimescaleDB ticks file. The file is designed to manage and analyze financial market data effectively.

## Prerequisites

- PostgreSQL installed
- TimescaleDB extension enabled in your PostgreSQL database

## Setup Instructions

### 1. Cleanup Existing Views and Tables

First, ensure that any existing materialized views or tables named `_ohlcv_1d`, `_ohlcv_1h`, `_ohlcv_1m`, or `ticks` are dropped to avoid conflicts.

```sql
DROP MATERIALIZED VIEW IF EXISTS _ohlcv_1d CASCADE;
DROP MATERIALIZED VIEW IF EXISTS _ohlcv_1h CASCADE;
DROP MATERIALIZED VIEW IF EXISTS _ohlcv_1m CASCADE;

DROP TABLE IF EXISTS ticks CASCADE;
```

### 2. Create the `ticks` Table

Create a new table `ticks` to store the time, symbol, price, and volume of trades. This table is defined to handle time-series data efficiently.

```sql
CREATE TABLE IF NOT EXISTS ticks (
    time TIMESTAMPTZ NOT NULL,
    symbol TEXT NOT NULL,
    price NUMERIC NOT NULL,
    volume NUMERIC NOT NULL
);
```

### 3. Convert `ticks` Table to a Hypertable

Utilize TimescaleDB's functionality to turn the `ticks` table into a hypertable for scalable time-series data storage.

```sql
SELECT create_hypertable('ticks', by_range('time', INTERVAL '1 day'));
```

### 4. Enable Compression

Configure compression settings for the `ticks` table to optimize storage and improve query performance.

```sql
ALTER TABLE ticks SET (timescaledb.compress, timescaledb.compress_segmentby = 'symbol', timescaledb.compress_orderby = 'time', timescaledb.compress_chunk_time_interval = '1 week');
```

### 5. Add Compression Policy

Apply a compression policy to automatically compress data older than one week.

```sql
SELECT add_compression_policy('ticks', INTERVAL '1 week');
```

### 6. Create Materialized Views for OHLCV Data

Set up materialized views to calculate Open-High-Low-Close-Volume (OHLCV) data at 1-minute, 1-hour, and 1-day intervals using the `candlestick_agg` function.

#### 1-Minute Interval

```sql
CREATE MATERIALIZED VIEW _ohlcv_1m
WITH (timescaledb.continuous, timescaledb.materialized_only=false) AS
SELECT time_bucket('1m', time) AS bucket,
       symbol,
       candlestick_agg(time, price, volume) AS candlestick
FROM ticks
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

### 7. Create Views for Easy Access

Generate views on top of the materialized views to simplify access to the calculated OHLCV data.

```sql
CREATE VIEW ohlcv_1m AS ...
CREATE VIEW ohlcv_1h AS ...
CREATE VIEW ohlcv_1d AS ...
```

### 8. Schedule Continuous Aggregate Policies

Automate the refreshing of continuous aggregates to ensure data is up-to-date.

```sql
SELECT add_continuous_aggregate_policy('_ohlcv_1m', ...);
SELECT add_continuous_aggregate_policy('_ohlcv_1h', ...);
SELECT add_continuous_aggregate_policy('_ohlcv_1d', ...);
```

### 9. Refresh All Continuous Aggregates

Finally, set up a job to periodically refresh all continuous aggregates.

```sql
SELECT add_job('refresh_all_caggs', '1 sec');
```

## Contribute

Following these steps will set up your finance segment using the TimescaleDB ticks file.

This setup enables efficient handling, compression, and analysis of financial time-series data,
optimizing for performance and scalability.

If you have any questions or suggestions, feel free to reach out the [TimescaleDB community][community].

[community]: https://timescale.com/community

