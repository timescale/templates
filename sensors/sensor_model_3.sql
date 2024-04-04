-- Purpose: Simple storage for generic metrics system which could be sensors data

create table metrics (
  time timestamptz,
  metric_name text,
  value double precision
)

select create_hypertable('metrics', by_range('time'));

insert into metrics values (now(), 'temperature', 20.0);
insert into metrics values (now(), 'humidity', 72.3);

insert into metrics values (now(), 'kitchen:temperature', 20.0);
insert into metrics values (now(), 'lab_1:humidity', 72.3);
