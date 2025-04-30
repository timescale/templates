-- Script to generate various traffic patterns for testing
-- This will help test how the system handles different scenarios

-- Initial burst of traffic
SELECT generate_log_data('openai.com', 1000);
SELECT generate_log_data('claude.ai', 800);

-- Function to generate different traffic patterns
CREATE OR REPLACE FUNCTION schedule_traffic_patterns() 
RETURNS int[] LANGUAGE plpgsql AS $$
DECLARE
    job_ids int[] := '{}';
    job_id int;
    amount int;
BEGIN
    -- Cancel any existing traffic generation jobs
    FOR job_id IN (
        SELECT j.job_id 
        FROM timescaledb_information.jobs j
        WHERE j.proc_name = 'generate_log_data_job'
        AND (j.config::text LIKE '%openai.com%' 
             OR j.config::text LIKE '%claude.ai%'
             OR j.config::text LIKE '%anthropic.com%'
             OR j.config::text LIKE '%perplexity.ai%')
    )
    LOOP
        PERFORM delete_job(job_id);
        RAISE NOTICE 'Deleted existing traffic job %', job_id;
    END LOOP;
    
    -- Scenario 1: Steady high traffic (openai.com)
    -- 300-500 hits every 5 seconds
    amount := 300 + (random() * 200)::integer;
    SELECT add_job(
        'generate_log_data_job', 
        INTERVAL '5 seconds', 
        config => jsonb_build_object(
            'use_specific_domain', true,
            'domain', 'openai.com',
            'amount', amount
        )
    ) INTO job_id;
    job_ids := array_append(job_ids, job_id);
    RAISE NOTICE 'Scheduled steady high traffic for openai.com with job_id=%', job_id;
    
    -- Scenario 2: Bursty traffic (claude.ai)
    -- 800-1000 hits every 30 seconds
    amount := 800 + (random() * 200)::integer;
    SELECT add_job(
        'generate_log_data_job', 
        INTERVAL '30 seconds', 
        config => jsonb_build_object(
            'use_specific_domain', true,
            'domain', 'claude.ai',
            'amount', amount
        )
    ) INTO job_id;
    job_ids := array_append(job_ids, job_id);
    RAISE NOTICE 'Scheduled bursty traffic for claude.ai with job_id=%', job_id;
    
    -- Scenario 3: Growing traffic (anthropic.com)
    -- Starts with 100 hits, increases by 50 every minute
    SELECT add_job(
        'generate_log_data_job', 
        INTERVAL '1 minute', 
        config => jsonb_build_object(
            'use_specific_domain', true,
            'domain', 'anthropic.com',
            'amount', 100,
            'growth_rate', 50
        )
    ) INTO job_id;
    job_ids := array_append(job_ids, job_id);
    RAISE NOTICE 'Scheduled growing traffic for anthropic.com with job_id=%', job_id;
    
    -- Scenario 4: Declining traffic (perplexity.ai)
    -- Starts with 500 hits, decreases by 20 every minute
    SELECT add_job(
        'generate_log_data_job', 
        INTERVAL '1 minute', 
        config => jsonb_build_object(
            'use_specific_domain', true,
            'domain', 'perplexity.ai',
            'amount', 500,
            'growth_rate', -20
        )
    ) INTO job_id;
    job_ids := array_append(job_ids, job_id);
    RAISE NOTICE 'Scheduled declining traffic for perplexity.ai with job_id=%', job_id;
    
    RETURN job_ids;
END;
$$;

-- Function to monitor traffic patterns
CREATE OR REPLACE FUNCTION monitor_traffic_patterns() 
RETURNS TABLE (
    domain text,
    total_hits bigint,
    recent_hits bigint,
    hit_trend text,
    last_updated timestamp with time zone
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    WITH recent_stats AS (
        SELECT 
            d.domain,
            SUM(d.total)::bigint as recent_hits
        FROM domain_stats_10m d
        WHERE d.bucket > now() - interval '1 hour'
        GROUP BY d.domain
    ),
    previous_stats AS (
        SELECT 
            d.domain,
            SUM(d.total)::bigint as previous_hits
        FROM domain_stats_10m d
        WHERE d.bucket > now() - interval '2 hours'
          AND d.bucket <= now() - interval '1 hour'
        GROUP BY d.domain
    )
    SELECT 
        r.domain,
        COALESCE((SELECT t.total_hits FROM top_websites_longterm t WHERE t.domain = r.domain), 0::bigint) as total_hits,
        r.recent_hits,
        CASE 
            WHEN r.recent_hits > p.previous_hits * 1.2 THEN 'Growing'
            WHEN r.recent_hits < p.previous_hits * 0.8 THEN 'Declining'
            ELSE 'Stable'
        END as hit_trend,
        now() as last_updated
    FROM recent_stats r
    LEFT JOIN previous_stats p ON r.domain = p.domain
    WHERE r.domain IN ('openai.com', 'claude.ai', 'anthropic.com', 'perplexity.ai')
    ORDER BY r.recent_hits DESC;
END;
$$;

-- Start the traffic patterns
SELECT schedule_traffic_patterns();

-- Initial traffic pattern report
SELECT * FROM monitor_traffic_patterns();

