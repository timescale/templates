CREATE OR REPLACE FUNCTION add_sample_data() RETURNS VOID LANGUAGE sql AS
$$
  INSERT INTO sample
      WITH latest AS MATERIALIZED (
        SELECT time FROM sample ORDER BY time DESC LIMIT 1
      )
      SELECT a.time,
        a.device_id,
        random()*100 AS value -- Assuming the value is a numeric type in the range 0-100
      FROM latest LEFT JOIN LATERAL (
        SELECT g1.time,
               g2.device_id
        FROM generate_series(
            COALESCE(latest.time, now()) + INTERVAL '1 second',
            COALESCE(latest.time, now()) + INTERVAL '1 month',
            INTERVAL '15 seconds') AS g1(time),
             generate_series(1, 10) AS g2(device_id) -- Assuming you have 10 devices, adjust as needed
      ) a ON true;
$$;

CREATE OR REPLACE PROCEDURE emulate_sample_from_devices(job_id int, config jsonb) LANGUAGE PLPGSQL AS
$$
BEGIN
  RAISE NOTICE 'Inserting in the job % with config %', job_id, config;
  insert into sample (time, device_id, value)
  select now(), i::text, random() * 100 from generate_series(1, 10) as i;
END
$$;

SELECT add_job('emulate_sample_from_devices','5 seconds', initial_start => now() + INTERVAL '5 seconds');

