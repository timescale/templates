-- insert random ticks data and recursively schedule next job.
CREATE OR REPLACE FUNCTION insert_random_ticks(job_id int, config jsonb) RETURNS VOID AS $$
DECLARE
  last_time timestamptz;
  interval_value interval default '1 second';
  symbol text;
  price numeric;
  volume numeric;
BEGIN
    select into last_time max(time) from ticks;
    if config ? 'interval' then
        interval_value := (config ->> 'interval')::interval;
    end if;

    if last_time is null then
        last_time := now() - interval_value;
    end if;

    if config ? 'symbol' then
        symbol := config ->> 'symbol';
    else
        symbol := 'BTC/USD';
    end if;
    if config ? 'last_price' then
        price := ((config ->> 'last_price')::numeric + (random() * 100 - 50))::numeric(10,2);
    else
        price := (random() * 10000)::numeric(10,2);
    end if;

    insert into ticks (time, symbol, price, volume)
    select d, symbol, price, (random() * 100)::numeric(10,2)
    FROM generate_series(last_time + interval_value, now(), interval_value) d;

END;
$$
LANGUAGE plpgsql;
;

select add_job('insert_random_ticks', '5 second', '{"interval": "5 second", "symbol": "ETH/USD"}');


insert into symbols (symbol, last_price, last_price_at)
  select 'SYM-'||symbol, random()*80 - 40, now() - INTERVAL '1 hour'
FROM generate_series(1, 300) AS symbol
where symbol % 2 = 0;

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
            coalesce(latest.time, null, now()) + INTERVAL '1 second',
            coalesce(latest.time, null, now()) + INTERVAL '1 hours',
            INTERVAL '1 second') AS g1(time),
        generate_series(1, 280) AS g2(symbol)
      ) a ON true;
$$;


