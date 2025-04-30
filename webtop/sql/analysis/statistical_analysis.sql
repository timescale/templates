-- WebTop - Statistical Analysis Functions
-- This file adds advanced statistical analysis capabilities using TimescaleDB Toolkit

-- Drop existing objects first
DROP VIEW IF EXISTS domain_traffic_stats CASCADE;
DROP MATERIALIZED VIEW IF EXISTS domain_traffic_stats_1h CASCADE;
DROP VIEW IF EXISTS traffic_patterns_monitor CASCADE;

-- Create a view for advanced statistical analysis of domain traffic
CREATE OR REPLACE VIEW domain_traffic_stats AS
SELECT 
    time_bucket('1 hour', time) AS bucket,
    domain,
    stats_agg(1) AS request_stats,  -- Aggregate for request counts
    percentile_agg(1) AS request_percentiles  -- Percentile aggregation for request counts
FROM logs
GROUP BY 1, 2;

-- Create a continuous aggregate for domain traffic statistics
CREATE MATERIALIZED VIEW domain_traffic_stats_1h
WITH (timescaledb.continuous, timescaledb.materialized_only=false) AS
SELECT 
    time_bucket('1 hour', time) AS bucket,
    domain,
    stats_agg(1) AS request_stats,
    percentile_agg(1) AS request_percentiles
FROM logs
GROUP BY 1, 2
WITH NO DATA;

-- Set refresh policy for the continuous aggregate
SELECT add_continuous_aggregate_policy('domain_traffic_stats_1h',
    start_offset => INTERVAL '7 days',
    end_offset => INTERVAL '5 minutes',
    schedule_interval => INTERVAL '5 minutes');

-- Create a view for traffic pattern analysis
CREATE OR REPLACE VIEW traffic_patterns_monitor AS
SELECT 
    domain,
    bucket,
    num_vals(request_stats) AS total_requests,
    ROUND(average(request_stats)::numeric, 2) AS avg_requests_per_minute,
    ROUND(stddev(request_stats)::numeric, 2) AS stddev_requests,
    ROUND(skewness(request_stats)::numeric, 2) AS skewness,
    ROUND(kurtosis(request_stats)::numeric, 2) AS kurtosis,
    CASE 
        WHEN average(request_stats) > approx_percentile(0.75, request_percentiles) THEN 'High'
        WHEN average(request_stats) > approx_percentile(0.25, request_percentiles) THEN 'Medium'
        ELSE 'Low'
    END AS current_traffic_level,
    CASE 
        WHEN average(request_stats) > LAG(average(request_stats)) OVER (PARTITION BY domain ORDER BY bucket) THEN 'Growing'
        WHEN average(request_stats) < LAG(average(request_stats)) OVER (PARTITION BY domain ORDER BY bucket) THEN 'Declining'
        ELSE 'Stable'
    END AS trend
FROM domain_traffic_stats_1h
WHERE bucket > NOW() - INTERVAL '1 hour'
ORDER BY bucket DESC, total_requests DESC;

