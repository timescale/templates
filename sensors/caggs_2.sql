
-- continuous aggregates for stats_agg of the value
\set value_expr ':payload_name'
-- Define a custom function to create continuous aggregates
DO $$
DECLARE
    hypertable_name TEXT := 'sample';
    segment_column TEXT := 'device_id';
    value_column TEXT := 'value';
    periods TEXT[] := ARRAY['1 minute', '1 hour', '1 day', '1 month'];
    period_suffixes TEXT[] := ARRAY['1m', '1h', '1d', 'monthly'];
    prev_cagg_name TEXT := NULL;
    cagg_name TEXT;
    i INT;
BEGIN
    -- Loop through each period to create continuous aggregates
    FOR i IN 1..array_length(periods, 1) LOOP
        cagg_name := 'stats_agg_' || period_suffixes[i] || '_' || hypertable_name;
        IF i = 1 THEN
            -- Create the initial continuous aggregate without rollup, directly from the hypertable
            EXECUTE format($f$
                CREATE MATERIALIZED VIEW %I
                WITH (timescaledb.continuous, timescaledb.materialized_only=false) AS
                SELECT time_bucket('%s', time) AS bucket,
                       %I,
                       stats_agg(%I) AS stats_agg
                FROM %I
                GROUP BY 1, 2
                WITH NO DATA;$f$, cagg_name, periods[i], segment_column, value_column, hypertable_name);
        ELSE
            EXECUTE format($f$
                CREATE MATERIALIZED VIEW %I
                WITH (timescaledb.continuous, timescaledb.materialized_only=false) AS
                SELECT time_bucket('%s', bucket) AS bucket,
                       %I,
                       rollup(stats_agg) AS stats_agg
                FROM %I
                GROUP BY 1, 2
                WITH NO DATA;
            $f$, cagg_name, periods[i], segment_column, prev_cagg_name);
        END IF;
        -- Update prev_cagg_name to reference the current continuous aggregate in the next iteration
        prev_cagg_name := cagg_name;
        
        -- Optional: Output the name of the created continuous aggregate for verification
        RAISE NOTICE 'Created continuous aggregate: %', cagg_name;
    END LOOP;
END $$ LANGUAGE plpgsql;

call refresh_continuous_aggregate('stats_agg_1m_sample', null, null);
call refresh_continuous_aggregate('stats_agg_1h_sample', null, null);
call refresh_continuous_aggregate('stats_agg_1d_sample', null, null);
call refresh_continuous_aggregate('stats_agg_monthly_sample', null, null);

SELECT add_continuous_aggregate_policy('stats_agg_1m_sample',
    start_offset => INTERVAL '5 min',
    end_offset => INTERVAL '1 min',
    schedule_interval => INTERVAL '1 min');

SELECT add_continuous_aggregate_policy('stats_agg_1h_sample',
    start_offset => INTERVAL '3 hours',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '5s');

SELECT add_continuous_aggregate_policy('stats_agg_1d_sample',
    start_offset => INTERVAL '3 days',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '5s');

SELECT add_continuous_aggregate_policy('stats_agg_monthly_sample',
    start_offset => INTERVAL '3 months',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '5s');

