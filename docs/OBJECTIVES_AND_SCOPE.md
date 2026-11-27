# Objectives and Scope

## Primary Objectives
1. Detect possible accident-like impacts, fall-like patterns, and unusual motion anomalies using smartphone accelerometer and gyroscope sensors.
2. Support instant or countdown-protected manual SOS activation.
3. Distinguish suspected events from confirmed emergencies using a configurable verification countdown.
4. Retrieve accurate GPS coordinates with explicit staleness tracking and Google Maps links.
5. Dispatch notifications via Firebase Cloud Functions & FCM to primary contacts, escalating to secondary contacts when unacknowledged.
6. Support solo/late-night travel via Safe Check-In sessions with grace periods.
7. Maintain searchable incident history and offline recovery queues.
8. Build a reproducible Python data pipeline (raw -> cleaned -> processed -> features -> ML -> SQL -> Power BI).

## Explicit Scope Boundaries
- **Does NOT** guarantee detection of all road accidents, crimes, attackers, or medical emergencies.
- **Does NOT** override Android OS background battery restrictions silently; limitations are surfaced transparently to users.
- **Does NOT** present synthetic/controlled simulation data as real-world vehicle crash telemetry.
