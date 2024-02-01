DROP TABLE IF EXISTS symbols cascade;
CREATE TABLE symbols (
    symbol TEXT PRIMARY KEY,
    last_price NUMERIC,
    last_price_at TIMESTAMPTZ
);

DROP MATERIALIZED VIEW IF EXISTS ohlcv_1d cascade;
DROP MATERIALIZED VIEW IF EXISTS ohlcv_1h cascade;
DROP MATERIALIZED VIEW IF EXISTS ohlcv_1m cascade;
DROP TABLE IF EXISTS ticks CASCADE;

CREATE TABLE IF NOT EXISTS ticks (
    time TIMESTAMPTZ NOT NULL,
    symbol TEXT NOT NULL REFERENCES symbols(symbol),
    price NUMERIC,
    volume NUMERIC
);

SELECT create_hypertable('ticks', by_range('time', INTERVAL '1 day'), if_not_exists => true);

CREATE OR REPLACE FUNCTION update_last_price()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE symbols
    SET last_price = NEW.price,
    last_price_at = NEW.time
    WHERE symbol = NEW.symbol;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER update_last_price_trigger
AFTER INSERT ON ticks
FOR EACH ROW EXECUTE FUNCTION update_last_price();


--enable compression
ALTER TABLE ticks SET (timescaledb.compress,
    timescaledb.compress_segmentby = 'symbol',
    timescaledb.compress_orderby = 'time',
    timescaledb.compress_chunk_time_interval = '1 week');

-- add compression
SELECT add_compression_policy('ticks ', INTERVAL '1 week');


CREATE MATERIALIZED VIEW ohlcv_1m
WITH (timescaledb.continuous) AS
SELECT time_bucket('1m', time) AS bucket,
       symbol,
       candlestick_agg(time, price, volume) AS candlestick
FROM ticks
GROUP BY 1, 2 WITH NO DATA;

CREATE MATERIALIZED VIEW ohlcv_1h
WITH (timescaledb.continuous) AS
SELECT time_bucket('1h', bucket) AS bucket,
       symbol,
       rollup(candlestick) as candlestick
FROM ohlcv_1m
GROUP BY 1, 2 WITH NO DATA;

CREATE MATERIALIZED VIEW ohlcv_1d
WITH (timescaledb.continuous) AS
SELECT time_bucket('1d', bucket) AS bucket,
       symbol,
       rollup(candlestick) as candlestick
FROM ohlcv_1h
GROUP BY 1, 2 WITH NO DATA;

CREATE OR REPLACE PROCEDURE refresh_all_caggs(job_id int, config jsonb)
LANGUAGE PLPGSQL AS $$
BEGIN
  CALL refresh_continuous_aggregate('ohlcv_1m', NULL, NULL);
  COMMIT;
  CALL refresh_continuous_aggregate('ohlcv_1h', NULL, NULL);
  COMMIT;
  CALL refresh_continuous_aggregate('ohlcv_1d', NULL, NULL);
  COMMIT;
END;
$$;

SELECT add_job('refresh_all_caggs', '5 sec');

