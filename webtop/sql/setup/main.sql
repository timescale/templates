-- WebTop - Main Setup Script
-- This script runs all the components in the proper order

-- Step 1: Clean up any existing jobs
\echo 'Cleaning up existing jobs...'
SELECT cleanup_all_jobs();

-- Step 2: Run the basic pipeline script to create tables and initial data
\echo 'Running main pipeline script...'
\i pipeline.sql

-- Step 3: Load data generation functions
\echo 'Loading data generation functions...'
\i data-generation.sql

-- Step 4: Load traffic pattern functions
\echo 'Loading traffic pattern functions...'
\i setup_traffic_patterns.sql
\i schedule_traffic_patterns.sql

-- Step 5: Create the generate_log_entry function
\echo 'Creating generate_log_entry function...'
CREATE OR REPLACE FUNCTION generate_log_entry(domain_name text, pattern text) 
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    config jsonb;
    amount INTEGER;
BEGIN
    -- Set amount based on pattern
    CASE pattern
        WHEN 'steady' THEN amount := 100;
        WHEN 'bursty' THEN amount := 200;
        WHEN 'growing' THEN amount := 50;
        WHEN 'declining' THEN amount := 150;
        ELSE amount := 100;
    END CASE;
    
    -- Create config based on pattern
    config := jsonb_build_object(
        'use_specific_domain', true,
        'domain', domain_name,
        'amount', amount
    );
    
    -- Add pattern-specific parameters
    CASE pattern
        WHEN 'bursty' THEN
            config := jsonb_set(config, '{burst_probability}', '0.4');
            config := jsonb_set(config, '{burst_multiplier}', '10');
        WHEN 'growing' THEN
            config := jsonb_set(config, '{growth_rate}', '10');
        WHEN 'declining' THEN
            config := jsonb_set(config, '{growth_rate}', '-5');
        ELSE
            NULL;
    END CASE;
    
    -- Call the log data generation job
    CALL generate_log_data_job(0, config);
    
    RAISE NOTICE 'Generated log entry for % with % pattern', domain_name, pattern;
END;
$$;

-- Step 6: Generate initial test data
\echo 'Generating initial test data...'
SELECT generate_log_entry('google.com', 'steady');
SELECT generate_log_entry('facebook.com', 'bursty');
SELECT generate_log_entry('youtube.com', 'growing');
SELECT generate_log_entry('twitter.com', 'steady');
SELECT generate_log_entry('instagram.com', 'bursty');

-- Step 7: Start data generation jobs
\echo 'Starting data generation jobs...'
-- Schedule traffic pattern generation
SELECT schedule_traffic_patterns();

-- Step 8: Start election process jobs
\echo 'Starting election process jobs...'
SELECT schedule_website_tracking_jobs();

-- Step 9: Force initial refresh of continuous aggregates
\echo 'Refreshing continuous aggregates...'
CALL refresh_continuous_aggregate('domain_stats_10m', NULL, NULL);
CALL refresh_continuous_aggregate('domain_stats_1d', NULL, NULL);
CALL refresh_continuous_aggregate('domain_traffic_stats_1h', NULL, NULL);

-- Step 10: Final check of tables and jobs
\echo 'Setup complete. Checking final state...'
SELECT 'Domain count:' AS check, COUNT(*) FROM top_websites_longterm;
SELECT 'Job status:' AS check;
SELECT job_id, proc_name, schedule_interval, next_start
FROM timescaledb_information.jobs
WHERE proc_name IN ('populate_website_candidates_job', 'elect_top_websites', 'generate_log_data_job');

\x
-- Check election system tables
SELECT * FROM top_websites_longterm LIMIT 1;
SELECT * FROM top_websites_report LIMIT 1;
