# TimescaleDB Finance

Welcome to my new repository. This is a work in progress to setup defaults of
Timescaledb for processing finance data.

##  Objectives

* [x] Create ticks hypertable with chunk time interval of 1 day.
* [x] Tracks `last_price` and `last_price_at` on `symbols` table which updates
    every new tick.
* [x] Add a compression policy to compress chunks after 1 week.
* [x] Create hierarchical continuous aggregates with candlesticks of 1m and 1h.
* [x] Track pairs of symbols and generate new ticks correlating their last
    prices.
* [x] Automated example testing the schema and functions.
* [x] Add background job to emulate ticks.
* [x] Add convenience views to fetch ohlcv from candlestick_aggs.

## Files

You can check the [main.sql](./main.sql) file which simply load all files in the
order:

* [ticks.sql](./ticks.sql) setup the `ticks` hypertable with compression settings
 and add continuous aggregates and utility view to track `ohlcv_1m` and `ohlcv_1h`.
 Check more on [ticks][#Ticks].
* [track_last_symbol_price](./track_last_symbol_price.sql) will track `last`
 `last_price` on `symbols` table too.
* [pairs.sql](./pairs.sql) allows you to `track_pairs` of trades and pipe it
    `ticks` back to `ticks` table.
* [cleanup.sql](./cleanup.sql) will remove all structures from the DB.


