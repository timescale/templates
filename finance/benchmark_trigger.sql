-- 540k ticks: 900 symbols with 10 ticks per second during 1 minute
CREATE OR REPLACE FUNCTION add_ticks()  RETURNS VOID LANGUAGE sql AS
$$
  INSERT INTO ticks
      WITH latest AS materialized (
        SELECT time FROM ticks ORDER BY time DESC LIMIT 1 
      )
      SELECT a.time,
        'SYM-'||a.symbol,
        random()*80 - 40 AS price,
        random()*100 AS volume
      FROM latest LEFT JOIN lateral (
        SELECT * FROM generate_series(
            latest.time + INTERVAL '100 ms',
            latest.time + INTERVAL '1 min',
            INTERVAL '100 ms') AS g1(time),
        generate_series(1, 900) AS g2(symbol)
      ) a ON true;
$$;

DROP trigger if exists update_last_price_from_ticks ON ticks;
truncate symbols;

select add_ticks() as no_trigger;

CREATE TRIGGER update_last_price_from_ticks
AFTER INSERT ON ticks
FOR EACH ROW EXECUTE FUNCTION update_last_price();

select add_ticks() as with_trigger_but_empty_records;

truncate symbols;
insert into symbols (symbol, last_price, last_price_at) select 'SYM-'||symbol, random()*80 - 40, now() - INTERVAL '1 hour'
  FROM generate_series(1, 90) AS symbol;
select add_ticks() as tracking_10_percent;

truncate symbols;
insert into symbols (symbol, last_price, last_price_at) select 'SYM-'||symbol, random()*80 - 40, now() - INTERVAL '1 hour'
  FROM generate_series(300, 750) AS symbol;
select add_ticks() as tracking_50_percent;

truncate symbols;
insert into symbols (symbol, last_price, last_price_at) select 'SYM-'||symbol, random()*80 - 40, now() - INTERVAL '1 hour'
  FROM generate_series(1, 900) AS symbol;
select add_ticks() as tracking_all_symbols;
