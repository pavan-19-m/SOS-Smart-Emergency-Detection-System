# Testing and Validation Report

All results reported below are from **actual test runs executed in this session**. Where an SDK or hardware was absent on the host machine, that limitation is reported explicitly without fabricating results.

## 1. Python Data, ML, SQL & Security Policy Suite (`pytest`)
- **Command:** `.venv\Scripts\python.exe -m pytest tests -v`
- **Result:** **8 / 8 PASSED (7.44s)**
- **Covered Tests:**
  - `test_data_cleaning_and_quality_report`: Verified `11,499` cleaned rows, `0` missing values, `0` NaN/Inf, `0` invalid timestamps, `0` sampling errors.
  - `test_subject_disjoint_split_zero_leakage`: Verified `0` subject overlap between `train_features.csv` and `test_features.csv`.
  - `test_data_source_provenance_honesty`: Verified real UCI HAR rows are exclusively tagged `uci_har_public_real` / `normal` and simulations are tagged `controlled_physics_simulation`.
  - `test_feature_extraction_and_rule_detector`: Verified 20-feature extraction and `crash_candidate` baseline classification.
  - `test_sklearn_to_json_inference_parity`: Verified 100% prediction match across 40 test samples between scikit-learn Random Forest and portable JSON tree traversal.
  - `test_sql_database_and_powerbi_exports`: Verified SQLite tables (`11,499` sensor rows) and all 7 CSV exports.
  - `test_firestore_security_rules_policy`: Verified password rejection and server-only notification creation in `firestore.rules`.
  - `test_end_to_end_sensor_to_incident_flow`: Verified 50 Hz fall-like window -> feature extraction -> portable Random Forest inference.
  - **Bug Discovered & Fixed During Testing:** Initially `test_end_to_end_sensor_to_incident_flow` failed because the synthetic test fixture subtracted `9.81` from Z-axis after a 90° phone rotation, leaving residual gravity on X/Z in `body_acc`. Corrected the fixture's gravity-free `body_acc` post-impact segment; test then passed.

## 2. EDA Jupyter Notebook Execution (`nbconvert`)
- **Command:** `.venv\Scripts\python.exe -m jupyter nbconvert --to notebook --execute --inplace data_science\notebooks\01_exploratory_data_analysis.ipynb`
- **Result:** **PASSED** (wrote `1,086,143` bytes with all charts and descriptive statistics embedded).

## 3. Firebase Cloud Functions Unit Tests (`node --test`)
- **Command:** `cd backend\functions && npm run lint && npm test`
- **Result:** **7 / 7 PASSED (178.9 ms)**
- **Covered Tests:** Validator secret-field rejection, stale/invalid GPS Maps URL rejection, contact validation, authorized responder checks, Demo Mode FCM suppression, primary-to-secondary escalation after delay, duplicate dispatch prevention, and acknowledgement escalation halt.

## 4. Flutter / Android Test & Build Status (Host Limitation)
- **Authored Test Suites:**
  - `mobile_app/test/sosense_unit_test.dart` (form validators, 20-feature extractor, Random Forest JSON inference, simulation/offline notification guards)
  - `mobile_app/test/sosense_widget_test.dart` (SOS button UI, Demo Center verification countdown banner)
  - `mobile_app/integration_test/app_e2e_test.dart` (login -> simulated accident -> verification -> acknowledgement)
- **Execution Status:** **Not executed on this host** because **Flutter SDK** and **Android SDK** are not installed in this environment. No Flutter test results or Android APK builds are claimed or fabricated.
