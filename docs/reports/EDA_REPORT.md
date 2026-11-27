# Exploratory Data Analysis (EDA) Report

Full interactive notebook with embedded code, tables, and charts: [01_exploratory_data_analysis.ipynb](file:///C:/Users/Erica%20Work/Desktop/Emergency-Tracking-System/SOS-Smart-Emergency-Detection-System/data_science/notebooks/01_exploratory_data_analysis.ipynb).

## Key Analytical Findings
1. **Class Imbalance (34.33:1):** Out of `11,499` windows, `10,299` (`89.56%`) are normal activities (`uci_har_public_real`), `600` (`5.22%`) are `unusual_movement`, `300` (`2.61%`) are `fall_like`, and `300` (`2.61%`) are `crash_candidate`. Accuracy alone is misleading; macro-F1, recall, and false-negative rate are mandatory.
2. **Peak Acceleration & Gyroscope Separation (SQL Q1):**
   - `normal` (UCI HAR): avg peak accel `13.49 m/s²` (max `25.63 m/s²`), avg peak gyro `0.93 rad/s`.
   - `fall_like`: avg peak accel `39.56 m/s²` (max `59.33 m/s²`), avg peak gyro `7.71 rad/s`.
   - `crash_candidate`: avg peak accel `70.04 m/s²` (max `101.18 m/s²`), avg peak gyro `11.57 rad/s`.
   - `unusual_movement`: avg peak accel `21.52 m/s²` (max `53.53 m/s²`), avg peak gyro `4.37 rad/s`.
3. **Temporal Waveform Signatures:** Walking displays periodic 1.5–2 Hz oscillations; laying stays flat near `9.8 m/s²`; falls show a free-fall dip followed by impact and post-fall stillness.
4. **Generated EDA Visualizations (`data_science/visualizations/`):**
   - `eda_class_imbalance.png`
   - `eda_sensor_distributions.png`
   - `eda_normal_vs_anomaly_waveforms.png`
   - `eda_correlation_heatmap.png`
