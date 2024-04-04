# Sensors data

This is a template to create a database with a hypertable for sensors data.

## Requirements

Timescaledb installed and configured in your database. Clone the repository and
start building your main file:

The [main.sql](./main.sql) file contains the main configuration to create the
structure that you want. The file is divided into sections to help you to
configure the database.

A few options are commented and you can go over and uncomment to enable the
features depending on your needs.

For now, navigating on the main file, you will find:

- [config.sql](config.sql) for all configurations: names, intervals, etc.
- [schema.sql](schema.sql) for creating the tables and hypertable.
- [caggs.sql](caggs.sql) for hierarchical continuous aggregates rolling up stats_agg.
- [compression.sql](compression.sql) for enabling compression and setting up compression policies.
- [retention.sql](retention.sql) for setting up retention policies.
- [data-simulator.sql](data-simulator.sql) for simulating data.
- [uninstall.sql](uninstall.sql) for dropping the full schema cascading to all tables and structures created by the template.

:warning: **Warning**: The uninstall script will drop the schema, so don't mix
with other business resources already available or just skip it.

### Kickstart

Let's start with our first example, so, just copy the `main.sql` into
`your-solar-panel.sql` and start editing the file.

```bash
cp main.sql your-solar-panel.sql
```

### Configuration

Check out all the [config.sql](config.sql) settings for the database.
You can change the names, intervals, and other configurations to adapt to your
needs.

Let's load our business names overriding the official configs:

```sql
\i config.sql

-- Main configuration for my solar panel farm.

\set schema_name '''solar_punk_farm'''

\set hypertable '''panel_data'''
\set hypertable_name '''panel_data'''

\set segment panel_id
\set segment_name '''panel_id'''

\set payload_type 'integer'
\set payload_name '''power'''

\set sample_segment '''roof_a:panel_1'''
\set sample_payload 100

\set retention_interval '5 year'

-- Continuous Aggregates
\i caggs.sql

-- Compression Policies
\i compression.sql

-- Retention Policies
\i retention.sql
```

### Schema

Configure the schema file to create the tables and the hypertable.

```sql
\i schema.sql
```

The schema constitutes the default namespace for all further operations which
does not prefix any schema. Instead, we change the search path to the schema.


## Continuous Aggregates

We have a few implementations of continuous aggregates. Consider changing and
adapting it to your needs.

### Hierarchical Continuous Aggregates with Dynamic config

The [caggs.sql](caggs.sql) implements Hierarchical Continuous Aggregates with
minute, hour, day, week and month timeframes. The minutely is the only one that
touches the raw hypertable and all others are rolling up from previous
hypertables. The timeframes are static but can be easily extended to more levels
if necessary.

Everything is configurable through the file and inherits previous file
configurations.

```sql
\set value_expr ':payload_name'
\set cagg_1m stats_agg_minute_:hypertable
\set hcagg_1h stats_agg_hour_:hypertable
\set hcagg_1d stats_agg_day_:hypertable
\set hcagg_1m stats_agg_month_:hypertable
```

For the functions, the `:payload_name` is already representing the value
pre-configured in the `sensors.sql` file.

For the rollup, the default needs to be changed to the same as the functions to
allow the rollup to work recursively in several levels.

```sql
\set func_expr stats_agg(:value_expr)
\set rollup_expr rollup(stats_agg) AS stats_agg
```

This configuration allows to configure multiple functions and rollups for the
same view.

```sql
\set func_expr stats_agg(':payload_name'), percentile_agg(':payload_name')
\set rollup_expr rollup(stats_agg) AS stats_agg, rollup(percentile_agg) AS percentile_agg
```
### Hierarchical Continuous Aggregates with Dynamic Timeframes

The [caggs_dynamic_timeframes.sql](caggs_dynamic_timeframes.sql) implements Hierarchical Continuous Aggregates with
flexible timeframes that should be configured by replacing the original
variables:

```sql
    periods TEXT[] := ARRAY['1 minute', '1 hour', '1 day', '1 month'];
    period_suffixes TEXT[] := ARRAY['1m', '1h', '1d', 'monthly'];
```

### Retention

The `retention.sql` setup retention for the hypertable.

### Simulating data

If you want to just simulate some amount of data, here is a small snippet to
help you to just insert data of 10 devices every 30 seconds during 1 year.

```sql
insert into :hypertable (time, :segment, :payload_name)
select time, 'device_id' || (random() * 10)::int, random() * 100
from generate_series(now() - interval '1 year', now(), interval '30s') as time;
```

#### Data Simulator

You can also take a look on [data simulator](./data-simulator.sql) that adds
a background worker that simulates random data of 10 devices every 5 seconds
continuously.

To run the data simulator, you can just run add following line to your main.sql.

```sql
\i data-simulator.sql
```

# Uninstalling

If you want ot remove completely all the structures created by the template,
you can run the uninstall script. Keep in mind it depends on your config.sql and
the overrides you made.

:warning: To drop all tests and structures created by the template,
the uninstall script will `DROP THE SCHEMA CASCADE`.

```sql
\i config.sql

-- Add all your configuration overrides here.

\i uninstall.sql
```
