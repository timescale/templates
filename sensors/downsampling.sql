-- Downsampling using lttb

SELECT device_id, (lttb(time, value, 10)->unnest()).*
  FROM sample
WHERE
  time > now() - interval '1 hour'
AND
  device_id = '1'
GROUP BY 1 ORDER BY 1 desc;


-- Downsampling using asap
SELECT device_id, (asap_smooth(time, value, 10)->unnest()).*
  FROM sample
WHERE
  time > now() - interval '1 hour'
AND
  device_id = '1'
GROUP BY 1 ORDER BY 1 desc;

# Histogram example with 8 buckets

with day as (
    select
    min(value) as low,
    max(value) as high
    from sample
    where device_id = '1'
      and time > now() - interval '1 day'
)
select time_bucket('1 hour', time) as bucket,
  count(value) as count,
  histogram(value, day.low, day.high, 8) as hist
from sample, day
where device_id = '1'
  and time > now() - interval '1 day' group by 1 order by 1;

with day as (
  select
    min(temp_c) as low,
    max(temp_c) as high
  from weather_metrics
  where
    city_name = 'New York'
  and
    time > now() - interval '1 day'
)
select
  time_bucket('1 hour', time) as bucket,
  count(temp_c) as count,
  histogram(temp_c, day.low, day.high, 8) as hist
from weather_metrics, day
    where city_name = 'New York'
      and time > now() - interval '1 day'
group by 1 order by 1;


select
  last(value) as temperature
from sample
where
  device_id = 'fridge'
and
  time > now() - interval '1 day';


WITH one_month AS (
  SELECT time_bucket('1 day'::interval, time) AS bucket,
    percentile_agg(value, 1000) 
  FROM sample
  WHERE device_id = '1'
    AND time > now() - interval '1 month'
  GROUP BY 1 ORDER BY 1
)
SELECT bucket as x,
  approx_percentile(0.25, percentile_agg) AS y,
  approx_percentile(0.5, percentile_agg) AS y_median,
  approx_percentile(0.75, percentile_agg) AS y_q3,
  approx_percentile(0.99, percentile_agg) AS y_99
FROM one_month;

