# SOS repository audit

Audit performed 28 November 2026 on `feature/sos-web-platform-recovery`, starting at `5127ac3` (the prior Safety Intelligence branch had reached `origin/main`). Existing user workspace changes were found in `mobile_app/analysis_options.yaml`, `mobile_app/pubspec.lock`, `mobile_app/android/app/.gradle/`, and generated `mobile_app/android/app/src/main/java/`. They were preserved and are not staged by this work.

## Architecture found

- **Mobile:** Flutter Android-first app in `mobile_app/`, 20+ screens and Firebase Auth/Firestore/FCM integrations. Real accelerometer and gyroscope streams feed EMA filtering, overlapping 128-sample/2.56-second windows, 20 features, on-device JSON Random Forest and rule baseline, then human verification. Geolocator supports real GPS. Offline queue and timed safe check-ins exist.
- **Backend:** Firebase Cloud Functions v2, Firestore security rules/indexes, server-side incident notification/escalation and account deletion. Demo incidents are guarded in both mobile dispatch and server FCM service.
- **ML/data science:** Python scripts under `data_science/scripts/`; real UCI HAR motion data (not accident data) plus explicitly labeled controlled synthetic anomaly windows. Training produces the 30-tree `RandomForestClassifier` JSON bundle used by Dart. Trained labels are `crash_candidate`, `fall_like`, `normal`, and `unusual_movement`.
- **Analytics:** Existing SQLite warehouse, CSV exports, SQL queries and Power BI specifications. Safety aggregate pipeline/registry and Firebase snapshot endpoint were added in the previous feature branch. Its official CSV inputs remain unavailable in this checkout, and safety JSON arrays are empty.
- **No laptop web app or root-level launcher existed** at audit start. There is no Firebase project binding (`.firebaserc`) or `.env`; `.env.example` contains placeholders only.

## Baseline test and environment findings

- `.venv\Scripts\python.exe -m pytest tests -q`: 11 passed before this implementation.
- `npm test` in `backend/functions`: 10 passed before this implementation.
- Node.js 24.12.0 and npm 11.6.2 are available.
- Flutter and Dart executables are not installed. Android build tools are not verified. Firebase project configuration is absent, so live Firestore/FCM cannot be tested from this checkout.
- `mobile_app/android/app/.gradle/` and `GeneratedPluginRegistrant.java` appeared as local generated/untracked files. The user's existing edits were preserved. No dependency lock was tracked at audit start.

## Working, partial, and unavailable features

| Area | Status at audit |
|---|---|
| Mobile safety screens, device sensor subscriptions, GPS, ML model loading, human confirmation | Implemented in source; not build-verified here |
| Firebase Auth/Firestore/FCM dispatch and simulation suppression | Implemented in source/tests; deployment not configured here |
| Python sensor corpus, feature engineering, model export, SQL and Power BI exports | Existing implementation; baseline tests pass |
| Safety dataset research/aggregate processing/API | Implemented but source CSV downloads were blocked; no geographic pins can be supported from discovered schemas |
| Laptop browser dashboard and sensor stream simulator | Missing before this branch |
| Laptop ML inference | Not available before this branch; will use the existing model bundle and 20-feature pipeline |
| Desktop emergency simulation, simulated notifications and session history | Missing before this branch |
| Real browser incident/contact integration | No Firebase project config; will remain explicitly local/demo until configured |

## Issues and technical debt

1. The application has no desktop browser build path despite the project depending on mobile device sensors.
2. Firebase initialization is intentionally caught when configuration is absent, allowing a local Flutter launch without cloud services but not real account/cloud behavior.
3. `NotificationService` guards simulated incidents from FCM and server `handleIncidentCreated` repeats the guard; any new laptop simulator must never call this real dispatch path.
4. The classifier was evaluated on controlled synthetic anomalies and real HAR activity windows, not real road crashes or falls. Near-perfect synthetic-benchmark metrics are not real-world safety performance.
5. The 2023 crash source has police-station aggregate counts; crime source has Bengaluru category totals. Neither supports incident pins, spatial density, or exact nearby search. The current refresh result has zero rows because publisher downloads were blocked, not because the city had zero incidents.
6. Safety API is Firebase Functions, not a local development server. A small local Node server is needed for browser UI and isolated simulation APIs; real Firebase will remain optional.
7. No default Firebase web keys, routing provider, map geometry, or authenticated cross-platform browser session is configured.

## Repair plan and execution

1. Add root Node scripts and a localhost web server that uses only Node/browser built-ins, avoiding dependency installation for laptop startup.
2. Port the mobile 20-feature computation to a shared-tested JavaScript module and traverse the existing exported forest; do not substitute random predictions.
3. Build browser dashboard pages, bounded 50 Hz simulator scenarios, interactive SVG charts, local-only simulated emergency/countdown/incident records, local contact/journey tools, safety source status and diagnostics.
4. Hard-separate local simulated history and notifications from Firebase/real incident dispatch.
5. Add API/unit tests, run existing and new suites, smoke test localhost endpoints and browser module assets, document exact SDK/service limits.
6. Commit only this branch's explicit project files, leaving pre-existing uncommitted Flutter user files unstaged, then push and verify the requested branch.

## Implementation update

The laptop web workspace, loopback Node server, dashboard pages, bounded sensor scenarios, actual exported-model inference, local-only emergency and journey simulation, web tests, launcher, setup guide and architecture/limitation documentation have now been added. The model/API tests and JS syntax checks pass. Remaining verification includes final reruns of the pre-existing Python and Functions suites, a live localhost smoke check, and Flutter/mobile build (Flutter unavailable). The safety map intentionally has no incident pins because source geometries are absent. No raw official CSV was downloaded; the existing source research records the Cloudflare download challenge.
