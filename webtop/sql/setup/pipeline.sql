-- Pipeline to track top websites
-- Drop all existing objects
DROP TABLE IF EXISTS logs CASCADE;
DROP MATERIALIZED VIEW IF EXISTS domain_stats_10m CASCADE;
DROP MATERIALIZED VIEW IF EXISTS domain_stats_1d CASCADE;
DROP MATERIALIZED VIEW IF EXISTS domain_traffic_stats_1h CASCADE;
DROP TABLE IF EXISTS top_websites_config CASCADE;
DROP TABLE IF EXISTS top_websites_longterm CASCADE;
DROP TABLE IF EXISTS top_websites_candidates CASCADE;
DROP VIEW IF EXISTS top_websites_report CASCADE;
DROP VIEW IF EXISTS traffic_patterns_monitor CASCADE;
DROP VIEW IF EXISTS domain_traffic_stats CASCADE;

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS timescaledb;
CREATE EXTENSION IF NOT EXISTS timescaledb_toolkit;

-- Create base table
CREATE TABLE IF NOT EXISTS "logs" (
    "time" timestamp with time zone NOT NULL,
    "domain" text NOT NULL
);

-- Create hypertable with 20-minute chunks
SELECT create_hypertable('logs', 'time', 
    chunk_time_interval => INTERVAL '20 minutes',
    if_not_exists => TRUE
);

-- Add retention policy to keep only last hour of logs
SELECT add_retention_policy('logs', INTERVAL '1 hour');

-- Create hierarchical continuous aggregates
-- 1. 10-minute aggregation (base level)
CREATE MATERIALIZED VIEW domain_stats_10m
WITH (timescaledb.continuous, timescaledb.materialized_only=false) AS
    SELECT 
        time_bucket('10 minutes', time) as bucket,
        domain,
        count(*) as total
    FROM logs
    GROUP BY 1,2
WITH NO DATA;

-- 2. 1-day aggregation (directly from logs)
CREATE MATERIALIZED VIEW domain_stats_1d
WITH (timescaledb.continuous, timescaledb.materialized_only=false) AS
    SELECT 
        time_bucket('1 day', time) as bucket,
        domain,
        count(*) as total
    FROM logs
    GROUP BY 1,2
WITH NO DATA;

-- 3. 1-hour aggregation with advanced statistics
CREATE MATERIALIZED VIEW domain_traffic_stats_1h
WITH (timescaledb.continuous, timescaledb.materialized_only=false) AS
    SELECT 
        time_bucket('1 hour', time) as bucket,
        domain,
        count(*) as total
    FROM logs
    GROUP BY 1,2
WITH NO DATA;

-- Set refresh policies for each level
-- 10-minute level: refresh every 1 minute, keep last 7 days
SELECT add_continuous_aggregate_policy('domain_stats_10m',
    start_offset => INTERVAL '7 days',
    end_offset => INTERVAL '1 minute',
    schedule_interval => INTERVAL '1 minute');

-- 1-day level: refresh every 5 minutes, keep last 90 days
SELECT add_continuous_aggregate_policy('domain_stats_1d',
    start_offset => INTERVAL '90 days',
    end_offset => INTERVAL '5 minutes',
    schedule_interval => INTERVAL '5 minutes');

-- 1-hour level: refresh every 1 minute, keep last 7 days
SELECT add_continuous_aggregate_policy('domain_traffic_stats_1h',
    start_offset => INTERVAL '7 days',
    end_offset => INTERVAL '1 minute',
    schedule_interval => INTERVAL '1 minute');

-- Initial refresh of all aggregates
CALL refresh_continuous_aggregate('domain_stats_10m', NULL, NULL);
CALL refresh_continuous_aggregate('domain_stats_1d', NULL, NULL);
CALL refresh_continuous_aggregate('domain_traffic_stats_1h', NULL, NULL);

-- Configuration table for top websites tracking
CREATE TABLE IF NOT EXISTS "top_websites_config" (
    "id" serial PRIMARY KEY,
    "min_hits_threshold" integer NOT NULL DEFAULT 100,
    "election_window" interval NOT NULL DEFAULT '24 hours',
    "longterm_retention_period" interval NOT NULL DEFAULT '90 days',
    "candidates_retention_period" interval NOT NULL DEFAULT '7 days',
    "max_longterm_entries" integer NOT NULL DEFAULT 1000,
    "election_schedule_interval" interval NOT NULL DEFAULT '1 day',
    "created_at" timestamp with time zone NOT NULL DEFAULT now(),
    "updated_at" timestamp with time zone NOT NULL DEFAULT now()
);

-- Insert default configuration if none exists
INSERT INTO "top_websites_config" 
    ("min_hits_threshold", "election_window", "longterm_retention_period", "candidates_retention_period", 
     "max_longterm_entries", "election_schedule_interval")
