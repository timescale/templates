--enable compression

ALTER TABLE :hypertable SET (timescaledb.compress,
    timescaledb.compress_segmentby = :segment_name,
    timescaledb.compress_orderby = 'time',
    timescaledb.compress_chunk_time_interval = :chunk_time_interval);

SELECT add_compression_policy(:hypertable_name, INTERVAL :chunk_time_interval);


