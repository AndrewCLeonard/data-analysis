# SQL Portfolio — Labor Organizing Data Analysis

Production queries written against PostgreSQL and ClickHouse databases 
supporting 50+ labor organizing campaigns.

## Highlighted Queries

**not_in_unit_over_time.sql**
Weekly trend analysis tracking worker attrition by union support status. 
Uses a date spine to preserve weeks with zero activity, classifying workers 
who signed authorization cards before vs. after removal from the bargaining unit.

**before_after_hiring_date.sql**
Hire date classification report using a configurable cutoff date parameter. 
Resolves hire dates from multiple sources with documented fallback logic.

**multi_plant_combined_query.sql**
Cross-campaign contact report spanning 8 plants. Pivots multiple phone 
numbers and emails per person using window functions, with filtering for 
active, contactable workers only.

## Additional Queries

- `name_source_2.sql` — Priority-ranked name matching including nicknames and suffixes
- `card_signings_over_time.sql` — Wide campaign report pulling multiple tag dimensions
