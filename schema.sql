-- ============================================================================
-- schema.sql — Sepsis Bundle Compliance Tracker (SYNTHETIC DATA ONLY)
-- Table definition for synthetic sepsis encounter data.
-- No real patient data is used anywhere in this project.
-- ============================================================================

CREATE TABLE IF NOT EXISTS sepsis_encounters (
    encounter_id               TEXT PRIMARY KEY,   -- synthetic ID, e.g. ENC-000001
    age                        INTEGER NOT NULL,   -- years at arrival
    sex                        TEXT NOT NULL,      -- 'M' or 'F'
    unit                       TEXT NOT NULL,      -- ED | ICU | Med-Surg | Telemetry | Stepdown
    arrival_ts                 TEXT NOT NULL,      -- 'YYYY-MM-DD HH:MM:SS'
    triage_ts                  TEXT,               -- triage assessment timestamp
    sepsis_screen_positive_ts  TEXT NOT NULL,      -- time zero: sepsis recognition
    sofa_score                 INTEGER,            -- SOFA score at recognition
    lactate_drawn_ts           TEXT,               -- NULL = lactate never drawn (data gap)
    lactate_value              REAL,               -- mmol/L; NULL if never drawn
    blood_culture_ts           TEXT,               -- NULL = cultures never drawn
    antibiotics_ordered_ts     TEXT,
    antibiotics_admin_ts       TEXT,               -- NULL = antibiotics never given
    fluids_started_ts          TEXT,               -- NULL = no fluids started
    fluids_ml_per_kg           REAL,               -- total crystalloid dose; NULL if none
    hypotensive_flag           INTEGER NOT NULL,   -- 1 = hypotensive at/after recognition
    vasopressor_started_ts     TEXT,               -- NULL = no vasopressor
    shift                      TEXT NOT NULL,      -- 'day' (07:00-18:59) | 'night' (19:00-06:59)
    discharge_disposition      TEXT                -- Home | SNF | Transfer | AMA | Hospice | Expired
);
