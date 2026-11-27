# Geospatial analysis methodology

## What can be computed from the verified schemas

The 2023 BTP crash table has one aggregate record per station (plus zone/subdivision) and counts for fatal crashes, people killed, non-fatal crashes, injured people and total cases. The 2023 BCP crime table has city totals by crime type, with reported and detected counts in 2021, 2022 and 2023. Neither table includes coordinates, incident timestamps, boundaries, exposure denominators, or identifiable incident rows.

The pipeline therefore preserves the aggregates and never creates points, grids, density surfaces, geocoded incident estimates, month/day/hour trends, or nearby distances. A station count is not an exact station centroid and a citywide total has no defensible area location.

## Crash concentration classes

For a successfully ingested crash dataset, station counts can be ranked and assigned four *relative recorded-count* bands using empirical rank quartiles (`rank <= 25%`, `<= 50%`, `<= 75%`, above 75%). Ties remain in the same threshold rule and may make band sizes unequal. The implementation labels them “lower/moderate/elevated/highest recorded concentration in this dataset.” These are descriptive count classes, not statistical significance, exposure-adjusted risk, or danger ratings. The current snapshot is empty because the source CSV could not be downloaded, so it contains no calculated classes.

Fatal cases, people killed, non-fatal cases and injured people remain distinct. Zero and missing values are not silently treated as equal: missing values remain null; absent count values are ignored only for the relevant metric. No rankings across reporting periods are produced.

## Crime analytics

The crime CSV can support crime-type reported/detected counts and year-to-year descriptive change only after inspection confirms numeric values and matching definitions. Source categories are preserved verbatim alongside normalized keys. It cannot produce geographic concentration or street-level filters. A crime total across years is not used to compare categories whose definitions change.

## Future spatial upgrade criteria

Spatial circles/tiles/nearby search require verified coordinates or official boundary geometries joined on stable identifiers and defensible aggregation. Any future precision must match the source: station boundaries for station totals, ward/division boundaries for those totals, and incident points only for genuinely incident-level public records. Population or traffic exposure should be used only if a compatible, reliable denominator and period exist. Kernel density and clustering are not meaningful for current aggregate rows.

No location is described as absolutely safe or unsafe. This is historical reported-incident awareness; it is affected by reporting practices and coverage.
