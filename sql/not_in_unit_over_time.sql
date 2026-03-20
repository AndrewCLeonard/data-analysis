-- Create a column of weekly start dates (Mondays) from 8/15/2024 through today.
-- This ensures every week appears in the final result, even if no workers were moved out during that week.
WITH weeks AS (
    SELECT
        generate_series(
            DATE_TRUNC('week', DATE '2024-08-15'),
            CURRENT_DATE,
            INTERVAL '1 week'
        ) :: date AS week_start
),
-- The first time each worker signed an authorization card.
first_signers AS (
    SELECT
        e.interact_id AS abid,
        e.id,
        MIN(gn."text" :: date) AS card_signing_date
    FROM
        tags t
        JOIN taggable_logbook tl ON tl.tag_id = t.id
        JOIN entities e ON e.id = tl.taggable_id
        JOIN global_notes gn ON tl.id = gn.owner_id
    WHERE
        t.tag_category_id =  [AUTH_CARD_TAG_CATEGORY_ID] -- Authorization Card tag
        AND tl.campaign_id = [CAMPAIGN_ID]
        AND tl.deleted_at IS NULL
    GROUP BY
        abid,
        e.id
),
-- Track when each worker was tagged as "Not In Unit" and whether they had previously signed a card.
-- Joins to first_signers to include the first card signing date (if any).
not_in_unit_tags AS (
    SELECT
        tl.taggable_id,
        -- when the worker was marked "Not In Unit"
        tl.created_at :: date AS not_in_unit_tag_date,
        -- takes the date the tag was created and finds the Monday before
        DATE_TRUNC('week', tl.created_at) :: date AS week_tagged_not_in_unit,
        -- the first date that a worker signed a card
        fs.card_signing_date
    FROM
        tags t
        JOIN taggable_logbook tl ON t.id = tl.tag_id
        LEFT JOIN first_signers fs ON fs.id = tl.taggable_id
    WHERE
        t.tag_category_id =  [NOT_IN_UNIT_TAG_CATEGORY_ID]rr -- Not In Unit tag
        AND tl.campaign_id = [CAMPAIGN_ID]
        AND tl.deleted_at IS NULL
),
-- Total count of all workers marked "Not In Unit" per week.
weekly_counts AS (
    SELECT
        week_tagged_not_in_unit,
        COUNT(DISTINCT taggable_id) AS not_in_unit_count
    FROM
        not_in_unit_tags
    GROUP BY
        week_tagged_not_in_unit
),
-- Workers who signed a card before being moved out of unit.
with_signed_before_removal AS (
    SELECT
        *
    FROM
        not_in_unit_tags
    WHERE
        card_signing_date IS NOT NULL
        AND not_in_unit_tag_date > card_signing_date
),
-- Workers who either never signed a card OR were moved out before signing.
with_no_card_or_removed_first AS (
    SELECT
        *
    FROM
        not_in_unit_tags
    WHERE
        card_signing_date IS NULL
        OR not_in_unit_tag_date <= card_signing_date
),
-- Count per week of workers who signed a card first, then were removed from unit.
weekly_signed_then_removed AS (
    SELECT
        DATE_TRUNC('week', not_in_unit_tag_date) :: date AS week_tagged_not_in_unit,
        COUNT(DISTINCT taggable_id) AS signed_then_removed_count
    FROM
        with_signed_before_removal
    GROUP BY
        1
),
-- Count per week of workers who were removed without signing a card first.
weekly_removed_no_card AS (
    SELECT
        DATE_TRUNC('week', not_in_unit_tag_date) :: date AS week_tagged_not_in_unit,
        COUNT(DISTINCT taggable_id) AS removed_without_card_count
    FROM
        with_no_card_or_removed_first
    GROUP BY
        1
)
/* Combined query: weekly summary showing both categories side-by-side.
 * Uses LEFT JOIN on `weeks` to ensure every week is represented, even with zero counts.
 */
SELECT
    w.week_start,
    COALESCE(wsr.signed_then_removed_count, 0) AS signed_then_removed,
    COALESCE(wrc.removed_without_card_count, 0) AS removed_without_card
FROM
    weeks w
    LEFT JOIN weekly_signed_then_removed wsr ON w.week_start = wsr.week_tagged_not_in_unit
    LEFT JOIN weekly_removed_no_card wrc ON w.week_start = wrc.week_tagged_not_in_unit
ORDER BY
    w.week_start;
