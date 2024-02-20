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

