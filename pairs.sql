
CREATE TABLE tracked_pairs (
    symbol_pair TEXT PRIMARY KEY
);

DROP TABLE IF EXISTS symbols cascade;
CREATE TABLE symbols (
    symbol TEXT PRIMARY KEY,
    last_price NUMERIC,
    last_price_at TIMESTAMPTZ
);

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

CREATE TRIGGER update_last_price_trigger
AFTER INSERT ON ticks
FOR EACH ROW EXECUTE FUNCTION update_last_price();

CREATE OR REPLACE FUNCTION insert_pair_ticks()
RETURNS TRIGGER AS $$
DECLARE
    symbol1 TEXT;
    symbol2 TEXT;
    symbol_pair TEXT;
    price1 NUMERIC;
    price2 NUMERIC;
BEGIN
    SELECT tracked_pairs.symbol_pair
    INTO symbol_pair
    FROM tracked_pairs
    WHERE tracked_pairs.symbol_pair ~ NEW.symbol;

    IF symbol_pair IS NULL THEN
        RETURN NEW;
    END IF;

    -- Split the symbol pair and get the individual symbols
    symbol1 := split_part(symbol_pair, '/', 1);
    symbol2 := split_part(symbol_pair, '/', 2);

    -- Retrieve the last prices for the symbols
    SELECT last_price INTO price1 FROM symbols WHERE symbol = symbol1;
    SELECT last_price INTO price2 FROM symbols WHERE symbol = symbol2;

    -- Check if both prices are available
    IF price1 IS NOT NULL AND price2 IS NOT NULL THEN
        -- Insert the calculated data into pairs table
        INSERT INTO ticks (time, symbol, price, volume)
        VALUES (NEW.last_price_at, symbol_pair, (price1 / price2)::numeric(10,5), 1);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER insert_pair_ticks_trigger
AFTER UPDATE ON symbols
FOR EACH ROW EXECUTE FUNCTION insert_pair_ticks();
