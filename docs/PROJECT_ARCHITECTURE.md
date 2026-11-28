# SOSense project architecture

## Existing mobile and cloud system

Flutter (`mobile_app/`) reads real phone accelerometer, gyroscope and GPS sources. Its 128-sample, 50 Hz feature path and 20-column Random Forest bundle run locally; the app handles user verification and its existing Firebase-backed workflow. Firebase Functions and Firestore rules support the cloud incident and notification paths. Python scripts under `data_science/` prepare and evaluate model artifacts. SQLite, CSV, SQL and Power BI materials live under `analytics/`.

## Laptop workspace added here

`web/` is a dependency-free browser application served by `web/server.cjs` on `127.0.0.1:3000`. The browser engine ports the Flutter feature calculation and traverses the repository's exported JSON trees/scaler. `/api/ml/predict` accepts test input only when `isSimulation: true`. Simulated incidents, journeys and sensor session state are held only in local server memory. They have no Firestore or notification integration. The server binds to loopback by default.

The web workspace is a local demonstrator, not a shared authenticated account interface. Firebase web credentials are not configured. The real mobile app remains the production-facing device workflow.

## Safety data

Existing source registry and processing output are consumed from `backend/functions/`. Catalogue research describes station-level crash counts and citywide crime counts without incident coordinates. Consequently there is no defensible point map, nearby distance, route score, or combined spatial hotspot. The UI presents source availability and caveats, not fabricated markers.

See [System Architecture](architecture/SYSTEM_ARCHITECTURE.md), [Security and Privacy](architecture/SECURITY_AND_PRIVACY.md), [Safety Map API](SAFETY_MAP_API.md), and [Safety source research](DATA_SOURCE_RESEARCH.md).
