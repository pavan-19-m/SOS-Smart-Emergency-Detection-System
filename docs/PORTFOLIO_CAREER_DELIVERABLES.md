# Career Portfolio Deliverables (Tracks A & B)

*(Every accomplishment and metric below is strictly verified from implemented code and actual test/evaluation outputs.)*

---

## Track A — AI/ML Engineer Resume Description

**SOSense — Intelligent Sensor-Based Emergency Detection System** | *Python, Scikit-learn, XGBoost, SciPy, Flutter/Dart, Firebase*
- Engineered an end-to-end 50 Hz smartphone sensor processing and ML pipeline ingesting **10,299 real UCI HAR windows** (30 participants) and **1,200 physics-informed anomaly windows** (`fall_like`, `crash_candidate`, `unusual_rotation`, `prolonged_inactivity`).
- Implemented 4th-order zero-phase Butterworth low-pass filtering (`20 Hz` cutoff), extracted **20 time-domain kinematic features** (SMA, jerk, energy, orientation shift, free-fall ratio, post-peak stillness), and enforced strict **subject-disjoint splits** (`28` train / `12` test subjects, zero leakage).
- Tuned and benchmarked **Rule-Based Baseline, Logistic Regression, Decision Tree, Random Forest, XGBoost, and Isolation Forest** using 5-fold `GroupKFold`; reduced false-positive rate from **17.10% (504 false alarms)** in the rule baseline to **0.00%** on the held-out benchmark while achieving **77.54% accuracy** on the 100% real-world 6-class UCI HAR human activity task.
- Exported a 30-tree Random Forest + `StandardScaler` bundle to portable JSON (`sosense_inference_bundle.json`) for zero-server **on-device Dart inference** in Flutter, verified via `pytest` for 100% prediction parity with scikit-learn.

---

## Track B — Data Analyst / Data Scientist Resume Description

**SOSense — Safety Telemetry & Emergency Response Analytics Platform** | *Python, Pandas, NumPy, SQL (SQLite), Power BI, DAX, Jupyter*
- Built a modular ETL & data quality pipeline (`raw -> cleaned -> processed -> training/testing -> exports`) with automated MD5 deduplication, ISO-8601 validation, and IQR outlier preservation for impact spikes across **11,499 sensor windows**.
- Authored and executed an end-to-end **Exploratory Data Analysis Jupyter Notebook** examining class imbalance (`34.33:1`), kinematic distributions, feature correlations, and waveform separation across normal vs emergency-candidate classes.
- Designed a relational **SQLite analytics warehouse** and authored **12 analytical SQL queries** tracking event trends, cancellation rates (`27.27%` fall-candidate cancellations), primary vs secondary contact response latency (`65.11s` vs `181.81s`), and model confusion matrices.
- Prepared 7 star-schema CSV exports, Power Query M ingestion scripts, and **21+ DAX KPI measures** specifying a **5-page Power BI Executive, Sensor, Emergency, Family Response, and ML Performance Dashboard**.

---

## Technical Skills Demonstrated
- **AI/ML:** Signal Processing (Butterworth filtering), Sliding-Window Feature Engineering, Subject-Disjoint `GroupKFold` CV, Imbalanced Classification, Isolation Forest Anomaly Detection, On-Device Model Serialization.
- **Data Analytics:** Data Auditing & Quality Reporting, EDA & Statistical Visualization, Relational SQL Modeling, Power BI / DAX / Power Query M.
- **Full-Stack & Security:** Flutter Material 3 Mobile Architecture, Firebase Auth, Least-Privilege Firestore Security Rules, Node.js Cloud Functions (`node --test`), `pytest` Automated Validation.

## Key Interview Talking Points & Challenges Solved
1. **Why not drop statistical outliers?** Impact events *are* extreme statistical outliers (`>28.94 m/s²`); dropping them destroys recall.
2. **Preventing data leakage in time-series HAR:** Splitting randomly leaks overlapping windows from the same person; `GroupKFold` + disjoint `subject_id` splits prevent optimistic memorization.
3. **Why Isolation Forest missed static inactivity:** Unsupervised density models fit on normal activities treat motionless `PROLONGED_INACTIVITY` identically to normal `SITTING`/`LAYING`, motivating session-aware Safe Check-Ins.
4. **Train/Serve parity:** Identical 20-feature extraction and `StandardScaler` JSON export eliminated Python server latency/offline failure risk in emergencies.
