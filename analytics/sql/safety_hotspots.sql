-- SQLite schema for source-faithful, aggregate safety analytics.
-- Import CSV exports using sqlite3 .import after .mode csv and skipping headers.
CREATE TABLE IF NOT EXISTS safety_accident_stations (
  zone TEXT, subdivision TEXT, station TEXT NOT NULL,
  fatalCases INTEGER, peopleKilled INTEGER, nonFatalCases INTEGER,
  peopleInjured INTEGER, totalCases INTEGER, concentration TEXT,
  geographicPrecision TEXT NOT NULL, sourceId TEXT NOT NULL, reportingPeriod TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS safety_crime_city (
  sourceCategory TEXT NOT NULL, category TEXT NOT NULL,
  reported2021 INTEGER, detected2021 INTEGER, reported2022 INTEGER, detected2022 INTEGER,
  reported2023 INTEGER, detected2023 INTEGER,
  geographicPrecision TEXT NOT NULL, sourceId TEXT NOT NULL
);

CREATE VIEW IF NOT EXISTS vw_safety_accident_by_station AS
SELECT station, zone, subdivision, reportingPeriod, totalCases, fatalCases,
       peopleKilled, nonFatalCases, peopleInjured, concentration, geographicPrecision, sourceId
FROM safety_accident_stations;

CREATE VIEW IF NOT EXISTS vw_safety_crime_by_category AS
SELECT sourceCategory, category,
       reported2021, detected2021, reported2022, detected2022, reported2023, detected2023,
       geographicPrecision, sourceId
FROM safety_crime_city;

-- Rankings are descriptive of the same 2023 station aggregate only.
SELECT station, zone, subdivision, totalCases, fatalCases, peopleKilled, nonFatalCases, peopleInjured
FROM safety_accident_stations
WHERE totalCases IS NOT NULL
ORDER BY totalCases DESC, station;

-- Source category year-on-year counts. Definition compatibility must be reviewed.
SELECT sourceCategory, reported2021, reported2022, reported2023,
       CASE WHEN reported2022 IS NOT NULL AND reported2021 > 0
            THEN ROUND(100.0 * (reported2022-reported2021)/reported2021, 2) END AS reported_change_2021_2022_pct,
       CASE WHEN reported2023 IS NOT NULL AND reported2022 > 0
            THEN ROUND(100.0 * (reported2023-reported2022)/reported2022, 2) END AS reported_change_2022_2023_pct
FROM safety_crime_city ORDER BY sourceCategory;

-- No spatial join or accident/crime hotspot overlap query is provided because
-- neither primary table has matching area geometry or coordinates.