SELECT 100, '24 hours', '90 days', '7 days', 1000, '1 day'
WHERE NOT EXISTS (SELECT 1 FROM top_websites_config);

-- Long-term top websites storage
CREATE TABLE IF NOT EXISTS "top_websites_longterm" (
    "domain" text NOT NULL,
    "first_seen" timestamp with time zone NOT NULL,
    "last_seen" timestamp with time zone NOT NULL,
    "total_hits" bigint NOT NULL DEFAULT 0,
    "last_election_hits" bigint NOT NULL DEFAULT 0,
    "times_elected" integer NOT NULL DEFAULT 1,
    "avg_hourly_requests" double precision DEFAULT 0,
    "stddev_hourly_requests" double precision DEFAULT 0,
    "p95_hourly_requests" double precision DEFAULT 0,
    "traffic_volatility" double precision DEFAULT 0,
    PRIMARY KEY ("domain")
) WITH (
    fillfactor = 70,
    autovacuum_vacuum_scale_factor = 0.05,
    autovacuum_analyze_scale_factor = 0.025,
    autovacuum_vacuum_threshold = 50,
    autovacuum_analyze_threshold = 50
);

-- Candidates table
CREATE TABLE IF NOT EXISTS "top_websites_candidates" (
    "domain" text NOT NULL,
    "time" timestamp with time zone NOT NULL,
    "hits" bigint NOT NULL,
    "created_at" timestamp with time zone NOT NULL DEFAULT now(),
    PRIMARY KEY ("domain", "time")
);

SELECT create_hypertable('top_websites_candidates', 'time', if_not_exists => TRUE);

-- Create a view for traffic pattern analysis
CREATE OR REPLACE VIEW traffic_patterns_monitor AS
SELECT 
    domain,
    bucket,
    SUM(total) AS total_requests,
    ROUND(AVG(total)::numeric, 2) AS avg_requests_per_minute,
    ROUND(STDDEV(total)::numeric, 2) AS stddev_requests,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY total)::numeric, 2) AS p75_requests,
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY total)::numeric, 2) AS p25_requests,
    CASE 
        WHEN AVG(total) > PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY total) THEN 'High'
        WHEN AVG(total) > PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY total) THEN 'Medium'
        ELSE 'Low'
    END AS current_traffic_level,
    CASE 
        WHEN AVG(total) > LAG(AVG(total)) OVER (PARTITION BY domain ORDER BY bucket) THEN 'Growing'
        WHEN AVG(total) < LAG(AVG(total)) OVER (PARTITION BY domain ORDER BY bucket) THEN 'Declining'
        ELSE 'Stable'
    END AS trend
FROM domain_traffic_stats_1h
WHERE bucket > NOW() - INTERVAL '1 hour'
GROUP BY domain, bucket
ORDER BY bucket DESC, total_requests DESC;

-- Create the election function
CREATE OR REPLACE FUNCTION elect_top_websites(job_id INTEGER, config JSONB)
RETURNS void AS $$
DECLARE
    max_entries INTEGER;
    retention_period INTERVAL;
