# Sensors data

This is a work in progress on Sensors data.

The `main.sql` file contains the call for extra files.

Remember to configure the `sensors.sql` with the variables you want.

```sql
\set hypertable events
\set hypertable_name '''events'''
\set chunk_time_interval '''1 week'''
\set segment origin
\set segment_name '''origin'''
```

The `sensors.sql` file contains the main functions to create the tables and the hypertable.
The `compression.sql` setup compression for the hypertable.
The `caggs.sql` is a WIP with Hierarchical Continuous Aggregates
