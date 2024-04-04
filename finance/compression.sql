
--enable compression

ALTER TABLE ticks SET (timescaledb.compress,
    timescaledb.compress_segmentby = 'symbol',
    timescaledb.compress_orderby = 'time',
    timescaledb.compress_chunk_time_interval = '1 week');

-- add compression
SELECT add_compression_policy('ticks ', INTERVAL '1 week');