-- Function to analyze traffic patterns with advanced statistics
CREATE OR REPLACE FUNCTION analyze_traffic_patterns(
    domain_name TEXT DEFAULT NULL,
    time_window INTERVAL DEFAULT '1 hour'
)
RETURNS TABLE (
    domain TEXT,
    time_bucket TIMESTAMPTZ,
    total_requests BIGINT,
    avg_requests DOUBLE PRECISION,
    stddev_requests DOUBLE PRECISION,
    traffic_level TEXT,
    trend TEXT,
    trend_slope DOUBLE PRECISION,
    trend_r2 DOUBLE PRECISION
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    WITH hourly_stats AS (
        SELECT 
            d.domain,
            d.bucket AS time_bucket,
            num_vals(d.request_stats)::BIGINT AS total_requests,
            average(d.request_stats)::DOUBLE PRECISION AS avg_requests,
            stddev(d.request_stats)::DOUBLE PRECISION AS stddev_requests
        FROM domain_traffic_stats_1h d
        WHERE d.bucket > NOW() - time_window
        AND (domain_name IS NULL OR d.domain = domain_name)
        ORDER BY d.domain, d.bucket DESC
    )
    SELECT 
        hs.domain,
        hs.time_bucket,
        hs.total_requests,
        hs.avg_requests,
        hs.stddev_requests,
        CASE 
            WHEN hs.total_requests > LAG(hs.total_requests) OVER (PARTITION BY hs.domain ORDER BY hs.time_bucket) * 1.2 THEN 'High'
            WHEN hs.total_requests > LAG(hs.total_requests) OVER (PARTITION BY hs.domain ORDER BY hs.time_bucket) * 0.8 THEN 'Medium'
            ELSE 'Low'
        END AS traffic_level,
        CASE 
            WHEN hs.total_requests > LAG(hs.total_requests) OVER (PARTITION BY hs.domain ORDER BY hs.time_bucket) THEN 'Growing'
            WHEN hs.total_requests < LAG(hs.total_requests) OVER (PARTITION BY hs.domain ORDER BY hs.time_bucket) THEN 'Declining'
            ELSE 'Stable'
        END AS trend,
        regr_slope(hs.total_requests, EXTRACT(EPOCH FROM hs.time_bucket)) OVER (PARTITION BY hs.domain ORDER BY hs.time_bucket ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS trend_slope,
        regr_r2(hs.total_requests, EXTRACT(EPOCH FROM hs.time_bucket)) OVER (PARTITION BY hs.domain ORDER BY hs.time_bucket ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS trend_r2
    FROM hourly_stats hs
    ORDER BY hs.domain, hs.time_bucket DESC;
END;
$$;

-- Function to detect traffic anomalies using statistical methods
CREATE OR REPLACE FUNCTION detect_traffic_anomalies(
    domain_name TEXT DEFAULT NULL,
    time_window INTERVAL DEFAULT '1 hour',
    threshold FLOAT DEFAULT 2.0
)
RETURNS TABLE (
    domain TEXT,
    time_bucket TIMESTAMPTZ,
    actual_requests BIGINT,
    expected_requests FLOAT,
    deviation FLOAT,
    is_anomaly BOOLEAN
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    WITH domain_stats AS (
        SELECT 
            d.domain,
            AVG(num_vals(d.request_stats))::FLOAT AS avg_requests,
            STDDEV(num_vals(d.request_stats))::FLOAT AS stddev_requests
        FROM domain_traffic_stats_1h d
        WHERE d.bucket > NOW() - time_window
        AND (domain_name IS NULL OR d.domain = domain_name)
        GROUP BY d.domain
    )
    SELECT 
        d.domain,
        d.bucket,
        num_vals(d.request_stats)::BIGINT,
        ds.avg_requests,
        CASE 
            WHEN ds.stddev_requests = 0 THEN 0
            ELSE (num_vals(d.request_stats) - ds.avg_requests) / ds.stddev_requests
        END::FLOAT,
        CASE 
            WHEN ds.stddev_requests = 0 THEN FALSE
            ELSE ABS(num_vals(d.request_stats) - ds.avg_requests) > (ds.stddev_requests * threshold)
        END
    FROM domain_traffic_stats_1h d
    JOIN domain_stats ds ON d.domain = ds.domain
    WHERE d.bucket > NOW() - time_window
    AND (domain_name IS NULL OR d.domain = domain_name)
    ORDER BY d.domain, d.bucket DESC;
END;
$$;

-- Function to generate a traffic report with advanced statistics
CREATE OR REPLACE FUNCTION generate_traffic_report(
    time_window INTERVAL DEFAULT '1 day'
)
RETURNS TABLE (
    domain TEXT,
    total_requests BIGINT,
    avg_requests_per_hour DOUBLE PRECISION,
    stddev_requests DOUBLE PRECISION,
    p95_requests DOUBLE PRECISION,
    max_requests BIGINT,
    traffic_volatility DOUBLE PRECISION,
    traffic_trend TEXT,
    anomaly_count BIGINT
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    WITH domain_stats AS (
        SELECT 
            d.domain,
            SUM(num_vals(d.request_stats))::BIGINT AS total_requests,
            ROUND(average(d.request_stats)::numeric, 2) AS avg_requests,
            ROUND(stddev(d.request_stats)::numeric, 2) AS stddev_requests,
            ROUND(approx_percentile(0.95, d.request_percentiles)::numeric, 2) AS p95_requests,
            MAX(num_vals(d.request_stats))::BIGINT AS max_requests,
            ROUND(
                CASE 
                    WHEN average(d.request_stats) = 0 THEN 0
                    ELSE stddev(d.request_stats) / average(d.request_stats)
                END::numeric, 
                2
            ) AS traffic_volatility,
            CASE 
                WHEN average(d.request_stats) > LAG(average(d.request_stats)) OVER (PARTITION BY d.domain ORDER BY d.bucket) THEN 'Growing'
                WHEN average(d.request_stats) < LAG(average(d.request_stats)) OVER (PARTITION BY d.domain ORDER BY d.bucket) THEN 'Declining'
                ELSE 'Stable'
            END AS traffic_trend
        FROM domain_traffic_stats_1h d
        WHERE d.bucket > NOW() - time_window
        GROUP BY d.domain, d.bucket
    ),
    anomaly_counts AS (
        SELECT 
            domain,
            COUNT(*) AS anomaly_count
        FROM detect_traffic_anomalies(NULL, time_window)
        WHERE is_anomaly = TRUE
        GROUP BY domain
    )
    SELECT 
        ds.domain,
        ds.total_requests,
        ds.avg_requests AS avg_requests_per_hour,
        ds.stddev_requests,
        ds.p95_requests,
        ds.max_requests,
        ds.traffic_volatility,
        ds.traffic_trend,
        COALESCE(ac.anomaly_count, 0) AS anomaly_count
    FROM domain_stats ds
    LEFT JOIN anomaly_counts ac ON ds.domain = ac.domain
    ORDER BY ds.total_requests DESC;
END;
$$; 