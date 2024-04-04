-- simulate several insertions into the database
-- insert sample data as described on sensors.sql

insert into :hypertable (time, :segment, :payload_name)
select time, 'device_id' || (random() * 10)::int, random() * 100
from generate_series(now() - interval '1 year', now(), interval '30s') as time;
