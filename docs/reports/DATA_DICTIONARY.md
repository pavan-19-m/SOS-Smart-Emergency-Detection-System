# Data Dictionary

## 1. Sensor Window & Feature Columns (`fact_sensor_events.csv` / `sensor_features_full.csv`)

| Column | Type | Unit / Values | Description |
|---|---|---|---|
| `window_id` | string | `win_00000`..`win_11498` | Unique 2.56-second window identifier |
| `session_id` | string | `sess_<subj>_<src>_<split>` | Recording session identifier |
| `subject_id` | int | `1..30` (real), `901..910` (sim) | Participant/simulation subject ID used for disjoint splitting |
| `split_group` | string | `train` / `test` | Subject-disjoint ML split |
| `timestamp_utc` | ISO-8601 | UTC string | Standardized window timestamp |
| `sampling_hz` | float | `50.0` | Sensor sampling rate |
| `window_samples` | int | `128` | Number of samples per window |
| `activity_category` | string | 10 categories | Fine-grained activity or anomaly label |
| `event_category` | string | `normal`, `fall_like`, `crash_candidate`, `unusual_movement` | Target risk classification label |
| `is_anomaly_ground_truth` | int | `0` / `1` | Binary anomaly indicator |
| `data_source` | string | `uci_har_public_real` / `controlled_physics_simulation` | Provenance label |
| `acc_mag_mean`, `max`, `min`, `std`, `var` | float | `m/s²` (or `m²/s⁴`) | Filtered total acceleration magnitude statistics |
| `acc_sma` | float | `m/s²` | Signal Magnitude Area across 3 body acceleration axes |
| `acc_energy`, `gyro_energy` | float | `(m/s²)²`, `(rad/s)²` | Mean squared signal energy |
| `acc_jerk_max` | float | `m/s³` | Peak time-derivative of acceleration magnitude |
| `acc_peak_count` | float | count | Samples exceeding `1.8g` (`17.65 m/s²`) |
| `free_fall_ratio` | float | `0.0..1.0` | Fraction of samples below `0.55g` (`5.4 m/s²`) |
| `gyro_mag_mean`, `max`, `std` | float | `rad/s` | Filtered rotational velocity magnitude statistics |
| `orientation_change_deg` | float | `0..180°` | Angle between first-16 and last-16 sample gravity vectors |
| `post_peak_inactivity_ratio` | float | `0.0..1.0` | Fraction of post-peak samples with low motion (`body<1.2`, `gyro<0.35`) |
| `body_acc_mag_mean`, `std` | float | `m/s²` | Gravity-separated linear acceleration statistics |
| `event_duration_sec`, `inactivity_duration_sec` | float | seconds | Active burst duration and quiet duration within window |

## 2. Incident & Notification Tables (`fact_incidents.csv`, `fact_notifications.csv`)
- `incident_id`, `user_hash` (SHA-256 truncated pseudonym, zero PII), `event_type`, `severity`, `detection_method`, `detection_confidence`, `user_response`, `status`, `contacts_notified_count`, `ack_latency_seconds`, `escalation_triggered`, `is_false_alarm`, `is_simulation`.
