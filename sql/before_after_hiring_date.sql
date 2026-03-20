-- ===========================================
-- HIRING DATE & STATUS REPORT FOR CAMPAIGN ####
-- ===========================================
-- GOAL:
-- 1. Determine the best-guess hire date for each person in Campaign 683
--    - Prefer self-reported hire date from "auth card" tag (tag_id = 16432)
--    - Otherwise, use the date the person was added to Action Builder (campaigns_entities.created_at)
-- 2. Classify whether the hire date was before or after a chosen cutoff date (e.g., petition filing date)
-- 3. Include "Not In Unit" tags for people who are no longer in the unit
-- ===========================================
-- -------------------------------------------
-- PARAMETER: Change this to update the cutoff date
-- Example: '2025-04-01' to compare against April 1, 2025
-- -------------------------------------------
WITH params AS (
    SELECT
        DATE '2025-01-06' AS cutoff_date
),
-- -------------------------------------------
-- 1. Base table: when each person was added to the campaign
-- -------------------------------------------
ce_created_at AS (
    SELECT
        e.id,
        e.first_name,
        e.last_name,
        ce.created_at :: date AS ce_tag_created_at
    FROM
        entities e
        JOIN campaigns_entities ce ON ce.entity_id = e.id
    WHERE
        ce.campaign_id = [CAMPAIGN_ID]
    ORDER BY
        ce.created_at ASC
),
-- -------------------------------------------
-- 2. Hire date from "auth card" global note
-- (tag_id = #### is the "auth card hire date" field)
-- -------------------------------------------
hire_date_available AS (
    SELECT
        e.last_name,
        e.first_name,
        gn.text :: date AS hire_date,
        e.interact_id,
        e.id
    FROM
        entities e
        JOIN campaigns_entities ce ON ce.entity_id = e.id
        JOIN taggable_logbook tl ON tl.taggable_id = e.id
        JOIN tags t ON t.id = tl.tag_id
        LEFT JOIN global_notes gn ON gn.owner_id = tl.id
    WHERE
        ce.campaign_id = [CAMPAIGN_ID]
        AND t.id = [TAG_ID]  
        AND tl.deleted_at IS NULL
    ORDER BY
        hire_date ASC
),
-- -------------------------------------------
-- 3. Not In Unit tags (tag_category_id = ####)
-- Will have names like "Fired, Quit, or Not on latest list"
-- -------------------------------------------
not_in_unit_tags AS (
    SELECT
        e.interact_id,
        e.id,
        e.first_name,
        e.last_name,
        t.name AS tag_name,
        tl.created_at :: date AS not_in_unit_date
    FROM
        tags t
        JOIN taggable_logbook tl ON tl.tag_id = t.id
        JOIN entities e ON e.id = tl.taggable_id
    WHERE
        t.tag_category_id = 17
        AND tl.campaign_id = 683
        AND tl.deleted_at IS NULL
) -- -------------------------------------------
-- 4. Final report:
-- Merge all sources and classify before/after cutoff date
-- -------------------------------------------
SELECT
    ceca.last_name,
    ceca.first_name,
    -- Best-guess hire date: prefer auth card date, else AB join date
    CASE
        WHEN hda.hire_date IS NOT NULL THEN hda.hire_date
        ELSE ceca.ce_tag_created_at
    END AS hire_date_best_guess,
    -- Before/after the chosen cutoff date
    CASE
        WHEN (
            CASE
                WHEN hda.hire_date IS NOT NULL THEN hda.hire_date
                ELSE ceca.ce_tag_created_at
            END
        ) < params.cutoff_date THEN 'Before Filing'
        ELSE 'After Filing'
    END AS hired_before_or_after_filing,
    -- Which source was used for hire date
    CASE
        WHEN hda.hire_date IS NOT NULL THEN 'auth_card'
        ELSE 'added_to_AB_date'
    END AS hire_date_source,
    -- "Not In Unit" tag (if present)
    niut.tag_name AS not_in_unit_tag,
    -- Extra debugging/trace columns
    ceca.ce_tag_created_at AS ce_tag_created_at,
    hda.hire_date AS self_reported_auth_card_hire_date,
    ceca.id
FROM
    ce_created_at AS ceca
    LEFT JOIN hire_date_available AS hda ON hda.id = ceca.id
    LEFT JOIN not_in_unit_tags niut ON niut.id = ceca.id
    CROSS JOIN params;

-- This makes cutoff_date available everywhere
