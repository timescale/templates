-- Main configuration for sensors data.

\set schema_name '''sensors'''

\set hypertable sample
\set hypertable_name '''sample'''
\set chunk_time_interval '''1 week'''

\set segment device_id
\set segment_name '''device_id'''

\set payload_type 'double precision'
\set payload_name value

\set sample_segment '''room_a:temperature'''
\set sample_payload 20.0

-- for retention policies

\set retention_interval '5 years'
