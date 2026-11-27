# SOS Safety Intelligence

The Safety Map extends the existing Flutter SOSense app and Firebase Functions backend. It reads a versioned aggregate snapshot from `mobile_app/assets/safety_summary.json`. Dataset inventory and refresh state are maintained in `safety/registry.json`. The Python pipeline is `safety/pipeline.py`.

## Current verified capability

This is a historical/periodic dataset feature, not a live police feed. The catalogue schemas expose Bengaluru 2023 crash totals by police station and crime type totals by city for 2021–2023. No verified incident coordinates were present. The UI consequently shows aggregate cards only when actual source files have passed validation, and currently shows an honest unavailable state with no sample incidents. It does not offer fabricated map pins or precise nearby distances.

The 2023 BTP report supplies separate context: 894 fatal crashes / 921 fatalities, division totals, vulnerable road-user proportions, and named high-risk corridors/locations. It is not merged with the CSV metrics. See [source research](DATA_SOURCE_RESEARCH.md) and [methodology](GEOSPATIAL_ANALYSIS_METHODOLOGY.md).

## App integration

Safety Map is available from the dashboard bottom navigation and Safety Modules grid. It supports combined, accident-only, and crime-only aggregate views, expandable detail cards, refresh of the bundled snapshot, reporting-period/precision disclosures, source notes, and empty-state behavior. The screen is deliberately not presented as a pin map until spatial data exists.

## Backend

Firebase HTTPS Function `safetyData` exposes read-only GET endpoints at the function URL:

- `/` — full processed snapshot
- `/summary` — availability and build status
- `/accidents` — station aggregate
- `/crimes` — city category aggregate
- `/sources` — registry metadata and limitations
- `/refresh-status` — download/update status

Responses contain no user data. They are cached for five minutes. Deploy via the existing Firebase Functions workflow; public data requires no user location and the endpoint never accepts GPS.

## Refresh and exports

Run `python safety/pipeline.py refresh` to attempt the two primary CSV downloads and process whichever files validate. A challenge/error response is recorded; no replacement/mock data is generated. The pipeline exports `analytics/safety/safety_summary.json`, `accident_station_summary.csv`, and `crime_city_summary.csv`; it also syncs the snapshot and registry into Firebase and the mobile asset. Manual workflow: [DATA_REFRESH_GUIDE.md](DATA_REFRESH_GUIDE.md).

## SQL and Power BI

`analytics/sql/safety_hotspots.sql` creates aggregate views if the tables are loaded in the existing SQLite warehouse. Export schemas are documented in [HOTSPOT_DATA_DICTIONARY.md](HOTSPOT_DATA_DICTIONARY.md). Power BI setup is specified in [reports/POWER_BI_DOCUMENTATION.md](reports/POWER_BI_DOCUMENTATION.md). No PBIX/PBIT dashboard file is claimed.

## Known incomplete items

- Publisher challenge prevented saving/inspecting the actual crash and crime CSV bytes; outputs remain unavailable until download or manual placement succeeds.
- BIGRS PDF was inspected online but not saved locally.
- No map tile provider, polygons, geocoding, location tracking, nearby search, crime street hotspots, routing provider, or route safety score is included because the required defensible spatial source is absent.
- Karnataka 2024/2025 datasets are researched in the registry but not downloaded or mixed into the Bengaluru view.
- The app currently uses the bundled snapshot. Rebuild/redeploy after refresh to publish updated mobile assets; deploy Firebase Functions for the HTTP snapshot endpoint.
