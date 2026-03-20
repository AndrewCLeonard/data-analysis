-- Wide campaign report joining worker demographics, department, shift,
-- work area, and authorization card status.
WITH work_area_tags AS (
    SELECT
        tl.taggable_id,
        t.name AS work_area,
        tl.updated_at
    FROM
        taggable_logbook tl
        JOIN tags t ON t.id = tl.tag_id
    WHERE
        tl.campaign_id = [CAMPAIGN_ID]
        AND t.tag_category_id = [WORK_AREA_TAG_CATEGORY_ID]
        AND tl.deleted_at IS NULL
),
department_tags AS (
    SELECT
        tl.taggable_id,
        t.name AS department,
        tl.updated_at
    FROM
        taggable_logbook tl
        JOIN tags t ON t.id = tl.tag_id
    WHERE
        tl.campaign_id = [CAMPAIGN_ID]
        AND t.tag_category_id = [DEPARTMENT_TAG_CATEGORY_ID]
        AND tl.deleted_at IS NULL
),
classification_tags AS (
    SELECT
        tl.taggable_id,
        t.name AS classification,
        tl.updated_at
    FROM
        taggable_logbook tl
        JOIN tags t ON t.id = tl.tag_id
    WHERE
        tl.campaign_id = [CAMPAIGN_ID]
        AND t.tag_category_id = [CLASSIFICATION_TAG_CATEGORY_ID]
        AND tl.deleted_at IS NULL
),
not_in_unit_tags AS (
    SELECT
        tl.taggable_id,
        t.name AS not_in_unit,
        tl.updated_at AS niu_updated_at
    FROM
        taggable_logbook tl
        JOIN tags t ON t.id = tl.tag_id
    WHERE
        tl.campaign_id = [CAMPAIGN_ID]
        AND t.tag_category_id = [NOT_IN_UNIT_TAG_CATEGORY_ID]
        AND tl.deleted_at IS NULL
),
shift_tags AS (
    SELECT
        tl.taggable_id,
        t.name AS shift,
        tl.updated_at
    FROM
        taggable_logbook tl
        JOIN tags t ON t.id = tl.tag_id
    WHERE
        tl.campaign_id = [CAMPAIGN_ID]
        AND t.tag_category_id = [SHIFT_TAG_CATEGORY_ID]
        AND tl.deleted_at IS NULL
),
subprocess_tags AS (
    SELECT
        tl.taggable_id,
        t.name AS subprocess,
        tl.updated_at
    FROM
        taggable_logbook tl
        JOIN tags t ON t.id = tl.tag_id
    WHERE
        tl.campaign_id = [CAMPAIGN_ID]
        AND t.tag_category_id = [SUBPROCESS_TAG_CATEGORY_ID]
        AND tl.deleted_at IS NULL
),
subprocess_area_tags AS (
    SELECT
        tl.taggable_id,
        t.name AS subprocess_area,
        tl.updated_at
    FROM
        taggable_logbook tl
        JOIN tags t ON t.id = tl.tag_id
    WHERE
        tl.campaign_id = [CAMPAIGN_ID]
        AND t.tag_category_id = [SUBPROCESS_AREA_TAG_CATEGORY_ID]
        AND tl.deleted_at IS NULL
),
auth_cards AS (
    SELECT
        e.id AS person_id,
        MAX(gn.text :: date) AS latest_card_date
    FROM
        tags t
        JOIN taggable_logbook tl ON tl.tag_id = t.id
        JOIN entities e ON e.id = tl.taggable_id
        JOIN global_notes gn ON tl.id = gn.owner_id
    WHERE
        t.tag_category_id = [AUTH_CARD_TAG_CATEGORY_ID]
        AND tl.campaign_id = [CAMPAIGN_ID]
        AND tl.deleted_at IS NULL
    GROUP BY
        person_id
),
entities_base AS (
    SELECT
        e.id AS entity_id,
        e.interact_id,
        e.first_name,
        e.last_name,
        e.middle_name,
        e.nickname,
        ce.latest_assessment_level
    FROM
        entities e
        JOIN campaigns_entities ce ON e.id = ce.entity_id
    WHERE
        ce.campaign_id = [CAMPAIGN_ID]
)
SELECT
    eb.interact_id,
    eb.entity_id,
    eb.first_name,
    eb.last_name,
    eb.middle_name,
    eb.nickname,
    d.department,
    wa.work_area,
    c.classification,
    sp.subprocess,
    spa.subprocess_area,
    s.shift,
    eb.latest_assessment_level,
    niu.not_in_unit,
    CAST(niu.niu_updated_at AS DATE),
    CONCAT_WS(
        ' | ',
        CONCAT_WS(' ', eb.first_name, eb.last_name),
        d.department,
        wa.work_area,
        s.shift,
        eb.entity_id
    ) AS unique_key_end,
    ac.latest_card_date,
    CONCAT_WS(', ', eb.last_name, eb.first_name),
    eb.interact_id AS interact_id_for_lookups
FROM
    entities_base eb
    LEFT JOIN work_area_tags wa ON eb.entity_id = wa.taggable_id
    LEFT JOIN department_tags d ON eb.entity_id = d.taggable_id
    LEFT JOIN classification_tags c ON eb.entity_id = c.taggable_id
    LEFT JOIN not_in_unit_tags niu ON eb.entity_id = niu.taggable_id
    LEFT JOIN shift_tags s ON eb.entity_id = s.taggable_id
    LEFT JOIN subprocess_tags sp ON eb.entity_id = sp.taggable_id
    LEFT JOIN subprocess_area_tags spa ON eb.entity_id = spa.taggable_id
    LEFT JOIN auth_cards ac ON eb.entity_id = ac.person_id
ORDER BY
    eb.last_name,
    eb.first_name
