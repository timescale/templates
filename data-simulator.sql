-- insert random ticks data and recursively schedule next job.
CREATE OR REPLACE PROCEDURE insert_random_ticks(job_id int, config jsonb) $$
DECLARE
  last_time timestamptz;
  interval_value interval default '1 second';
  symbol text;
  price numeric;
  volume numeric;
begin
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
        price := (config ->> 'last_price')::numeric + (random() * 100 - 50);
    else
        price := random() * 10000;
    end if;

    insert into ticks (time, symbol, price, volume)
    select last_time + interval_value, 'BTC/USD', price, random() * 100;
    end;
    -- recursively schedule next job
    config['last_price'] := price;
    select add_job('insert_random_ticks', '0 sec', config, last_time + interval_value);
END;
$$
$$;
LANGUAGE Plpgsql;

select add_job('insert_random_ticks', '1 second', '{"interval": "0.2 seconds", "symbol": "ETH/USD"}', now() + INTERVAL '1s');
