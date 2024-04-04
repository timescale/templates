CREATE SCHEMA IF NOT EXISTS :schema_name;

set search_path to :schema_name, public;

CREATE TABLE IF NOT EXISTS :hypertable (
    time TIMESTAMPTZ NOT NULL,
    :segment TEXT NOT NULL,
    :payload_name :payload_type NOT NULL
);

SELECT create_hypertable(:hypertable_name,
  by_range('time', INTERVAL :chunk_time_interval));

