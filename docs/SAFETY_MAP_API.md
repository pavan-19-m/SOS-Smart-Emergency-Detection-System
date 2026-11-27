# Safety Map API

The existing Firebase Functions service exports a public read-only HTTPS function named `safetyData`. Base URL follows the deployed project's region, commonly `https://REGION-PROJECT_ID.cloudfunctions.net/safetyData`.

| GET path | Response |
|---|---|
| `/` | Full processed snapshot |
| `/summary` | availability, dataStatus, generatedAt, message |
| `/accidents` | 2023 police-station aggregate records |
| `/crimes` | Bengaluru city category totals for 2021–2023 |
| `/sources` | Dataset registry, URLs, precision, freshness and limitations |
| `/refresh-status` | Source ids and last attempt/download/success status |

The endpoint accepts no coordinates, identity or filters that could imply false precision. No nearby endpoint is exposed because current datasets do not have defensible point or area geometries. Responses have a five-minute public cache header. Unsupported method returns 405; unsupported path returns 404. Data is public and aggregate. Do not place secrets or personal records in either JSON snapshot.

See [SAFETY_HOTSPOT_DOCUMENTATION.md](SAFETY_HOTSPOT_DOCUMENTATION.md) and [DATA_REFRESH_GUIDE.md](DATA_REFRESH_GUIDE.md).
