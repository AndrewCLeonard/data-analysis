WITH entities_base AS (
    SELECT
        e.id AS entity_id,
        e.interact_id,
        e.first_name,
        e.middle_name,
        e.last_name,
        e.nickname,
        ce.latest_assessment_level,
        c."name" AS campaign_name,
        c.id AS campaign_id
    FROM
        entities e
        JOIN campaigns_entities ce ON ce.entity_id = e.id
        JOIN campaigns c ON c.id = ce.campaign_id
    WHERE
        ce.campaign_id IN (
            -- Plant campaigns redacted for portfolio
            [CAMPAIGN_ID_1],
            [CAMPAIGN_ID_2],
            [CAMPAIGN_ID_3],
            [CAMPAIGN_ID_4],
            [CAMPAIGN_ID_5],
            [CAMPAIGN_ID_6],
            [CAMPAIGN_ID_7],
            [CAMPAIGN_ID_8]
        )
),
-- =====================================================================
tag_current AS (
    SELECT
        tl.taggable_id AS entity_id,
        t.tag_category_id,
        t.name AS tag_name,
        tl.updated_at,
        tl.created_by AS user_id
    FROM
        taggable_logbook tl
        JOIN tags t ON t.id = tl.tag_id
    WHERE
        tl.deleted_at IS NULL
        AND t.tag_category_id IN (
            [DO_NOT_CONTACT_TAG_CATEGORY_ID],
            [NOT_IN_UNIT_TAG_CATEGORY_ID]
        )
        AND tl.campaign_id IN (
            [CAMPAIGN_ID_1],
            [CAMPAIGN_ID_2],
            [CAMPAIGN_ID_3],
            [CAMPAIGN_ID_4],
            [CAMPAIGN_ID_5],
            [CAMPAIGN_ID_6],
            [CAMPAIGN_ID_7],
            [CAMPAIGN_ID_8]
        )
),
-- =====================================================================
work_info AS (
    SELECT
        entity_id,
        -- do not contact ----------------------------------------------
        MAX(tag_name) FILTER (
            WHERE
                tag_category_id = [DO_NOT_CONTACT_TAG_CATEGORY_ID]
        ) AS do_not_contact,
        -- not in unit -------------------------------------------------
        MAX(tag_name) FILTER (
            WHERE
                tag_category_id = [NOT_IN_UNIT_TAG_CATEGORY_ID]
        ) AS not_in_unit
    FROM
        tag_current
    GROUP BY
        entity_id
),
entity_emails AS (
    SELECT
        owner_id AS entity_id,
        MAX(email) FILTER (
            WHERE
                rn = 1
        ) AS email_1,
        MAX(email) FILTER (
            WHERE
                rn = 2
        ) AS email_2,
        MAX(email) FILTER (
            WHERE
                rn = 3
        ) AS email_3,
        MAX(email) FILTER (
            WHERE
                rn = 4
        ) AS email_4,
        MAX(email) FILTER (
            WHERE
                rn = 5
        ) AS email_5
    FROM
        (
            SELECT
                owner_id,
                email,
                ROW_NUMBER() OVER (
                    PARTITION BY owner_id
                    ORDER BY
                        MAX(created_at) DESC
                ) AS rn
            FROM
                emails
            WHERE
                emails.status != 'bad'
                AND owner_id IN (
                    SELECT
                        entity_id
                    FROM
                        entities_base
                )
            GROUP BY
                owner_id,
                email
        ) ranked
    GROUP BY
        owner_id
),
-- =====================================================================
entity_phones AS (
    SELECT
        owner_id AS entity_id,
        MAX(phone) FILTER (
            WHERE
                rn = 1
        ) AS phone_1,
        MAX(phone) FILTER (
            WHERE
                rn = 2
        ) AS phone_2,
        MAX(phone) FILTER (
            WHERE
                rn = 3
        ) AS phone_3,
        MAX(phone) FILTER (
            WHERE
                rn = 4
        ) AS phone_4,
        MAX(phone) FILTER (
            WHERE
                rn = 5
        ) AS phone_5
    FROM
        (
            SELECT
                owner_id,
                number AS phone,
                ROW_NUMBER() OVER (
                    PARTITION BY owner_id
                    ORDER BY
                        MAX(created_at) DESC
                ) AS rn
            FROM
                phone_numbers
            WHERE
                phone_numbers.status != 'bad'
                AND owner_id IN (
                    SELECT
                        entity_id
                    FROM
                        entities_base
                )
            GROUP BY
                owner_id,
                number
        ) ranked
    GROUP BY
        owner_id
)
-- =====================================================================
SELECT
    eb.entity_id,
    eb.interact_id,
    eb.first_name,
    eb.last_name,
    eb.campaign_name,
    eb.campaign_id,
    eb.latest_assessment_level,
    ee.email_1,
    ee.email_2,
    ee.email_3,
    ee.email_4,
    ep.phone_1,
    ep.phone_2,
    ep.phone_3,
    ep.phone_4
FROM
    entities_base eb
    LEFT JOIN work_info wi ON wi.entity_id = eb.entity_id
    LEFT JOIN entity_emails ee ON ee.entity_id = eb.entity_id
    LEFT JOIN entity_phones ep ON ep.entity_id = eb.entity_id
WHERE
    wi.not_in_unit IS NULL
    AND wi.do_not_contact IS NULL
    AND eb.latest_assessment_level != 4
ORDER BY
    eb.campaign_name,
    eb.last_name,
    eb.first_name
