-- Reset script for Top Websites Tracker
-- This removes all existing data and schedules, but keeps the structure for real packet tracking

-- Function to clean up all jobs
CREATE OR REPLACE FUNCTION cleanup_all_jobs()
RETURNS void AS $$
BEGIN
    -- Delete all existing jobs
    PERFORM delete_job(job_id)
    FROM timescaledb_information.jobs
    WHERE proc_name IN (
        'generate_log_data_job',
        'elect_top_websites',
        'populate_website_candidates_job'
    );
END;
$$ LANGUAGE plpgsql;

-- Clean up all jobs
SELECT cleanup_all_jobs();

-- Clean up all data
TRUNCATE logs;
TRUNCATE top_websites_candidates;
TRUNCATE top_websites_longterm;

-- Refresh continuous aggregates
CALL refresh_continuous_aggregate('domain_stats_10m', NULL, NULL);
CALL refresh_continuous_aggregate('domain_stats_1d', NULL, NULL);
CALL refresh_continuous_aggregate('domain_traffic_stats_1h', NULL, NULL);

-- Show current jobs
SELECT job_id, proc_name, schedule_interval, next_start
FROM timescaledb_information.jobs
WHERE proc_name IN ('populate_website_candidates_job', 'elect_top_websites');

-- Set minimum hits threshold lower to detect real traffic patterns more easily
UPDATE top_websites_config SET min_hits_threshold = 5 WHERE id = 1;

-- Schedule only the jobs needed for real data processing (no data generation)
SELECT schedule_website_tracking_jobs();

-- Show new configuration
SELECT * FROM top_websites_config;

SELECT 'System has been reset. Ready to track real DNS traffic.' AS message; 