-- Setup Traffic Patterns for Top Websites Tracker
-- This script sets up different traffic patterns for testing

-- First, let's make sure we have the necessary functions
\i data-generation.sql
\i schedule_traffic_patterns.sql

-- Function to check if traffic patterns are already running
CREATE OR REPLACE FUNCTION check_traffic_patterns_running() 
RETURNS BOOLEAN AS $$
DECLARE
    pattern_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO pattern_count
    FROM timescaledb_information.jobs j
    WHERE j.proc_name = 'generate_log_data_job'
    AND j.config::text LIKE '%traffic.com%';
    
    RETURN pattern_count > 0;
END;
$$ LANGUAGE plpgsql;

-- Function to stop existing traffic patterns
CREATE OR REPLACE FUNCTION stop_traffic_patterns() 
RETURNS INTEGER AS $$
DECLARE
    job_id INTEGER;
    stopped_count INTEGER := 0;
BEGIN
    -- Stop all traffic pattern jobs
    FOR job_id IN (
        SELECT j.job_id 
        FROM timescaledb_information.jobs j
        WHERE j.proc_name = 'generate_log_data_job'
        OR j.proc_name = 'populate_website_candidates_job'
        OR j.proc_name = 'elect_top_websites'
    )
    LOOP
        PERFORM delete_job(job_id);
        stopped_count := stopped_count + 1;
    END LOOP;
    
    RETURN stopped_count;
END;
$$ LANGUAGE plpgsql;

-- Main execution
DO $$
DECLARE
    patterns_running BOOLEAN;
    stopped_count INTEGER;
    job_record RECORD;
BEGIN
    -- Check if patterns are already running
    patterns_running := check_traffic_patterns_running();
    
    IF patterns_running THEN
        RAISE NOTICE 'Traffic patterns are already running. Stopping existing patterns...';
        stopped_count := stop_traffic_patterns();
        RAISE NOTICE 'Stopped % existing traffic pattern jobs', stopped_count;
    END IF;
    
    -- Schedule new traffic patterns
    RAISE NOTICE 'Scheduling new traffic patterns...';
    PERFORM schedule_traffic_patterns();
    
    -- Verify the patterns are running
    SELECT COUNT(*) INTO stopped_count
    FROM timescaledb_information.jobs j
    WHERE j.proc_name = 'generate_log_data_job'
    AND j.config::text LIKE '%traffic.com%';
    
    RAISE NOTICE 'Successfully scheduled % traffic pattern jobs', stopped_count;
    
    -- Show the current traffic patterns
    RAISE NOTICE 'Current traffic patterns:';
    FOR job_record IN
        SELECT j.job_id, j.schedule_interval, j.config
        FROM timescaledb_information.jobs j
        WHERE j.proc_name = 'generate_log_data_job'
        AND j.config::text LIKE '%traffic.com%'
        ORDER BY j.job_id
    LOOP
        RAISE NOTICE 'Job ID: %, Interval: %, Config: %', 
            job_record.job_id, job_record.schedule_interval, job_record.config;
    END LOOP;
END;
$$; 