BEGIN
    -- Get configuration
    SELECT max_longterm_entries, longterm_retention_period 
    INTO max_entries, retention_period
    FROM top_websites_config 
    LIMIT 1;
    
    -- Update existing entries
    UPDATE top_websites_longterm t
    SET 
        last_seen = c.time,
        total_hits = t.total_hits + c.hits,
        last_election_hits = c.hits,
        times_elected = t.times_elected + 1,
        avg_hourly_requests = (
            SELECT COALESCE(AVG(total), 0)
            FROM domain_traffic_stats_1h
            WHERE domain = t.domain
            AND bucket > now() - interval '24 hours'
        ),
        stddev_hourly_requests = (
            SELECT COALESCE(STDDEV(total), 0)
            FROM domain_traffic_stats_1h
            WHERE domain = t.domain
            AND bucket > now() - interval '24 hours'
        ),
        p95_hourly_requests = (
            SELECT COALESCE(
                PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY total),
                0
            )
            FROM domain_traffic_stats_1h
            WHERE domain = t.domain
            AND bucket > now() - interval '24 hours'
        ),
        traffic_volatility = (
            SELECT COALESCE(
                STDDEV(total) / NULLIF(AVG(total), 0),
                0
            )
            FROM domain_traffic_stats_1h
            WHERE domain = t.domain
            AND bucket > now() - interval '24 hours'
        )
    FROM top_websites_candidates c
    WHERE c.domain = t.domain
    AND c.time > now() - interval '1 hour';

    -- Insert new entries
    INSERT INTO top_websites_longterm (
        domain, first_seen, last_seen, total_hits, last_election_hits,
        avg_hourly_requests, stddev_hourly_requests, p95_hourly_requests, traffic_volatility
    )
    SELECT 
        c.domain,
        c.time as first_seen,
        c.time as last_seen,
        c.hits as total_hits,
        c.hits as last_election_hits,
        COALESCE((
            SELECT AVG(total)
            FROM domain_traffic_stats_1h
            WHERE domain = c.domain
            AND bucket > now() - interval '24 hours'
        ), 0) as avg_hourly_requests,
        COALESCE((
            SELECT STDDEV(total)
            FROM domain_traffic_stats_1h
            WHERE domain = c.domain
            AND bucket > now() - interval '24 hours'
        ), 0) as stddev_hourly_requests,
        COALESCE((
            SELECT PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY total)
            FROM domain_traffic_stats_1h
            WHERE domain = c.domain
            AND bucket > now() - interval '24 hours'
        ), 0) as p95_hourly_requests,
        COALESCE((
            SELECT STDDEV(total) / NULLIF(AVG(total), 0)
            FROM domain_traffic_stats_1h
            WHERE domain = c.domain
            AND bucket > now() - interval '24 hours'
        ), 0) as traffic_volatility
    FROM top_websites_candidates c
    WHERE c.time > now() - interval '1 hour'
    AND NOT EXISTS (
        SELECT 1 
        FROM top_websites_longterm t 
        WHERE t.domain = c.domain
    )
    ORDER BY c.hits DESC
    LIMIT max_entries;

    -- Remove old entries
    DELETE FROM top_websites_longterm
    WHERE last_seen < now() - retention_period;
    
    -- Clean up old candidates
    DELETE FROM top_websites_candidates
    WHERE time < now() - interval '1 day';
    
    RAISE NOTICE 'Top websites elected by job %', job_id;
END;
$$ LANGUAGE plpgsql;

-- Function to schedule website tracking jobs
CREATE OR REPLACE FUNCTION schedule_website_tracking_jobs() 
RETURNS int[] LANGUAGE plpgsql AS $$
DECLARE
    job_ids int[] := '{}';
    job_id int;
BEGIN
    -- Schedule job to populate website candidates (runs every minute, starts after 2 minutes)
    SELECT add_job(
        'populate_website_candidates_job', 
        INTERVAL '1 minute',
        config => '{}'::jsonb,
        initial_start => NOW() + INTERVAL '2 minutes'
    ) INTO job_id;
    job_ids := array_append(job_ids, job_id);
    
    -- Schedule job to elect top websites (runs every hour, starts after 5 minutes)
    SELECT add_job(
        'elect_top_websites', 
        INTERVAL '1 hour',
        config => '{}'::jsonb,
        initial_start => NOW() + INTERVAL '5 minutes'
    ) INTO job_id;
    job_ids := array_append(job_ids, job_id);
    
    RETURN job_ids;
END;
$$;

CREATE OR REPLACE PROCEDURE populate_website_candidates_job(job_id INTEGER, config JSONB)
LANGUAGE plpgsql AS $$
DECLARE
    min_hits_threshold INTEGER;
BEGIN
    -- Get configuration
    SELECT top_websites_config.min_hits_threshold INTO min_hits_threshold
    FROM top_websites_config 
    LIMIT 1;
    
    -- Insert candidates from the last hour's traffic
    INSERT INTO top_websites_candidates (domain, time, hits)
    SELECT 
        domain,
        time_bucket('1 hour', NOW()) as time,
        COUNT(*) as hits
    FROM logs
    WHERE time > NOW() - INTERVAL '1 hour'
    GROUP BY domain
    HAVING COUNT(*) >= min_hits_threshold
    ON CONFLICT (domain, time) 
    DO UPDATE SET hits = EXCLUDED.hits;
END;
$$;

-- Create the top websites report view
CREATE OR REPLACE VIEW top_websites_report AS
SELECT 
    domain,
    total_hits,
    last_election_hits,
    times_elected,
    ROUND(avg_hourly_requests::numeric, 2) as avg_hourly_requests,
    ROUND(stddev_hourly_requests::numeric, 2) as stddev_hourly_requests,
    ROUND(p95_hourly_requests::numeric, 2) as p95_hourly_requests,
    ROUND(traffic_volatility::numeric, 2) as traffic_volatility,
    first_seen,
    last_seen,
    ROW_NUMBER() OVER (ORDER BY total_hits DESC) as rank
FROM top_websites_longterm
ORDER BY total_hits DESC;

-- Create the election job
SELECT add_job(
    'elect_top_websites',
    schedule_interval => INTERVAL '1 hour',
    config => '{"min_requests": 1000}'::jsonb,
    initial_start => NOW(),
    fixed_schedule => true
);
