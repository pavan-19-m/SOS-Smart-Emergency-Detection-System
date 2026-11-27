# Safety aggregate data dictionary

All values derive from publisher aggregates after successful validation. Empty snapshot arrays mean data is unavailable; they do not mean zero incidents. No synthetic records are included in production exports.

## Accident station table (`accident_station_summary.csv`)

| Field | Type | Meaning |
|---|---|---|
| zone | text/null | BTP source zone |
| subdivision | text/null | BTP source subdivision |
| station | text | BTP police station label; aggregate geography |
| fatalCases | integer/null | Source 2023 fatal crash cases |
| peopleKilled | integer/null | Source 2023 people killed |
| nonFatalCases | integer/null | Source 2023 non-fatal crash cases |
| peopleInjured | integer/null | Source 2023 people injured |
| totalCases | integer/null | Source 2023 total crash cases |
| concentration | text/null | Relative empirical quartile class of totalCases after a successful nonempty ingest |
| geographicPrecision | text | `police_station_aggregate`; never a point coordinate |
| sourceId | text | Registry dataset identifier |
| reportingPeriod | text | `2023` |

## Crime city table (`crime_city_summary.csv`)

`sourceCategory` preserves the source's crime type label. `category` is a normalized key. `reported2021`, `detected2021`, ... `reported2023`, `detected2023` are source counts (integer/null). `geographicPrecision` is `city_aggregate`; `sourceId` identifies the registry item. Crime table does not include coordinates, timestamps, police stations, or victims/suspects.

## Snapshot metadata

`generatedAt` is the actual pipeline generation time. `dataStatus` remains `historical`. `availability` is `unavailable`, `partial`, or `available` based on validated local primary CSV files. Dataset `lastDownloadedAt` is set only after a non-HTML file is saved; `lastSuccessfulUpdateAt` is set only after schema and duplicate validation. Registry source status describes pipeline state, not publisher freshness.
