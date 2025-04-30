-- Function to schedule traffic patterns
CREATE OR REPLACE FUNCTION schedule_traffic_patterns() RETURNS void AS $$
DECLARE
    job_id INTEGER;
BEGIN
    -- Bursty traffic pattern (base 1000 requests with 40% chance of 10x bursts)
    SELECT add_job('generate_log_data_job', '1 minute',
        jsonb_build_object(
            'amount', 1000,
            'domain', 'bursty-traffic.com',
            'use_specific_domain', true,
            'growth_rate', 0,
            'burst_probability', 0.4,  -- 40% chance of burst
            'burst_multiplier', 10    -- 10x traffic during bursts
        )
    ) INTO job_id;
    RAISE NOTICE 'Scheduled bursty traffic pattern with job_id=%', job_id;

    -- Steady traffic pattern (constant 500 requests per minute)
    SELECT add_job('generate_log_data_job', '1 minute',
        jsonb_build_object(
            'amount', 500,
            'domain', 'steady-traffic.com',
            'use_specific_domain', true,
            'growth_rate', 0,
            'burst_probability', 0,
            'burst_multiplier', 1
        )
    ) INTO job_id;
    RAISE NOTICE 'Scheduled steady traffic pattern with job_id=%', job_id;

    -- Growing traffic pattern (starts at 100, grows by 10 per minute)
    SELECT add_job('generate_log_data_job', '1 minute',
        jsonb_build_object(
            'amount', 100,
            'domain', 'growing-traffic.com',
            'use_specific_domain', true,
            'growth_rate', 10,
            'burst_probability', 0,
            'burst_multiplier', 1
        )
    ) INTO job_id;
    RAISE NOTICE 'Scheduled growing traffic pattern with job_id=%', job_id;
END;
$$ LANGUAGE plpgsql;

-- Function to monitor traffic patterns
CREATE OR REPLACE FUNCTION monitor_traffic_patterns() RETURNS TABLE (
    domain TEXT,
    total_requests BIGINT,
    avg_requests_per_minute NUMERIC,
    current_traffic_level TEXT,
    trend TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH recent_traffic AS (
        SELECT 
            l.domain,
            COUNT(*) as total_requests,
            COUNT(*)::NUMERIC / 
                EXTRACT(EPOCH FROM (now() - MIN(time))) * 60 as avg_requests_per_minute,
            COUNT(*) FILTER (WHERE time > now() - interval '5 minutes')::NUMERIC /
                COUNT(*) FILTER (WHERE time > now() - interval '10 minutes') as recent_ratio
        FROM logs l
        WHERE time > now() - interval '1 hour'
        GROUP BY l.domain
    )
    SELECT 
        rt.domain,
        rt.total_requests,
        ROUND(rt.avg_requests_per_minute, 2),
        CASE 
            WHEN rt.avg_requests_per_minute > 1500 THEN 'High'
            WHEN rt.avg_requests_per_minute > 500 THEN 'Medium'
            ELSE 'Low'
        END as current_traffic_level,
        CASE 
            WHEN rt.recent_ratio > 1.1 THEN 'Growing'
            WHEN rt.recent_ratio < 0.9 THEN 'Declining'
            ELSE 'Stable'
        END as trend
    FROM recent_traffic rt
    WHERE rt.domain LIKE '%-traffic.com'
    ORDER BY rt.total_requests DESC;
END;
$$ LANGUAGE plpgsql;

-- Execute the scheduling
SELECT schedule_traffic_patterns();

-- Create a view for easy monitoring
DROP VIEW IF EXISTS traffic_patterns_monitor;
CREATE OR REPLACE VIEW traffic_patterns_monitor AS
SELECT * FROM monitor_traffic_patterns(); 