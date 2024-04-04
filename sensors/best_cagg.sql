drop function if exists select_best_cagg(interval, text);
create or replace function select_best_cagg(
    duration interval,
    hypertable_name TEXT,
    OUT selected_source REGCLASS
) language plpgsql immutable
as $$
declare
    source_name text;
begin
    -- Determine the best continuous aggregate based on the duration
    IF duration <= '1 day'::INTERVAL THEN
        source_name := 'stats_agg_1m_' || hypertable_name;
    ELSIF duration > '1 day'::INTERVAL AND duration <= '1 week'::INTERVAL THEN
        -- Use hourly aggregates for durations greater than 1 day and up to 1 week
        source_name := 'stats_agg_1h_' || hypertable_name;
    ELSIF duration > '1 week'::INTERVAL AND duration <= '6 months'::INTERVAL THEN
        -- Use daily aggregates for durations greater than 1 week and up to 6 months
        source_name := 'stats_agg_1d_' || hypertable_name;
    ELSE
        -- Use monthly aggregates for durations greater than 6 months
        source_name := 'stats_agg_monthly_' || hypertable_name;
    END IF;
    selected_source := source_name::regclass;
end;
$$;

CREATE OR REPLACE FUNCTION query_data_based_on_range(
    start_timestamptz timestamptz,
    end_timestamptz timestamptz,
    hypertable_name TEXT
)
RETURNS SETOF RECORD
LANGUAGE plpgsql IMMUTABLE
AS $$
DECLARE
    selected_source regclass;
    query TEXT;
BEGIN
    -- Determine the best continuous aggregate or the raw hypertable
    SELECT select_best_cagg(end_timestamptz -  start_timestamptz, hypertable_name) INTO selected_source;
    -- Construct the dynamic query string
    query := format('SELECT * FROM %s where time between %L and %L', selected_source, start_timestamptz, end_timestamptz);
    
    -- Return query execution result
    RETURN QUERY EXECUTE query;
END;
$$;

SELECT bucket, device_id, average(stats_agg)
FROM query_data_based_on_range(now() - interval '1 min', now(), 'sample')
AS t(bucket TIMESTAMPTZ, device_id TEXT, stats_agg statssummary1d);
