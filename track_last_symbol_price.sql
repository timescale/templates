
CREATE TABLE IF NOT EXISTS symbols (
    symbol TEXT PRIMARY KEY,
    last_price NUMERIC,
    last_price_at TIMESTAMPTZ
);

-- Insert most recent tick from each symbol gets rank 1.
INSERT INTO symbols (symbol, last_price)
SELECT symbol, MAX(price) AS last_price
FROM (
    SELECT symbol, price, RANK()
    OVER (PARTITION BY symbol ORDER BY time DESC) as rk
    FROM ticks
) sub
WHERE sub.rk = 1
GROUP BY symbol;

-- Add a foreign key to the ticks table if necessary ( disable compression first )
-- ALTER TABLE ticks ADD CONSTRAINT symbol_fk FOREIGN KEY (symbol_fk) REFERENCES symbols(symbol);

CREATE OR REPLACE FUNCTION update_last_price()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE symbols
    SET last_price = NEW.price,
    last_price_at = NEW.time
    WHERE symbol = NEW.symbol;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_last_price_from_ticks
AFTER INSERT ON ticks
FOR EACH ROW EXECUTE FUNCTION update_last_price();

