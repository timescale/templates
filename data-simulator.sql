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
    select now(), symbol, price, (random() * 100)::numeric(10,2);
END;
$$
LANGUAGE plpgsql;
;

select add_job('insert_random_ticks', '5 second', '{"interval": "5 second", "symbol": "ETH/USD"}');
