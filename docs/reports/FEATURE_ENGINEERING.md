# Feature Engineering

Implemented identically in Python ([04_feature_engineering.py](file:///C:/Users/Erica%20Work/Desktop/Emergency-Tracking-System/SOS-Smart-Emergency-Detection-System/data_science/scripts/04_feature_engineering.py)) and Dart ([sensor_pipeline_service.dart](file:///C:/Users/Erica%20Work/Desktop/Emergency-Tracking-System/SOS-Smart-Emergency-Detection-System/mobile_app/lib/services/sensor_pipeline_service.dart)) to prevent train/serve skew.

## Engineered Features (20 Features per 2.56s / 128-Sample Window)

| Category | Features | Physical Rationale |
|---|---|---|
| Acceleration Magnitude | `acc_mag_mean`, `acc_mag_max`, `acc_mag_min`, `acc_mag_std`, `acc_mag_var` | Captures impact peaks, free-fall dips (`acc_mag_min`), and motion spread independent of phone orientation. |
| Energy & Jerk | `acc_sma`, `acc_energy`, `acc_jerk_max`, `acc_peak_count`, `free_fall_ratio` | Quantifies instantaneous deceleration shock (`jerk`) and weightlessness duration before impact. |
| Rotational Motion | `gyro_mag_mean`, `gyro_mag_max`, `gyro_mag_std`, `gyro_energy` | Distinguishes tumbling/rotational crashes from linear walking or jogging. |
| Posture & Stillness | `orientation_change_deg`, `post_peak_inactivity_ratio`, `event_duration_sec`, `inactivity_duration_sec` | Detects whether the phone changed orientation (standing -> lying) and became motionless after an impact peak. |
| Body Linear Motion | `body_acc_mag_mean`, `body_acc_mag_std` | Gravity-separated body motion separating static stillness from dynamic locomotion. |

## Data Leakage Prevention
- Every feature is computed strictly inside its own 128-sample window (no cross-window lag/future peeking).
- Train (`28` subjects, `8,192` windows) and Test (`12` subjects, `3,307` windows) share **0 overlapping subjects**.
- `StandardScaler` is fit **exclusively** on the training split and saved to `feature_scaler.json`.
