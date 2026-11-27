# Detection Logic & Multi-Stage Pipeline

SOSense implements a 9-stage detection pipeline that separates physical sensor heuristics from machine learning classification and human verification:

1. **Sensor Collection:** 50 Hz 3-axis Accelerometer (`m/s²`) and Gyroscope (`rad/s`).
2. **Noise Filtering:**
   - Offline Python pipeline: 4th-order zero-phase Butterworth low-pass filter (`cutoff = 20 Hz`, `fs = 50 Hz`), reducing high-frequency noise RMS by `0.04177 m/s²`.
   - Mobile real-time stream: Exponential moving-average low-pass filter (`alpha = 0.65`) for zero-phase-lag low latency.
3. **Windowing:** 128-sample (2.56-second) sliding windows with 50% overlap on live mobile monitoring.
4. **Feature Extraction:** 20 time-domain features (`acc_mag_mean/max/min/std/var`, `acc_sma`, `acc_energy`, `acc_jerk_max`, `acc_peak_count`, `free_fall_ratio`, `gyro_mag_*`, `orientation_change_deg`, `post_peak_inactivity_ratio`, `body_acc_mag_*`, `event_duration_sec`, `inactivity_duration_sec`).
5. **Rule-Based Baseline (`05_rule_based_detector.py` / `SensorPipelineService.classifyRuleBased`):**
   - `crash_candidate`: Peak `>= 4.2g`, `gyro_mag_max >= 3.2 rad/s`, `post_peak_inactivity_ratio >= 0.45`.
   - `fall_like`: Peak `>= 2.5g`, free-fall trough (`<= 0.55g`), orientation shift `>= 30°`, post-peak stillness `>= 0.45`.
   - `unusual_movement`: Rotational burst `>= 4.0 rad/s` or prolonged static inactivity (`body_acc_mag_std < 0.05`).
6. **On-Device Random Forest (`MlInferenceService`):** Evaluates 30 depth-8 decision trees serialized in `sosense_inference_bundle.json`, scaled by training `StandardScaler` parameters.
7. **Sensitivity Gating:** User-configurable `Low` (min confidence 0.70), `Medium` (0.55), and `High` (0.45) thresholds.
8. **User Verification Countdown:** Prompts *"Are you okay?"* with configurable 5–45s timer before alert dispatch.
9. **Dispatch & Recording:** Creates Firestore/offline incident record and triggers Cloud Function FCM notifications (blocked in Demo Mode).
