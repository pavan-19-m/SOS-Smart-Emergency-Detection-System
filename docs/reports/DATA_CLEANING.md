# Data Cleaning & Preprocessing Report

Executed by [03_clean_and_preprocess.py](file:///C:/Users/Erica%20Work/Desktop/Emergency-Tracking-System/SOS-Smart-Emergency-Detection-System/data_science/scripts/03_clean_and_preprocess.py) with structured JSON audit output at `data_science/reports/data_quality_report.json`.

## Before-and-After Audit Summary

| Quality Metric | Before Cleaning | After Cleaning |
|---|---:|---:|
| Total Windows | 11,499 | 11,499 |
| Missing Metadata Cells | 0 | 0 |
| Non-Finite (`NaN`/`Inf`) Accel Values | 0 | 0 |
| Non-Finite (`NaN`/`Inf`) Gyro Values | 0 | 0 |
| Physically Invalid Windows (`>160 m/s²` or `>40 rad/s`) | 0 | 0 |
| Duplicate Signal Windows (MD5) | 0 | 0 |
| Invalid ISO-8601 Timestamps | 0 | 0 |
| Inconsistent Sampling (`!=50 Hz` or `!=128` samples) | 0 | 0 |
| Statistical High-Peak Windows (`> IQR fence 28.94 m/s²`) | 779 | 779 (retained intentionally) |
| Class Imbalance Ratio (Max / Min) | 34.33 : 1 | 34.33 : 1 |

## Signal Filtering & Outlier Policy
- **Noise Filter:** 4th-order zero-phase Butterworth low-pass filter (`cutoff = 20 Hz`, `fs = 50 Hz`), removing `0.04177 m/s²` high-frequency noise RMS without phase distortion.
- **Why Outliers Are Retained:** Windows above the IQR upper fence (`28.9352 m/s²`) correspond physically to impact peaks in `fall_like` and `crash_candidate` events. Blindly winsorizing or dropping statistical outliers would destroy the emergency signal!
- **Bug Caught During Audit:** Initial timestamp generation mixed millisecond and whole-second ISO formats, causing Pandas 3 strict parsing to flag 11,039 rows as `NaT`. Standardized to `timespec="milliseconds"` and `format="ISO8601"`, bringing `invalid_timestamps` to `0`.
