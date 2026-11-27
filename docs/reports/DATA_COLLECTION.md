# Data Collection & Engineering Pipeline

## Storage Separation
- `data_science/datasets/raw/`: Unmodified downloaded UCI HAR zip/extracted files + `sensor_windows_metadata.csv` + `sensor_windows_signals.npz` + `dataset_manifest.json`.
- `data_science/datasets/cleaned/`: Validated, filtered signals (`cleaned_sensor_windows_*`).
- `data_science/datasets/processed/`: Complete 20-feature matrix (`sensor_features_full.csv`).
- `data_science/datasets/training/`: Subject-disjoint train split (`8,192` windows, `28` subjects).
- `data_science/datasets/testing/`: Subject-disjoint test split (`3,307` windows, `12` subjects).
- `data_science/models/`: Saved `.joblib` models, `feature_scaler.json`, and `sosense_inference_bundle.json`.
- `analytics/exports/`: Clean Power BI-ready CSVs (`fact_sensor_events.csv`, `fact_incidents.csv`, `fact_notifications.csv`, `dim_date.csv`, `ml_model_comparison.csv`, `ml_confusion_matrix.csv`, `sensor_timeseries_sample.csv`).

## Provenance Tagging
Every record carries an explicit `data_source` column:
- `uci_har_public_real`: 10,299 real smartphone windows (50 Hz, 128 samples = 2.56s).
- `controlled_physics_simulation`: 1,200 explicitly tagged synthetic physics-modeled anomaly windows.
- `evaluation_simulation`: Incident & notification lifecycle logs (`is_simulation = 1`) in SQLite and Power BI exports.
