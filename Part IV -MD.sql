-- MAJI NDOGO WATER PROJECT (Part IV)

-- CHARTING THE COURSE FOR MAJI NDOGO'S WATER FUTURE

-- 1. Joining Pieces Together

-- This view assembles data from different tables into one to simplify analysis
CREATE VIEW combined_analysis_table AS 
	SELECT 	l.province_name,
			l.town_name,
			ws.type_of_water_source AS source_type,
			l.location_type,
			number_of_people_served AS people_served,
			v.time_in_queue,
			wp.results
	FROM 	visits AS v
	LEFT JOIN well_pollution AS wp
		ON v.source_id = wp.source_id
	JOIN 	location AS l
		ON v.location_id = l.location_id
	JOIN 	water_source AS ws
		ON v.source_id = ws.source_id
	WHERE v.visit_count = 1;

-- 2. Analysing Sources

-- (a). Are there any specific provinces where some sources are more abundant?
WITH province_totals AS( -- This CTE calculates the sum of all the people surveyed grouped by province.
	SELECT 	province_name,
			SUM(people_served) AS total_people_served
	FROM combined_analysis_table
	GROUP BY province_name
) 	-- This main query selects the province names; creates columns for each source type with CASE statements;
	-- sums up population for each province, and calculate percentages using `province_totals` table.
SELECT 	cat.province_name,
		ROUND(SUM(CASE WHEN source_type = 'river' THEN people_served ELSE 0 END) * 100 / pt.total_people_served, 0) AS river,
        ROUND(SUM(CASE WHEN source_type = 'well' THEN people_served ELSE 0 END) * 100 / pt.total_people_served, 0) AS well,
        ROUND(SUM(CASE WHEN source_type = 'shared_tap' THEN people_served ELSE 0 END) * 100 / pt.total_people_served, 0) AS shared_tap,
        ROUND(SUM(CASE WHEN source_type = 'tap_in_home_broken' THEN people_served ELSE 0 END) * 100 / pt.total_people_served, 0) AS tap_in_home_broken,
        ROUND(SUM(CASE WHEN source_type = 'tap_in_home' THEN people_served ELSE 0 END) * 100 / pt.total_people_served, 0) AS tap_in_home
FROM combined_analysis_table AS cat
JOIN province_totals AS pt
	ON cat.province_name = pt.province_name
GROUP BY cat.province_name
ORDER BY cat.province_name;
	-- Sokoto has a significantly larger population of people drinking river water compared to other provinces.
    -- The majority of water from Amanzi comes from taps, but about half of these home taps don't work because the infrastructure is broken.
    
-- (b). Are there any specific towns where some sources are more abundant?
-- Since there are two Harare towns, group by province_name and town_name
DROP TABLE IF EXISTS town_aggregated_water_access;
CREATE TEMPORARY TABLE town_aggregated_water_access AS -- Creates a temporary table for easy reference.
WITH town_totals AS( -- This CTE calculates the sum of all the people surveyed grouped by town.
	SELECT 	province_name,
			town_name,
            SUM(people_served) AS total_people_served
	FROM combined_analysis_table
	GROUP BY province_name, town_name
) 	-- This main query selects the province and town names; creates columns for each source type with CASE statements;
	-- sums up population for each town, and calculate percentages using `town_totals` table.
SELECT 	cat.province_name,
		cat.town_name,
        ROUND(SUM(CASE WHEN source_type = 'river' THEN people_served ELSE 0 END) * 100 / tt.total_people_served, 0) AS river,
        ROUND(SUM(CASE WHEN source_type = 'well' THEN people_served ELSE 0 END) * 100 / tt.total_people_served, 0) AS well,
        ROUND(SUM(CASE WHEN source_type = 'shared_tap' THEN people_served ELSE 0 END) * 100 / tt.total_people_served, 0) AS shared_tap,
        ROUND(SUM(CASE WHEN source_type = 'tap_in_home_broken' THEN people_served ELSE 0 END) * 100 / tt.total_people_served, 0) AS tap_in_home_broken,
        ROUND(SUM(CASE WHEN source_type = 'tap_in_home' THEN people_served ELSE 0 END) * 100 / tt.total_people_served, 0) AS tap_in_home
FROM combined_analysis_table AS cat
JOIN town_totals AS tt -- Since the town names are not unique, we have to join on a composite key
	ON cat.province_name = tt.province_name AND cat.town_name = tt.town_name
