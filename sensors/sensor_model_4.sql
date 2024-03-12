-- Purpose: Create the sensor data model for the sensor data considering the following:
-- Define a hypertable for each type of sensor data

create table float_sample (
  time timestamptz,
  id text,
  value float
);
select create_hypertable('float_sample', by_range('time'));

create table boolean_sample (
  time timestamptz,
  id text,
  value boolean
);
select create_hypertable('boolean_sample', by_range('time'));

create table text_sample (
  time timestamptz,
  id text,
  value text
);
select create_hypertable('text_sample', by_range('time'));


