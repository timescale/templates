-- Swap Finance SQL Schema and Sample Data
-- Ready for testing with TimescaleDB
-- Run with: psql $local_uri -f swap_finance.sql

-- Create extension if not exists
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Drop existing tables and views to start fresh
DROP VIEW IF EXISTS swap_fifo_pnl;
DROP TABLE IF EXISTS swap_events CASCADE;

-- Create the swap events table
CREATE TABLE swap_events (
  id SERIAL,
  time TIMESTAMPTZ NOT NULL,
  token_address TEXT NOT NULL,
  token_in NUMERIC,
  token_out NUMERIC,
  usd_in NUMERIC,
  usd_out NUMERIC,
  wallet_address TEXT,
  PRIMARY KEY (id, time)  -- Include time in the primary key for TimescaleDB
);

-- Convert to a TimescaleDB hypertable
SELECT create_hypertable('swap_events', 'time');

-- Insert some sample data
INSERT INTO swap_events (time, token_address, token_in, token_out, usd_in, usd_out, wallet_address) VALUES
  ('2025-03-01 10:00:00', '0xabc123', 1.0, 0, 100, 0, '0xuser1'),
  ('2025-03-02 11:00:00', '0xabc123', 2.0, 0, 210, 0, '0xuser1'),
  ('2025-03-03 12:00:00', '0xabc123', 0, 0.5, 0, 60, '0xuser1'),
  ('2025-03-04 13:00:00', '0xabc123', 0, 1.5, 0, 180, '0xuser1'),
  ('2025-03-05 14:00:00', '0xabc123', 3.0, 0, 300, 0, '0xuser1'),
  ('2025-03-06 15:00:00', '0xabc123', 0, 2.0, 0, 220, '0xuser1');

