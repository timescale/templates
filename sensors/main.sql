
\i sensors.sql
\i caggs_2.sql
-- \i best_cagg.sql
\i data-simulator.sql

--insert into sample (time, device_id, value) values (now() - INTERVAL '6 months', '1', 20.0);
--select add_sample_data() from generate_series(1, 6) as _;

call refresh_continuous_aggregate('stats_agg_1m_sample', null, null);
call refresh_continuous_aggregate('stats_agg_1h_sample', null, null);
call refresh_continuous_aggregate('stats_agg_1d_sample', null, null);
call refresh_continuous_aggregate('stats_agg_monthly_sample', null, null);


-- see more examples in the following files


-- \i sensor_model_1.sql
-- \i sensor_model_2.sql
-- \i sensor_model_3.sql
-- \i sensor_model_4.sql

-- setup continuous aggregates

-- \i caggs.sql

-- setup compression policies
-- \i compression.sql
