# Testing report — 28 November 2026

## Executed

- Baseline Python: `.venv\Scripts\python.exe -m pytest tests -q` — 11 passed before web implementation.
- Baseline Firebase Functions: `npm test` in `backend/functions` — 10 passed before web implementation.
- Laptop web API/model/sensor tests: `npm test` — 12 passed, including 20-feature input order, exported Random Forest prediction parity, bounded scenarios, API input validation, simulation-only incidents, journey check-in/missed handling, and static path traversal rejection.
- JavaScript syntax checks: `npm run check` — passed after implementation fixes.

## Not verified in this environment

The existing Python/backend suites should be rerun against the final worktree; the mobile Flutter build/tests were not executable because Flutter and Dart are not installed. No Firebase project is configured, so live authentication, Firestore, FCM or contact delivery was not exercised. Dataset download/processing is not validated against raw files because the publisher download endpoint returned a Cloudflare challenge in the recorded audit. No Power BI Desktop or physical phone was available. See [known limitations](KNOWN_LIMITATIONS.md).
