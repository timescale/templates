-- Traffic Monitor View
-- This view provides real-time monitoring of traffic patterns

CREATE OR REPLACE VIEW traffic_monitor AS
WITH recent_traffic AS (
    SELECT 
        domain,
        time_bucket('1 minute', time) AS minute,
        COUNT(*) AS requests
    FROM logs
    WHERE time > NOW() - INTERVAL '10 minutes'
    GROUP BY domain, time_bucket('1 minute', time)
),
traffic_stats AS (
    SELECT 
        domain,
        AVG(requests) AS avg_requests,
        MAX(requests) AS max_requests,
        MIN(requests) AS min_requests,
        STDDEV(requests) AS stddev_requests
    FROM recent_traffic
    GROUP BY domain
),
traffic_patterns AS (
    SELECT 
        domain,
        CASE 
            WHEN stddev_requests > avg_requests * 0.5 THEN 'BURSTY'
            WHEN max_requests > avg_requests * 2 THEN 'BURSTY'
            WHEN max_requests < avg_requests * 0.5 THEN 'DECLINING'
            ELSE 'STEADY'
        END AS pattern,
        CASE 
            WHEN avg_requests > 1000 THEN 'HIGH'
            WHEN avg_requests > 100 THEN 'MEDIUM'
            ELSE 'LOW'
        END AS traffic_level
    FROM traffic_stats
)
SELECT 
    t.domain,
    t.pattern,
    t.traffic_level,
    s.avg_requests,
    s.max_requests,
    s.min_requests,
    s.stddev_requests,
    CASE 
        WHEN t.domain IN (SELECT domain FROM top_websites_longterm) THEN 'TOP'
        WHEN t.domain IN (SELECT domain FROM top_websites_candidates) THEN 'CANDIDATE'
        ELSE 'RANDOM'
    END AS website_status
FROM traffic_patterns t
JOIN traffic_stats s ON t.domain = s.domain
ORDER BY s.avg_requests DESC; 