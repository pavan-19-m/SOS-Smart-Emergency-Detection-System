# Safety Map testing record

Automated pipeline tests use synthetic rows isolated in pytest temporary directories; those rows are never written into production exports or app assets.

Executed on 27 November 2026:

- `.venv\Scripts\python.exe -m pytest tests -q` — **11 passed**.
- `npm test` in `backend/functions` — **10 passed** (includes 3 safety HTTP service tests).
- `npm run lint` in `backend/functions` — **passed** (`node --check`).
- `flutter analyze` — **not run**; Flutter executable is not installed in this environment.
- Android emulator/device rendering, Firebase emulator endpoint integration and offline-device behavior — **not run**.

Coverage: no-source behavior, schema rejection, numeric cleaning, duplicate detection, aggregate rows without fabricated coordinates, and HTTP GET/method/unknown-path/metadata filtering. The existing test suite does not verify a deployed Firebase endpoint. Do not claim mobile manual checks passed without running them.
