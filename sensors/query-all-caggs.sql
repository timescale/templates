 with m as (
    select * from stats_agg_1m_sample
),
h as (
    select * from stats_agg_1h_sample
),
d as (
    select * from stats_agg_1d_sample
),
mon as (
    select * from stats_agg_monthly_sample
)
select
m.bucket as time,
m.device_id,
m.stats_agg->average() as avg_1m,
h.stats_agg->average() as avg_1h,
d.stats_agg->average() as avg_1d,
mon.stats_agg->average() as avg_mon
from m join h on time_bucket('1h', m.bucket) = h.bucket and m.device_id = h.device_id
 join d on time_bucket('1d', m.bucket) = d.bucket and m.device_id = d.device_id
join mon on time_bucket('1mon', m.bucket) = mon.bucket and m.device_id = mon.device_id
where m.bucket > now() - interval '1 month'
order by 1 desc,2 asc limit 10
