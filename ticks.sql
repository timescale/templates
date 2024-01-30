DROP TABLE IF EXISTS symbols cascade;
CREATE TABLE symbols (
    symbol TEXT PRIMARY KEY,
    last_price NUMERIC,
    last_price_at TIMESTAMPTZ
);

CREATE TABLE ticks (
    time TIMESTAMPTZ NOT NULL,
    symbol TEXT NOT NULL REFERENCES symbols(symbol),
    price NUMERIC,
    volume NUMERIC
);

SELECT create_hypertable('ticks', by_range('time', INTERVAL '1 day'));

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
GROUP BY 1, 2;

CREATE MATERIALIZED VIEW ohlcv_1h
WITH (timescaledb.continuous) AS
SELECT time_bucket('1h', bucket) AS bucket,
       symbol,
       rollup(candlestick) as candlestick
FROM ohlcv_1m
GROUP BY 1, 2;
