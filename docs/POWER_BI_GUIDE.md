# Power BI guide

Power BI Desktop was not available for this implementation, so no dashboard has been opened or tested here. Existing Power BI-ready CSV exports, DAX measures, Power Query M examples and theme are under `analytics/`; design notes are in [Power BI documentation](reports/POWER_BI_DOCUMENTATION.md).

In Power BI Desktop, use **Get Data → Text/CSV** for the existing files under `analytics/exports/`, set date/time and numeric types, then relate only compatible keys and grains. Keep source aggregate rows at their published geography and time grain. Do not plot station-level crash totals or citywide crime totals as exact locations. Recommended report pages: overview, accident counts/severity, crime type and reported/detected counts, source-grain-aware map or table, supported time trends, model benchmark context, and clearly separated simulation events. Refresh from the documented source workflow; do not imply live freshness.
