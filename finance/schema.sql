CREATE SCHEMA IF NOT EXISTS finance;

SET search_path to finance, public;

CREATE TABLE IF NOT EXISTS ticks (
    time TIMESTAMPTZ NOT NULL,
    symbol TEXT NOT NULL,
    price NUMERIC NOT NULL,
    volume NUMERIC NOT NULL
);

SELECT create_hypertable('ticks',
  by_range('time', INTERVAL '1 day'));


