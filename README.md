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

* [ ] Add background job to emulate ticks.
* [ ] Add hooks to allow to subscribe to candlesticks `on_new_candlestick`.
* [ ] Add convenience views to fetch ohlcv from candlestick_aggs.
* [ ] Add functions covering basic finance indicators like bollinger bands.
* [ ] Convert the repository to a plain postgresql extension.


## Files

You can check the [main.sql](./main.sql) file which simply load all files in the
order:

* [ticks.sql](./ticks.sql) setup the `ticks` hypertable with compression settings
 and add continuous aggregates to track `ohlcv_1m` and `ohlcv_1h`. Track
 `last_price` on `symbols` table too.
* [pairs.sql](./pairs.sql) allows you to `track_pairs` of trades and pipe it
    `ticks` back to `ticks` table.
* [pairs_test.sql](./pairs_test.sql) is an example feeding data.
* [cleanup.sql](./cleanup.sql) will remove all structures from the DB.