GROUP BY cat.province_name, cat.town_name
ORDER BY cat.province_name, cat.town_name;

-- View the `town_aggregated_water_access` table
SELECT 	*
FROM 	town_aggregated_water_access;

-- (c). Which town has the highest ratio of people who have taps, but have no running water?
SELECT 	province_name,
		town_name,
        ROUND(tap_in_home_broken/(tap_in_home_broken + tap_in_home) * 100, 0) AS pct_broken_taps
FROM 	town_aggregated_water_access
ORDER BY 3 DESC;

-- 3. Summary Report

/*
Plan of Action:
-> Focus efforts on improving the water sources that affect the most people. 
	Most people will benefit if the shared taps are improved first.
-> Wells are a good source of water, but many are contaminated. 
	Fixing this will benefit a lot of people.
-> Fixing existing infrastructure will help many people. 
	If they have running water again, they won't have to queue, thereby shorting queue times.
-> Installing taps in homes will stretch resources too thin. 
	So for now, if the queue times are low, don't improve that source.
-> Most water sources are in rural areas. 
	This means repairs/upgrades in rural areas where road conditions, supplies, and labour are harder challenges to overcome.
*/

-- 4. Practical Plan

-- This query creates the `project_progress` table:
CREATE TABLE project_progress (
	project_id SERIAL PRIMARY KEY, -- Unique key for sources in case the same source is visited  more than once in the future.
	source_id VARCHAR(20) NOT NULL REFERENCES water_source(source_id) ON DELETE CASCADE ON UPDATE CASCADE, -- Foreign key from `water_source` table.
	address VARCHAR(50), -- Street address
	town VARCHAR(30),
	province VARCHAR(30),
	source_type VARCHAR(50), -- The type of water source
	improvement VARCHAR(50), -- What the engineers should do at that place
	source_status VARCHAR(50) DEFAULT 'Backlog' CHECK (Source_status IN ('Backlog', 'In progress', 'Complete')),
	-- Limit the type of information engineers can provide: By DEFAULT all projects are in the "Backlog" which is like a TODO list.
	-- CHECK() ensures only those three options will be accepted. This helps to maintain clean data.
	date_of_completion DATE, -- Engineers will add this the day the source has been upgraded.
	comments TEXT -- Engineers can leave comments. Use a TEXT type that has no limit on char length
);

-- Create a table where the respective teams have the information needed to fix, upgrade and/or repair water sources.
-- Build up the `project_progress` query then insert into the table.
INSERT INTO project_progress (
    source_id, 
    address, 
    town, 
    province, 
    source_type, 
    improvement, 
    source_status, 
    date_of_completion, 
    comments
)
SELECT
    ws.source_id,
    l.address,
    l.town_name,
    l.province_name,
    ws.type_of_water_source,
    CASE 
        WHEN ws.type_of_water_source = 'river' THEN 'Drill well'
        WHEN wp.results LIKE '%Chemical%' THEN 'Install RO filter'
        WHEN wp.results LIKE '%Biological%' THEN 'Install UV and RO filter'
        WHEN ws.type_of_water_source = 'shared_tap' AND v.time_in_queue >= 30 THEN CONCAT('Install ', FLOOR(v.time_in_queue / 30), ' tap(s)')
        -- Using FLOOR() rounds down everything below 59 mins to one extra tap, and if the queue is 60 min, 2 taps will be installed, and so on.
        WHEN ws.type_of_water_source = 'tap_in_home_broken' THEN 'Diagnose local infrastructure'
        ELSE NULL 
    END AS improvement,
    'Backlog' AS source_status,  -- Default status for new projects
    NULL AS date_of_completion,  -- Default value for projects not completed yet
    'No comments yet' AS comments  -- Default comment placeholder
FROM 	water_source AS ws
LEFT JOIN well_pollution AS wp
    ON ws.source_id = wp.source_id
INNER JOIN visits AS v
    ON ws.source_id = v.source_id
INNER JOIN location AS l
    ON l.location_id = v.location_id
WHERE v.visit_count = 1 AND (v.time_in_queue >= 30 OR wp.results != 'Clean' OR ws.type_of_water_source IN ('tap_in_home_broken', 'river'));

-- View the `project_progress` table.
SELECT 	* 
FROM 	project_progress;	