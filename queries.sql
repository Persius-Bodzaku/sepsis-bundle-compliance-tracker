-- queries.sql — Sepsis Bundle Compliance Tracker (SYNTHETIC DATA ONLY)
-- The 8 analysis queries, run in order against the bundle_compliance view.
-- Written and executed by Persius Bodzaku, October 2026.

-- ---------------------------------------------------------------- Q0: view
-- Bundle logic lives here so every query below stays simple.
DROP VIEW IF EXISTS bundle_compliance;
CREATE VIEW bundle_compliance AS
WITH elements AS (
    SELECT
        e.*,
        (julianday(sepsis_screen_positive_ts) - julianday(arrival_ts)) * 1440.0
            AS recog_delay_min,
        CASE WHEN antibiotics_admin_ts IS NOT NULL
             THEN (julianday(antibiotics_admin_ts)
                   - julianday(sepsis_screen_positive_ts)) * 1440.0 END
            AS abx_from_recog_min,
        CASE WHEN lactate_drawn_ts IS NOT NULL
              AND (julianday(lactate_drawn_ts)
                   - julianday(sepsis_screen_positive_ts)) * 1440.0 <= 60
             THEN 1 ELSE 0 END AS lactate_ok,
        CASE WHEN blood_culture_ts IS NOT NULL
              AND antibiotics_admin_ts IS NOT NULL
              AND blood_culture_ts <= antibiotics_admin_ts
             THEN 1 ELSE 0 END AS cultures_ok,
        CASE WHEN antibiotics_admin_ts IS NOT NULL
              AND (julianday(antibiotics_admin_ts)
                   - julianday(sepsis_screen_positive_ts)) * 1440.0 <= 60
             THEN 1 ELSE 0 END AS abx_ok,
        CASE WHEN (hypotensive_flag = 1
                   OR (lactate_value IS NOT NULL AND lactate_value >= 4.0))
             THEN CASE WHEN (fluids_started_ts IS NOT NULL
                             AND (julianday(fluids_started_ts)
                                  - julianday(sepsis_screen_positive_ts)) * 1440.0 <= 60
                             AND fluids_ml_per_kg >= 30)
                            OR (vasopressor_started_ts IS NOT NULL
                                AND (julianday(vasopressor_started_ts)
                                     - julianday(sepsis_screen_positive_ts)) * 1440.0 <= 60)
                       THEN 1 ELSE 0 END
             ELSE 1 END AS fluids_ok
    FROM sepsis_encounters e
)
SELECT
    elements.*,
    (lactate_ok = 1 AND cultures_ok = 1 AND abx_ok = 1 AND fluids_ok = 1)
        AS bundle_compliant
FROM elements;

-- ------------------------------------------------- Q1: overall compliance
SELECT
    COUNT(*)                                           AS encounters,
    SUM(bundle_compliant)                              AS compliant,
    ROUND(100.0 * SUM(bundle_compliant) / COUNT(*), 1) AS compliance_pct
FROM bundle_compliance;

-- ------------------------------------------- Q2: element-level compliance
SELECT 'lactate_within_1h' AS element,
       SUM(lactate_ok) AS met,
       COUNT(*) AS eligible,
       ROUND(100.0 * SUM(lactate_ok) / COUNT(*), 1) AS pct
FROM bundle_compliance
UNION ALL
SELECT 'cultures_before_abx',
       SUM(cultures_ok), COUNT(*),
       ROUND(100.0 * SUM(cultures_ok) / COUNT(*), 1)
FROM bundle_compliance
UNION ALL
SELECT 'abx_within_1h',
       SUM(abx_ok), COUNT(*),
       ROUND(100.0 * SUM(abx_ok) / COUNT(*), 1)
FROM bundle_compliance
UNION ALL
SELECT 'fluids_or_pressor_when_indicated',
       SUM(fluids_ok), COUNT(*),
       ROUND(100.0 * SUM(fluids_ok) / COUNT(*), 1)
FROM bundle_compliance
ORDER BY pct;

-- ------------------------------------------------- Q3: compliance by unit
SELECT
    unit,
    COUNT(*)                                           AS encounters,
    SUM(bundle_compliant)                              AS compliant,
    ROUND(100.0 * SUM(bundle_compliant) / COUNT(*), 1) AS compliance_pct
FROM bundle_compliance
GROUP BY unit
ORDER BY compliance_pct;

-- ------------------------------------------------ Q4: day vs night shift
SELECT
    shift,
    COUNT(*)                                           AS encounters,
    SUM(bundle_compliant)                              AS compliant,
    ROUND(100.0 * SUM(bundle_compliant) / COUNT(*), 1) AS compliance_pct
FROM bundle_compliance
GROUP BY shift;

-- ------------------------------------------------------ Q5: monthly trend
SELECT
    strftime('%Y-%m', sepsis_screen_positive_ts)       AS month,
    COUNT(*)                                           AS encounters,
    SUM(bundle_compliant)                              AS compliant,
    ROUND(100.0 * SUM(bundle_compliant) / COUNT(*), 1) AS compliance_pct
FROM bundle_compliance
GROUP BY month
ORDER BY month;

-- ------------------------------------- Q6: median time to antibiotics
WITH abx AS (
    SELECT unit, abx_from_recog_min
    FROM bundle_compliance
    WHERE abx_from_recog_min IS NOT NULL
),
ranked AS (
    SELECT unit, abx_from_recog_min,
           ROW_NUMBER() OVER (PARTITION BY unit ORDER BY abx_from_recog_min) AS rn,
           COUNT(*) OVER (PARTITION BY unit) AS cnt
    FROM abx
)
SELECT unit,
       ROUND(AVG(abx_from_recog_min), 1) AS median_abx_min
FROM ranked
WHERE rn IN ((cnt + 1) / 2, (cnt + 2) / 2)
GROUP BY unit
ORDER BY median_abx_min;

-- ------------------------------------ Q7: mortality, met vs missed bundle
SELECT
    CASE WHEN bundle_compliant = 1 THEN 'bundle_met' ELSE 'bundle_missed' END
        AS group_name,
    COUNT(*) AS encounters,
    SUM(CASE WHEN discharge_disposition = 'Expired' THEN 1 ELSE 0 END) AS deaths,
    ROUND(100.0 * SUM(CASE WHEN discharge_disposition = 'Expired' THEN 1 ELSE 0 END)
          / COUNT(*), 1) AS mortality_pct
FROM bundle_compliance
GROUP BY group_name;

-- ------------------------------------------ Q8: compliance by SOFA band
SELECT
    CASE WHEN sofa_score <= 4 THEN 'mild (0-4)'
         WHEN sofa_score <= 8 THEN 'moderate (5-8)'
         ELSE 'severe (9+)' END AS sofa_band,
    COUNT(*)                                           AS encounters,
    SUM(bundle_compliant)                              AS compliant,
    ROUND(100.0 * SUM(bundle_compliant) / COUNT(*), 1) AS compliance_pct
FROM bundle_compliance
GROUP BY sofa_band
ORDER BY compliance_pct DESC;
