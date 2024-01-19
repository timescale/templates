-- Insert into symbols table
INSERT INTO symbols (symbol, last_price) VALUES
('STOCK_A', 100.0),
('STOCK_B', 200.0);

-- Insert into ticks table
-- Hypothetical tick data for STOCK_A and STOCK_B
INSERT INTO ticks (time, symbol, price, volume) VALUES
(now(), 'STOCK_A', 101.0, 1000),
(now(), 'STOCK_B', 202.0, 500);

-- Verify last_price update in symbols table
SELECT * FROM symbols;

-- Insert into tracked_pairs
-- Assuming STOCK_A and STOCK_B are the pair to be tracked
INSERT INTO tracked_pairs (symbol_pair) VALUES ('STOCK_A/STOCK_B') ON CONFLICT DO NOTHING;

-- (Insert more ticks data here to simulate more trading activity)

INSERT INTO ticks (time, symbol, price, volume) VALUES
(now(), 'STOCK_A', 102.0, 1000),
(now(), 'STOCK_B', 202.0, 500);


-- Verify pairs table update
-- This should show correlated data for STOCK_A and STOCK_B
SELECT * FROM ticks order by time desc limit 5;
