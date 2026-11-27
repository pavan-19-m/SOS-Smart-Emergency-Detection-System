# Dataset Research & Gap Analysis

## Public Datasets Evaluated

| Dataset | Sampling Rate | Sensors | License | Suitability |
|---|---:|---|---|---|
| **UCI Human Activity Recognition (ID 240)** | 50 Hz | 3-axis Accel + 3-axis Gyro | CC BY 4.0 | **Adopted** for Stage 1 real normal activity baseline (10,299 windows, 30 subjects, raw inertial signals). |
| **WISDM HAR Dataset** | 20 Hz | 3-axis Accel | Academic / Public | Reviewed; lower 20 Hz rate & missing gyroscope across core split makes UCI HAR stronger for rotational crash/fall fusion. |
| **MobiAct v2.0** | `SENSOR_DELAY_FASTEST` (~20–200 Hz) | Accel + Gyro + Orientation | Academic Institutional EULA | Reviewed; requires formal institutional request for raw v2 archive; ideal future validation corpus. |
| **SisFall** | 200 Hz | Dual Accel + Gyro | CC BY 4.0 | Reviewed; waist-worn custom embedded module rather than pocket/handheld smartphone orientation. |

## The Core Research Gap
1. **Activity Recognition ≠ Road Accident Detection:** UCI HAR contains everyday human locomotion (`WALKING`, `WALKING_UPSTAIRS`, `WALKING_DOWNSTAIRS`, `SITTING`, `STANDING`, `LAYING`), **not** real-world vehicular crashes or falls.
2. **Staged Solution Implemented:**
   - **Stage 1 (Real Data):** 6-class Human Activity Recognition on UCI HAR (`2,947` unseen test windows -> 77.54% accuracy across unseen subjects) + Isolation Forest trained strictly on real normal UCI HAR windows.
   - **Stage 2 (Controlled Simulation):** 1,200 physics-informed synthetic anomaly windows (`FALL_LIKE`, `CRASH_CANDIDATE`, `UNUSUAL_ROTATION`, `PROLONGED_INACTIVITY`) explicitly tagged `controlled_physics_simulation`.
   - **Stage 3 (Rule Baseline + Verification):** Interpretable G-force/gyro/inactivity thresholds paired with user countdown confirmation.
   - **Future Work:** Partner with automotive telemetry or IRB-approved clinical fall corpora (e.g., MobiAct/SisFall resampled to 50 Hz) before claiming clinical or automotive crash validation.
