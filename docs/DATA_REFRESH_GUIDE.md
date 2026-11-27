# Safety data refresh guide

The publisher is periodically updated, not a live incident API. No automatic scheduler is configured. Refreshing is an explicit operator task.

## Automated attempt

From the repository root:

```powershell
python safety\pipeline.py refresh
```

The command downloads the official Bengaluru BTP station crash CSV and Bengaluru BCP total crimes CSV to timestamp/hash-named immutable raw paths. Where the server provides ETag or Last-Modified, the next request uses conditional headers; identical content hashes are not written again. It validates expected columns, detects duplicate station/category keys, audits missingness and coordinate/time field availability, normalizes numeric values without changing raw files, and generates aggregate JSON/CSV outputs. If the source returns HTML, an error, or a schema mismatch, the pipeline records failure and does not replace existing raw versions. Inspect `safety/registry.json` after the attempt.

## Manual publisher file placement

If OpenCity requires a browser challenge, download the CSV manually from each `downloadUrl` in `safety/registry.json` and save it as:

- `safety/data/raw/bengaluru_btp_station_crashes_2023/source.csv`
- `safety/data/raw/bengaluru_bcp_crime_2023/source.csv`

Then run `python safety/pipeline.py process`. Raw files are ignored by git and kept separately from normalized outputs. Review headers and update documented schema/mapping intentionally if publishers revise fields. Do not geocode aggregates or substitute test data.

## Publishing refreshed output

The script syncs output to `analytics/safety/`, `backend/functions/safety_summary.json`, `backend/functions/safety_registry.json`, and `mobile_app/assets/safety_summary.json`. Review the resulting counts, schema, statuses, dates, and diff. Rebuild/release the mobile app to refresh bundled data and deploy the existing Functions codebase to update the API response. Keep all timestamps tied to actual actions. Never label this periodic history as live.

## Recovery

If source access fails, retain the last validated raw file and output. A failed attempt must not remove a prior valid source. The current repository has no validated source CSV, so the bundled snapshot is empty. Check the OpenCity page and report the access failure in `docs/DATA_SOURCE_RESEARCH.md` before presenting updated analysis.
