-- Remove tables and functions if exists
\i cleanup.sql

-- Create tables and functions
\i schema.sql

-- Setup continuous aggregates for candlesticks
\i caggs_candlesticks.sql

-- Create
\i compression.sql

-- Track last symbol price
-- \i track_last_symbol_price.sql

-- Support pairs
-- \i pairs.sql

-- Test pairs
-- \i pairs_test.sql

-- Simulate ticks
-- \i data-simulator.sql

-- Watch ohlcv data from multiple frames
-- \i watch_ohlcv.sql
