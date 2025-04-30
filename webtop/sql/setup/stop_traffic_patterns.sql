-- Stop Traffic Patterns for Top Websites Tracker
-- This script stops all traffic pattern jobs

-- Function to stop traffic patterns
CREATE OR REPLACE FUNCTION stop_traffic_patterns() 
RETURNS INTEGER AS $$
DECLARE
    job_id INTEGER;
    stopped_count INTEGER := 0;
BEGIN
    FOR job_id IN (
        SELECT j.job_id 
        FROM timescaledb_information.jobs j
        WHERE j.proc_name = 'generate_log_data_job'
        AND j.config::text LIKE '%traffic.com%'
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
    stopped_count INTEGER;
BEGIN
    -- Stop traffic patterns
    RAISE NOTICE 'Stopping traffic patterns...';
    stopped_count := stop_traffic_patterns();
    
    IF stopped_count > 0 THEN
        RAISE NOTICE 'Successfully stopped % traffic pattern jobs', stopped_count;
    ELSE
        RAISE NOTICE 'No traffic pattern jobs were running';
    END IF;
END;
$$; 