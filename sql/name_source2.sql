-- retrieve all name info for the campaign
WITH base AS (
    SELECT
        e.interact_id,
        e.first_name,
        e.middle_name,
        e.last_name,
        e.nickname,
        e.suffix
    FROM
        entities e
        JOIN campaigns_entities ce ON e.id = ce.entity_id
    WHERE
        ce.campaign_id = [CAMPAIGN_ID]
),
-- create values for first & last names currently stored in Action Builder ------------------------------
first_last AS (
    SELECT
        b.interact_id,
        REGEXP_REPLACE(LOWER(TRIM(b.first_name)), '[^a-z]', '', 'g') || regexp_replace(LOWER(TRIM(b.last_name)), '[^a-z]', '', 'g') AS simplified_name,
        b.first_name,
        b.last_name,
        b.suffix,
        CONCAT_WS(' ', b.first_name, b.last_name) AS name_key,
        1 AS priority
    FROM
        base b
    WHERE
        b.first_name IS NOT NULL
        AND b.last_name IS NOT NULL
),
-- create values for nickname & last names currently stored in Action Builder ------------------------------
nickname_last AS (
    SELECT
        b.interact_id,
        REGEXP_REPLACE(LOWER(TRIM(b.nickname)), '[^a-z]', '', 'g') || regexp_replace(LOWER(TRIM(b.last_name)), '[^a-z]', '', 'g') AS simplified_name,
        b.first_name,
        b.last_name,
        b.suffix,
        CONCAT_WS(' ', b.nickname, b.last_name) AS name_key,
        2 AS priority
    FROM
        base b
    WHERE
        b.nickname IS NOT NULL
        AND b.last_name IS NOT NULL
),
-- create values for names with suffixes ------------------------------
name_suffixes_included AS (
    -- first_name + suffix ----------
    SELECT
        b.interact_id,
        REGEXP_REPLACE(LOWER(TRIM(b.first_name)), '[^a-z]', '', 'g') || regexp_replace(LOWER(TRIM(b.last_name)), '[^a-z]', '', 'g') || regexp_replace(LOWER(TRIM(b.suffix)), '[^a-z]', '', 'g') AS simplified_name,
        b.first_name,
        b.last_name,
        b.suffix,
        CONCAT_WS(' ', b.first_name, b.last_name, b.suffix) AS name_key,
        3 AS priority
    FROM
        base b
    WHERE
        b.suffix IS NOT NULL
        AND b.first_name IS NOT NULL
        AND b.last_name IS NOT NULL
    UNION
    ALL -- nickname + suffix ----------
    SELECT
        b.interact_id,
        REGEXP_REPLACE(LOWER(TRIM(b.nickname)), '[^a-z]', '', 'g') || regexp_replace(LOWER(TRIM(b.last_name)), '[^a-z]', '', 'g') || regexp_replace(LOWER(TRIM(b.suffix)), '[^a-z]', '', 'g') AS simplified_name,
        b.first_name,
        b.last_name,
        b.suffix,
        CONCAT_WS(' ', b.nickname, b.last_name, b.suffix) AS name_key,
        4 AS priority
    FROM
        base b
    WHERE
        b.suffix IS NOT NULL
        AND b.nickname IS NOT NULL
        AND b.last_name IS NOT NULL
),
-- combine the proper first names and nicknames together ------------------------------
all_names AS (
    SELECT
        interact_id,
        simplified_name,
        first_name,
        last_name,
        suffix,
        name_key,
        priority
    FROM
        first_last
    UNION
    ALL
    SELECT
        interact_id,
        simplified_name,
        first_name,
        last_name,
        suffix,
        name_key,
        priority
    FROM
        nickname_last
    UNION
    ALL
    SELECT
        interact_id,
        simplified_name,
        first_name,
        last_name,
        suffix,
        name_key,
        priority
    FROM
        name_suffixes_included
),
-- add ranking to select one row per name appearance and entity ------------------------------
ranked AS (
    SELECT
        interact_id,
        simplified_name,
        first_name,
        last_name,
        suffix,
        name_key,
        priority,
        ROW_NUMBER() OVER (
            PARTITION BY interact_id,
            simplified_name
            ORDER BY
                priority,
                name_key
        ) AS rn
    FROM
        all_names
    WHERE
        simplified_name IS NOT NULL
        AND simplified_name <> ''
)
SELECT
    interact_id,
    simplified_name,
    concat_ws(' | ', name_key, interact_id) AS match_key,
    last_name,
    first_name,
    COUNT(*) OVER (PARTITION BY interact_id) AS abid_count
FROM
    ranked
WHERE
    rn = 1
ORDER BY
    last_name,
    interact_id,
    simplified_name,
    match_key
