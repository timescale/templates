-- Script to adjust the configuration for top_websites_tracking
-- This increases the min_hits_threshold to reduce the number of candidates

-- Step 1: Check current configuration
SELECT 'Current configuration:' AS check;
SELECT id, min_hits_threshold, max_longterm_entries 
FROM top_websites_config;

-- Step 2: Update the min_hits_threshold to a more reasonable value
-- A higher threshold means fewer domains will qualify as candidates
UPDATE top_websites_config
SET min_hits_threshold = 20,  -- Increase from 1 to 20
    updated_at = now();

-- Step 3: Verify the updated configuration
SELECT 'Updated configuration:' AS check;
SELECT id, min_hits_threshold, max_longterm_entries 
FROM top_websites_config;

-- Step 4: Clean up any excess domains from previous low threshold
-- This removes domains with low hit counts from the longterm storage
DELETE FROM top_websites_longterm
WHERE total_hits < 50  -- Adjust based on your traffic patterns
AND times_elected < 3; -- Keep domains that have been elected multiple times

-- Step 5: Check the count of domains after cleanup
SELECT 'Domains before cleanup:' AS check, 
       (SELECT COUNT(*) FROM top_websites_longterm WHERE times_elected < 3 AND total_hits < 50) AS count_to_remove;
       
SELECT 'Domains after cleanup:' AS check, 
       COUNT(*) AS remaining_domains 
FROM top_websites_longterm;

-- Step 6: Manually trigger the next election cycle with the new threshold
SELECT 'Re-running election process with new threshold:' AS operation;
SELECT populate_website_candidates();
SELECT elect_top_websites(); 