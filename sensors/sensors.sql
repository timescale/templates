-- Description: Create a table to store sensor data and enable compression
-- Configure hypertable name as a psql settings

\set hypertable events
\set hypertable_name '''events'''
\set chunk_time_interval '''1 week'''
\set segment origin
\set segment_name '''origin'''

DROP TABLE IF EXISTS :hypertable CASCADE;

CREATE TABLE IF NOT EXISTS :hypertable (
    time TIMESTAMPTZ NOT NULL,
    :segment TEXT NOT NULL,
    payload jsonb NOT NULL
);

SELECT create_hypertable(:hypertable_name,
  by_range('time', INTERVAL :chunk_time_interval));


insert into :hypertable (time, :segment, payload)
values (now(), 'sensor_1', '{"temperature": 20.0, "humidity": 94.5}');

