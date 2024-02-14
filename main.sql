-- Remove tables and functions if exists
\i cleanup.sql

-- Create tables and functions
\i ticks.sql

-- Track last symbol price
\i track_last_symbol_price.sql

-- Support pairs
\i pairs.sql

-- Test pairs
\i pairs_test.sql

-- Simulate ticks
\i simulate_ticks.sql

-- Watch ohlcv data from multiple frames
\i watch_ohlcv.sql
