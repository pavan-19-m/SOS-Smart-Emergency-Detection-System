# SQL analytics guide

The existing SQLite warehouse and reproducible query collection are in `analytics/sosense_analytics.db` and `analytics/sql/analytics_queries.sql`. Schema documentation is in `architecture/DATABASE_SCHEMA.md`; the notebook and report outputs are under `data_science/` and `docs/reports/`.

Use the existing database rather than creating a parallel local dashboard store. Local browser simulation incidents are intentionally in-memory and are not inserted into the real analytics warehouse. Do not merge those test events into real incident reporting without preserving the simulation flag. Available tables/views and query assumptions are described in [SQL Analytics](reports/SQL_ANALYTICS.md).
