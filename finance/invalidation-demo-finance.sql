
-- Create a continuous aggregate materialized view for hourly data
\i ticks.sql

DROP MATERIALIZED VIEW ticks_by_day CASCADE;
DROP MATERIALIZED VIEW ticks_by_hour CASCADE;

CREATE MATERIALIZED VIEW ticks_by_hour
WITH (timescaledb.continuous) AS 
SELECT time_bucket('1 hour', time) AS bucket, count(*) as total_hourly
FROM ticks
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


-- Set the client's minimum message level to DEBUG1

-- Insert data into 'ticks' from the last 80 minutes to the present
INSERT INTO ticks VALUES
(now() - interval '80 min', 'SYMBOL', 3.5, 200),
(now() - interval '60 min', 'SYMBOL', 3.56, 200),
(now() - interval '30 min', 'SYMBOL', 3.6, 200),
(now() - interval '10 min', 'SYMBOL', 3.57, 100),
(now(),                     'SYMBOL', 3.0, 100);

SET client_min_messages TO DEBUG1;

-- Refresh the continuous aggregate
CALL refresh_continuous_aggregate('ticks_by_hour', NULL, NULL);

-- Convert the invalidation log's timestamps to human-readable format
SELECT get_hypertable_name(hypertable_id),
       _timescaledb_functions.to_timestamp(lowest_modified_value) as lowest,
       _timescaledb_functions.to_timestamp(greatest_modified_value) as greatest
FROM _timescaledb_catalog.continuous_aggs_hypertable_invalidation_log;

INSERT INTO ticks VALUES
(now() + interval '10 min', 'SYMBOL', 3.5, 200),
(now() + interval '32 min', 'SYMBOL', 3.3, 200),
(now() + interval '61 min', 'SYMBOL', 3.5, 200);

-- Refresh the continuous aggregate 'ticks_by_hour'
CALL refresh_continuous_aggregate('ticks_by_hour', NULL, NULL);


-- Check the time range of the data last two weeks

SELECT min(time), max(time) from ticks 
WHERE time < now() - interval '2 week';

-- Update past 2 days of data

UPDATE ticks SET price = price + 1
WHERE time > now() + interval '30 min';

-- Refresh the continuous aggregate 'ticks_by_hour'

CALL refresh_continuous_aggregate('ticks_by_hour', NULL, NULL);

