CREATE EXTENSION IF NOT EXISTS timescaledb;
CREATE EXTENSION IF NOT EXISTS timescaledb_toolkit;

-- Create tables and functions
\i ticks.sql

-- Support pairs
\i pairs.sql

-- Test pairs
\i pairs_test.sql
