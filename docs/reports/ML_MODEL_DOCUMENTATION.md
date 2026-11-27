# Machine Learning Model Documentation

## Modeling Strategy (Track A)
Implemented in [06_train_and_evaluate_ml.py](file:///C:/Users/Erica%20Work/Desktop/Emergency-Tracking-System/SOS-Smart-Emergency-Detection-System/data_science/scripts/06_train_and_evaluate_ml.py) using strict **5-fold `GroupKFold`** grouped by `subject_id` on `8,192` training windows (`28` subjects), evaluated once on `3,307` held-out test windows (`12` unseen subjects).

## Models Trained & Tuned
1. **Rule-Based Baseline:** Deterministic G-force, gyroscope, orientation, and stillness thresholds (`05_rule_based_detector.py`).
2. **Logistic Regression:** `class_weight="balanced"`, `max_iter=1500`, tuned `C=5.0`.
3. **Decision Tree:** `class_weight="balanced"`, tuned `max_depth=6`, `min_samples_leaf=1`.
4. **Random Forest (Deployed On-Device):** `class_weight="balanced"`, tuned `n_estimators=30`, `max_depth=8`, `min_samples_leaf=1`. Exported to pure JSON (`sosense_inference_bundle.json`) for zero-server local Flutter inference.
5. **XGBoost:** `eval_metric="mlogloss"`, tuned `n_estimators=50`, `max_depth=4`, `learning_rate=0.1`.
6. **Isolation Forest (Unsupervised):** Fit **exclusively** on real normal UCI HAR training windows (`contamination=0.02`, `n_estimators=100`).
7. **Real-Only UCI HAR 6-Class Activity Classifier:** Random Forest (`n_estimators=80`, `max_depth=14`) trained and evaluated strictly on real smartphone human activity data (`2,947` real test windows).

## Why On-Device JSON Inference Instead of a Remote Python Server?
During road accidents or rural travel, cellular connectivity can drop or spike in latency. Exporting the 30-tree Random Forest + `StandardScaler` parameters to `mobile_app/assets/models/sosense_inference_bundle.json` enables sub-millisecond deterministic inference offline in Dart, verified for 100% parity with scikit-learn via `pytest`.
