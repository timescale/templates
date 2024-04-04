
-- Create a continuous aggregate materialized view for hourly data
\i sensors.sql

DROP MATERIALIZED VIEW sample_by_day CASCADE;
DROP MATERIALIZED VIEW sample_by_hour CASCADE;

CREATE MATERIALIZED VIEW sample_by_hour
WITH (timescaledb.continuous) AS
SELECT time_bucket('1 hour', time) AS bucket,
count(*) as total_hourly
FROM sample
GROUP BY 1 WITH NO DATA;

-- Function to get hypertable_id by name

CREATE OR REPLACE FUNCTION get_hypertable_id(hypertable_name VARCHAR)
RETURNS INTEGER AS $$
DECLARE
    hypertable_id INT;
BEGIN
    SELECT id INTO hypertable_id
    FROM _timescaledb_catalog.hypertable
    WHERE table_name = hypertable_name;

    RETURN hypertable_id;
END;
$$ LANGUAGE plpgsql;

-- Function to get hypertable_name by id
CREATE OR REPLACE FUNCTION get_hypertable_name(hypertable_id INTEGER)
RETURNS VARCHAR AS $$
DECLARE
    hypertable_name VARCHAR;
BEGIN
    SELECT table_name INTO hypertable_name
    FROM _timescaledb_catalog.hypertable
    WHERE id = hypertable_id;

    RETURN hypertable_name;
END;
$$ LANGUAGE plpgsql;


INSERT INTO sample VALUES
(now() - interval '80 min', 'room:temperature', 22.2),
(now() - interval '60 min', 'room:temperature', 22.1),
(now() - interval '30 min', 'room:temperature', 22.0),
(now() - interval '10 min', 'room:temperature', 21.9),
(now(),                     'room:temperature', 21.8);

-- Set the client's minimum message level to DEBUG1
SET client_min_messages TO DEBUG1;

-- Refresh the continuous aggregate
CALL refresh_continuous_aggregate('sample_by_hour', NULL, NULL);

-- Convert the invalidation log's timestamps to human-readable format
SELECT get_hypertable_name(hypertable_id),
       _timescaledb_functions.to_timestamp(lowest_modified_value) as lowest,
       _timescaledb_functions.to_timestamp(greatest_modified_value) as greatest
FROM _timescaledb_catalog.continuous_aggs_hypertable_invalidation_log;

INSERT INTO sample VALUES
(now() + interval '10 min', 'room:temperature', 21.7),
(now() + interval '32 min', 'room:temperature', 21.6),
(now() + interval '61 min', 'room:temperature', 21.5);

-- Refresh the continuous aggregate 'sample_by_hour'
CALL refresh_continuous_aggregate('sample_by_hour', NULL, NULL);


-- Check the time range of the data last two weeks

SELECT min(time), max(time) from sample 
WHERE time < now() - interval '2 week';

-- Update past half hour

UPDATE sample SET value = value + 1
WHERE time between now() - interval '30 min' and now();

-- Refresh the continuous aggregate 'sample_by_hour'

CALL refresh_continuous_aggregate('sample_by_hour', NULL, NULL);

