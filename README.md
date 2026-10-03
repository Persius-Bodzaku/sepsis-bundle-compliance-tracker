# Sepsis Bundle Compliance Tracker

SQL analysis of 1-hour sepsis bundle (SEP-1 style) compliance on a synthetic
cohort of 1,800 encounters across five hospital units, April–September 2026.

Third featured project in my clinical informatics portfolio, and the first of
a paced SQL series. **All data is fully synthetic. No real patient information
was used.**

## The bundle

Time zero = sepsis recognition. All-or-none 1-hour bundle:

1. Lactate drawn within 1 hour of recognition
2. Blood cultures drawn **before** antibiotics
3. Antibiotics administered within 1 hour of recognition
4. Fluids/vasopressors when indicated (30 mL/kg crystalloids within 1 hour,
   or vasopressor within 1 hour, for hypotension or lactate >= 4.0)

## Findings

| Analysis | Result |
|---|---|
| Overall all-or-none compliance | 57.3% (1,032 / 1,800) |
| Weakest element | Antibiotics within 1h: 74.4% |
| Strongest element | Fluids/pressors when indicated: 93.1% |
| Best unit | ICU: 66.5% |
| Worst unit | Med-Surg: 40.1% |
| Day vs night shift | 61.3% vs 53.6% |
| Trend | 53.3% (Apr) → 59.1% (Sep) |
| Median time to antibiotics | ED 21.7 min, Med-Surg 46.5 min |
| Mortality, bundle met vs missed | 9.2% vs 12.8% (unadjusted, synthetic) |
| Compliance by severity | Severe 63.2% > mild 54.6% |

The story: antibiotics within the hour is the bottleneck, concentrated on
Med-Surg, where median time to antibiotics is more than double the ED's.
Nights run 8 points worse than days. The trend is improving. And missing the
bundle tracks with higher mortality.

## Files

- `sepsis_encounters.csv` — synthetic encounter-level dataset (1,800 rows)
- `schema.sql` — table definition
- `queries.sql` — the bundle view plus the 8 analysis queries
- `sepsis-bundle-compliance-tracker.pdf` — quality-committee style writeup,
  including the Epic reporting translation (Reporting Workbench, flowsheet
  and MAR timestamp sources, timestamp hygiene)

## Reproduce it

1. Open [DB Browser for SQLite](https://sqlitebrowser.org/), create a new database.
2. File → Import → Table from CSV, select `sepsis_encounters.csv`
   (INTEGER: age, sofa_score, hypotensive_flag; REAL: lactate_value,
   fluids_ml_per_kg; everything else TEXT).
3. Paste `schema.sql` if you prefer to create the table by hand first.
4. Run the view (Q0) in `queries.sql`, then Q1–Q8 in order.
5. Hit Write Changes (Ctrl+S) to persist the view.

## Techniques

Reusable SQL view holding the bundle logic, time-zero anchored timestamp math
with `julianday`, explicit NULL handling (a missing timestamp scores as a
miss, never imputed), `UNION ALL` element breakdown, `strftime` monthly trend,
window-function medians (`ROW_NUMBER` + `COUNT(*) OVER (...)`), conditional
counting with `SUM(CASE ...)`, and `CASE` severity banding.
