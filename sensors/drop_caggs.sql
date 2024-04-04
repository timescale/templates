
-- Drop the materialized views for the continuous aggregates
-- While we can't find a dynamic data generation

DROP materialized view if exists stats_agg_1M_sample CASCADE;
DROP materialized view if exists stats_agg_1d_sample CASCADE;
DROP materialized view if exists stats_agg_1h_sample CASCADE;
DROP materialized view if exists stats_agg_1m_sample CASCADE;
