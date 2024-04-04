-- Purpose: define a minimal hypertable to store sensors data

create table sample (
  time timestamptz,
  device text,
  value double precision
);

select create_hypertable('sample', by_range('time'));




