-- Description: Create a table to store sensor data and enable compression
-- Configure hypertable name as a psql settings

\set hypertable sample
\set hypertable_name '''sample'''
\set chunk_time_interval '''1 week'''
\set segment device_id
\set segment_name '''device_id'''
\set payload_type 'double precision'
\set payload_name value
\set sample_segment '''room_a:temperature'''
\set sample_payload 20.0

DROP materialized view if exists stats_agg_1M_sample CASCADE;
DROP materialized view if exists stats_agg_1d_sample CASCADE;
DROP materialized view if exists stats_agg_1h_sample CASCADE;
DROP materialized view if exists stats_agg_1m_sample CASCADE;
DROP TABLE IF EXISTS :hypertable CASCADE;

CREATE TABLE IF NOT EXISTS :hypertable (
    time TIMESTAMPTZ NOT NULL,
    :segment TEXT NOT NULL,
    :payload_name :payload_type NOT NULL
);

SELECT create_hypertable(:hypertable_name,
  by_range('time', INTERVAL :chunk_time_interval));

INSERT INTO :hypertable (time, :segment, :payload_name)
VALUES (now(), :sample_segment, :sample_payload);