-- Create a view for realized PnL with FIFO accounting
CREATE OR REPLACE VIEW swap_fifo_pnl AS
WITH token_queue AS (
  SELECT
    time,
    id,
    token_address,
    wallet_address,
    token_in,
    token_out,
    usd_in,
    usd_out,
    SUM(token_in) OVER (
      PARTITION BY wallet_address, token_address
      ORDER BY time, id
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) - SUM(token_out) OVER (
      PARTITION BY wallet_address, token_address
      ORDER BY time, id
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS token_balance,
    SUM(token_in) OVER (
      PARTITION BY wallet_address, token_address
      ORDER BY time, id
    ) AS cumulative_token_in,
    SUM(token_out) OVER (
      PARTITION BY wallet_address, token_address
      ORDER BY time, id
    ) AS cumulative_token_out,
    SUM(usd_in) OVER (
      PARTITION BY wallet_address, token_address
      ORDER BY time, id
    ) AS cumulative_usd_in
  FROM swap_events
),
fifo_calcs AS (
  SELECT
    time,
    id,
    token_address,
    wallet_address,
    token_in,
    token_out,
    usd_in,
    usd_out,
    token_balance,
    cumulative_token_in,
    cumulative_token_out,
    cumulative_usd_in,
    CASE 
      WHEN token_out > 0 THEN
        -- Calculate the average cost basis for tokens being sold using FIFO
        usd_out - (token_out * 
          (LAG(cumulative_usd_in, 1, 0) OVER (PARTITION BY wallet_address, token_address ORDER BY time, id) / 
           LAG(cumulative_token_in, 1, 1) OVER (PARTITION BY wallet_address, token_address ORDER BY time, id)))
      ELSE 0
    END AS realized_pnl
  FROM token_queue
)
SELECT
  time,
  wallet_address,
  token_address,
  token_in,
  token_out,
  usd_in,
  usd_out,
  token_balance,
  realized_pnl,
  SUM(realized_pnl) OVER (
    PARTITION BY wallet_address, token_address
    ORDER BY time, id
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  ) AS cumulative_pnl
FROM fifo_calcs;

-- Create continuous aggregate for real-time metrics
CREATE MATERIALIZED VIEW IF NOT EXISTS swap_events_hourly WITH (timescaledb.continuous) AS
SELECT
  time_bucket('1 hour', time) AS bucket,
  wallet_address,
  token_address,
  SUM(usd_in) AS total_usd_in,
  SUM(usd_out) AS total_usd_out,
  SUM(token_in) AS total_token_in,
  SUM(token_out) AS total_token_out,
  COUNT(*) AS swap_count,
  COUNT(CASE WHEN token_out > 0 THEN 1 END) AS sell_count,
  COUNT(CASE WHEN token_in > 0 THEN 1 END) AS buy_count
FROM swap_events
GROUP BY bucket, wallet_address, token_address;

-- Force refresh for testing
CALL refresh_continuous_aggregate('swap_events_hourly', null, null);
  
-- Set refresh policy for the continuous aggregate
SELECT add_continuous_aggregate_policy('swap_events_hourly',
  start_offset => INTERVAL '1 day',
  end_offset => INTERVAL '1 hour',
  schedule_interval => INTERVAL '1 hour');


-- Query to check FIFO PnL results
SELECT 
  time, 
  wallet_address, 
  token_address, 
  token_in, 
  token_out, 
  usd_in, 
  usd_out, 
  token_balance, 
  realized_pnl, 
  cumulative_pnl 
FROM swap_fifo_pnl
ORDER BY time;

-- Query for performance metrics (win rate, etc.)
SELECT
  wallet_address,
  token_address,
  COUNT(*) AS total_trades,
  COUNT(CASE WHEN realized_pnl > 0 THEN 1 END) AS winning_trades,
  ROUND(COUNT(CASE WHEN realized_pnl > 0 THEN 1 END)::numeric / NULLIF(COUNT(*), 0) * 100, 2) AS win_rate,
  SUM(realized_pnl) AS total_pnl
FROM swap_fifo_pnl
WHERE token_out > 0
GROUP BY wallet_address, token_address;

-- Additional useful queries

-- Daily volume by token
SELECT
  time_bucket('1 day', time) AS day,
  token_address,
  SUM(usd_in) AS buy_volume_usd,
  SUM(usd_out) AS sell_volume_usd,
  SUM(usd_in) + SUM(usd_out) AS total_volume_usd,
  SUM(token_in) AS buy_volume_token,
  SUM(token_out) AS sell_volume_token
FROM swap_events
GROUP BY day, token_address
ORDER BY day;

-- Average cost basis per wallet and token
SELECT
  wallet_address,
  token_address,
  SUM(usd_in) AS total_cost,
  SUM(token_in) AS total_tokens_bought,
  CASE 
    WHEN SUM(token_in) - SUM(token_out) > 0 THEN 
      SUM(usd_in) / SUM(token_in)
    ELSE 0
  END AS avg_cost_per_token,
  SUM(token_in) - SUM(token_out) AS current_token_balance
FROM swap_events
GROUP BY wallet_address, token_address
HAVING SUM(token_in) - SUM(token_out) > 0
ORDER BY wallet_address, token_address;

-- Unrealized PnL (requires current price data, using last sell price as estimate)
WITH last_prices AS (
  SELECT DISTINCT ON (token_address)
    token_address,
    usd_out / token_out AS estimated_current_price
  FROM swap_events
  WHERE token_out > 0
  ORDER BY token_address, time DESC
)
SELECT
  w.wallet_address,
  w.token_address,
  w.current_token_balance,
  w.avg_cost_per_token,
  p.estimated_current_price,
  w.current_token_balance * p.estimated_current_price AS estimated_current_value,
  w.current_token_balance * p.estimated_current_price - (w.current_token_balance * w.avg_cost_per_token) AS unrealized_pnl,
  ROUND(((p.estimated_current_price / w.avg_cost_per_token) - 1) * 100, 2) AS unrealized_pnl_percent
FROM (
  SELECT
    wallet_address,
    token_address,
    SUM(token_in) - SUM(token_out) AS current_token_balance,
    SUM(usd_in) / SUM(token_in) AS avg_cost_per_token
  FROM swap_events
  GROUP BY wallet_address, token_address
  HAVING SUM(token_in) - SUM(token_out) > 0
) w
JOIN last_prices p ON w.token_address = p.token_address;