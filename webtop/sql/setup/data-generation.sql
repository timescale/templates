-- Data Generation Functions for Top Websites Tracker
-- This file contains all functions related to generating synthetic data

-- Drop existing functions first
DROP FUNCTION IF EXISTS generate_log_data(text, integer);
DROP FUNCTION IF EXISTS schedule_data_generation();
DROP FUNCTION IF EXISTS schedule_top_websites_generation();
DROP FUNCTION IF EXISTS schedule_random_websites_generation();
DROP PROCEDURE IF EXISTS generate_log_data_job(int, jsonb);

-- Procedure to generate synthetic log data every second
CREATE OR REPLACE PROCEDURE generate_log_data_job(job_id_param int, config_param jsonb) 
LANGUAGE plpgsql AS $$
DECLARE
    amount INTEGER;
    domain TEXT;
    use_specific_domain BOOLEAN;
    growth_rate INTEGER;
    current_amount INTEGER;
    burst_probability FLOAT;
    burst_multiplier INTEGER;
    final_amount INTEGER;
BEGIN
    -- Get configuration
    amount := (config_param->>'amount')::INTEGER;
    domain := config_param->>'domain';
    use_specific_domain := COALESCE((config_param->>'use_specific_domain')::BOOLEAN, false);
    growth_rate := COALESCE((config_param->>'growth_rate')::INTEGER, 0);
    burst_probability := COALESCE((config_param->>'burst_probability')::FLOAT, 0);
    burst_multiplier := COALESCE((config_param->>'burst_multiplier')::INTEGER, 1);
    
    -- If this is a growing/declining traffic pattern, adjust the amount
    IF growth_rate != 0 AND job_id_param != 0 THEN
        -- Get the current amount from the job's config
        SELECT (j.config->>'amount')::INTEGER INTO current_amount
        FROM timescaledb_information.jobs j
        WHERE j.job_id = job_id_param;
        
        -- Update the amount for next run
        amount := current_amount + growth_rate;
        
        -- Update the job's config using alter_job
        PERFORM alter_job(
            job_id_param,
            config => jsonb_build_object(
                'amount', amount,
                'domain', domain,
                'use_specific_domain', use_specific_domain,
                'growth_rate', growth_rate,
                'burst_probability', burst_probability,
                'burst_multiplier', burst_multiplier
            )
        );
    END IF;

    -- Calculate final amount considering bursts
    IF random() < burst_probability THEN
        final_amount := amount * burst_multiplier;
        RAISE NOTICE 'Traffic burst! Multiplying amount by %x (% -> %)', burst_multiplier, amount, final_amount;
    ELSE
        final_amount := amount;
    END IF;
    
    -- Generate logs
    IF use_specific_domain THEN
        -- Generate logs for specific domain
        INSERT INTO logs (time, domain)
        SELECT 
            now() - (random() * interval '1 minute'),
            domain
        FROM generate_series(1, final_amount);
        
        RAISE NOTICE 'Generated % log entries for % at %', final_amount, domain, now();
    ELSE
        -- Generate logs for random domains
        INSERT INTO logs (time, domain)
        SELECT 
            now() - (random() * interval '1 minute'),
            'random-domain-' || floor(random() * 1000)::text
        FROM generate_series(1, final_amount);
        
        RAISE NOTICE 'Generated % random log entries at %', final_amount, now();
    END IF;
END;
$$;

-- Function to generate test data manually
CREATE OR REPLACE FUNCTION generate_log_data(
    domain_name text DEFAULT NULL,
    amount integer DEFAULT 100
) 
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    config jsonb;
BEGIN
    IF domain_name IS NULL THEN
        -- Generate random domain data
        config := jsonb_build_object(
            'use_specific_domain', false,
            'amount', amount
        );
    ELSE
        -- Generate specific domain data
        config := jsonb_build_object(
            'use_specific_domain', true,
            'domain', domain_name,
            'amount', amount
        );
    END IF;
    
    CALL generate_log_data_job(0, config);
END;
$$;

-- Function to schedule data generation
CREATE OR REPLACE FUNCTION schedule_data_generation() 
RETURNS int[] LANGUAGE plpgsql AS $$
DECLARE
    job_ids int[] := '{}';
    job_id int;
BEGIN
    -- Schedule random data generation (runs every minute)
    SELECT add_job(
        'generate_log_data_job',
        INTERVAL '1 minute',
        config => jsonb_build_object(
            'amount', 100,
            'use_specific_domain', false
        ),
        initial_start => NOW() + INTERVAL '1 minute'
    ) INTO job_id;
    job_ids := array_append(job_ids, job_id);
    
    RETURN job_ids;
END;
$$;

-- Function to schedule data generation for top websites
CREATE OR REPLACE FUNCTION schedule_top_websites_generation() 
RETURNS int[] LANGUAGE plpgsql AS $$
DECLARE
    top_websites text[] := ARRAY['google.com', 'facebook.com', 'youtube.com', 'twitter.com', 'instagram.com'];
    job_ids int[] := '{}';
    job_id int;
    website text;
    amount int;
BEGIN
    -- Schedule a job for each top website
    FOREACH website IN ARRAY top_websites LOOP
        -- Each top website generates 50-200 hits every 10 seconds
        amount := 50 + (random() * 150)::integer;
        SELECT add_job(
            'generate_log_data_job', 
            INTERVAL '10 seconds', 
            config => jsonb_build_object(
                'use_specific_domain', true,
                'domain', website,
                'amount', amount
            )
        ) INTO job_id;
        
        job_ids := array_append(job_ids, job_id);
        RAISE NOTICE 'Scheduled top website job for % with job_id=%', website, job_id;
    END LOOP;
    
    RETURN job_ids;
END;
$$;

-- Function to schedule data generation for random websites
CREATE OR REPLACE FUNCTION schedule_random_websites_generation() 
RETURNS int[] LANGUAGE plpgsql AS $$
DECLARE
    job_ids int[] := '{}';
    job_id int;
    amount int;
BEGIN
    -- Low-traffic random domains (1-10 hits every minute)
    amount := 5 + (random() * 5)::integer;
    SELECT add_job(
        'generate_log_data_job', 
        INTERVAL '1 minute', 
        config => jsonb_build_object(
            'use_specific_domain', false,
            'domain_min', 400,
            'domain_max', 1000,
            'amount', amount
        )
    ) INTO job_id;
    job_ids := array_append(job_ids, job_id);
    RAISE NOTICE 'Scheduled low-traffic random websites job with job_id=%', job_id;
    
    -- Medium-traffic random domains (10-50 hits every 30 seconds)
    amount := 10 + (random() * 40)::integer;
    SELECT add_job(
        'generate_log_data_job', 
        INTERVAL '30 seconds', 
        config => jsonb_build_object(
            'use_specific_domain', false,
            'domain_min', 100,
            'domain_max', 399,
            'amount', amount
        )
    ) INTO job_id;
    job_ids := array_append(job_ids, job_id);
    RAISE NOTICE 'Scheduled medium-traffic random websites job with job_id=%', job_id;
    
    -- High-traffic random domains (50-100 hits every 15 seconds)
    amount := 50 + (random() * 50)::integer;
    SELECT add_job(
        'generate_log_data_job', 
        INTERVAL '15 seconds', 
        config => jsonb_build_object(
            'use_specific_domain', false,
            'domain_min', 10,
            'domain_max', 99,
            'amount', amount
        )
    ) INTO job_id;
    job_ids := array_append(job_ids, job_id);
    RAISE NOTICE 'Scheduled high-traffic random websites job with job_id=%', job_id;
    
    RETURN job_ids;
END;
$$; 