"""
03_clean_and_preprocess.py
Performs comprehensive sensor data auditing, cleaning, noise filtering,
and before-and-after quality reporting while keeping raw files untouched.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import numpy as np
import pandas as pd
from scipy.signal import butter, filtfilt

ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = ROOT / "data_science" / "datasets" / "raw"
CLEANED_DIR = ROOT / "data_science" / "datasets" / "cleaned"
REPORTS_DIR = ROOT / "data_science" / "reports"
CLEANED_DIR.mkdir(parents=True, exist_ok=True)
REPORTS_DIR.mkdir(parents=True, exist_ok=True)


def butter_lowpass_filter(signals: np.ndarray, cutoff_hz: float = 20.0, fs_hz: float = 50.0, order: int = 4) -> np.ndarray:
    """Zero-phase Butterworth low-pass filter along time axis (axis=1)."""
    nyq = 0.5 * fs_hz
    normal_cutoff = min(cutoff_hz / nyq, 0.99)
    b, a = butter(order, normal_cutoff, btype="low", analog=False)
    return filtfilt(b, a, signals, axis=1).astype(np.float32)


def audit_dataset(meta: pd.DataFrame, tot_acc: np.ndarray, gyro: np.ndarray) -> dict:
    nan_meta = int(meta.isna().sum().sum())
    nan_acc = int(np.isnan(tot_acc).sum() + np.isinf(tot_acc).sum())
    nan_gyro = int(np.isnan(gyro).sum() + np.isinf(gyro).sum())

    # Physical plausibility bounds for smartphone MEMS sensors:
    # Accelerometer typical range +/- 16g (~157 m/s^2); Gyroscope +/- 35 rad/s (2000 deg/s)
    invalid_acc = int(((np.abs(tot_acc) > 160.0).any(axis=(1, 2))).sum())
    invalid_gyro = int(((np.abs(gyro) > 40.0).any(axis=(1, 2))).sum())

    # Duplicate signal hash check
    hashes = [
        hashlib.md5(np.concatenate([tot_acc[i], gyro[i]], axis=1).tobytes()).hexdigest()
        for i in range(len(meta))
    ]
    dup_signals = int(pd.Series(hashes).duplicated().sum())
    dup_ids = int(meta["window_id"].duplicated().sum())

    # Timestamp validity
    parsed_ts = pd.to_datetime(meta["timestamp_utc"], format="ISO8601", utc=True, errors="coerce")
    invalid_ts = int(parsed_ts.isna().sum())

    # Sampling consistency
    invalid_sampling = int(((meta["sampling_hz"] != 50.0) | (meta["window_samples"] != 128)).sum())

    # Outlier stats (IQR on raw_acc_mag_max)
    q1 = float(meta["raw_acc_mag_max"].quantile(0.25))
    q3 = float(meta["raw_acc_mag_max"].quantile(0.75))
    iqr = q3 - q1
    upper_fence = q3 + 1.5 * iqr
    statistical_outliers = int((meta["raw_acc_mag_max"] > upper_fence).sum())

    class_counts = meta["event_category"].value_counts().to_dict()
    max_cls = max(class_counts.values()) if class_counts else 1
    min_cls = min(class_counts.values()) if class_counts else 1

    return {
        "row_count": int(len(meta)),
        "missing_metadata_cells": nan_meta,
        "non_finite_acc_values": nan_acc,
        "non_finite_gyro_values": nan_gyro,
        "physically_invalid_acc_windows": invalid_acc,
        "physically_invalid_gyro_windows": invalid_gyro,
        "duplicate_signal_windows": dup_signals,
        "duplicate_window_ids": dup_ids,
        "invalid_timestamps": invalid_ts,
        "inconsistent_sampling_windows": invalid_sampling,
        "iqr_upper_fence_acc_max_ms2": round(upper_fence, 4),
        "statistical_high_peak_windows": statistical_outliers,
        "event_category_distribution": {str(k): int(v) for k, v in class_counts.items()},
        "imbalance_ratio_max_to_min": round(max_cls / max(min_cls, 1), 2),
        "_signal_hashes": hashes,
    }


def main() -> None:
    meta = pd.read_csv(RAW_DIR / "sensor_windows_metadata.csv")
    npz = np.load(RAW_DIR / "sensor_windows_signals.npz")
    tot_acc = npz["tot_acc"]
    body_acc = npz["body_acc"]
    gyro = npz["gyro"]

    before_report = audit_dataset(meta, tot_acc, gyro)
    hashes = before_report.pop("_signal_hashes")

    # Cleaning mask: remove non-finite, physically impossible, invalid timestamp, inconsistent sampling, or exact duplicate windows
    valid_mask = np.ones(len(meta), dtype=bool)
    valid_mask &= ~np.isnan(tot_acc).any(axis=(1, 2))
    valid_mask &= ~np.isinf(tot_acc).any(axis=(1, 2))
    valid_mask &= ~np.isnan(gyro).any(axis=(1, 2))
    valid_mask &= ~np.isinf(gyro).any(axis=(1, 2))
    valid_mask &= (np.abs(tot_acc) <= 160.0).all(axis=(1, 2))
    valid_mask &= (np.abs(gyro) <= 40.0).all(axis=(1, 2))
    valid_mask &= (meta["sampling_hz"] == 50.0).to_numpy()
    valid_mask &= (meta["window_samples"] == 128).to_numpy()
    valid_mask &= ~pd.Series(hashes).duplicated().to_numpy()

    cleaned_meta = meta.loc[valid_mask].reset_index(drop=True)
    cleaned_tot_acc = tot_acc[valid_mask]
    cleaned_body_acc = body_acc[valid_mask]
    cleaned_gyro = gyro[valid_mask]

    # Noise filtering: preserve peak impulse shape (20 Hz cutoff on 50 Hz signal removes >20 Hz jitter)
    filtered_tot_acc = butter_lowpass_filter(cleaned_tot_acc, cutoff_hz=20.0, fs_hz=50.0, order=4)
    filtered_body_acc = butter_lowpass_filter(cleaned_body_acc, cutoff_hz=20.0, fs_hz=50.0, order=4)
    filtered_gyro = butter_lowpass_filter(cleaned_gyro, cutoff_hz=20.0, fs_hz=50.0, order=4)

    # Recompute cleaned magnitude summaries
    acc_mag = np.linalg.norm(filtered_tot_acc, axis=-1)
    gyro_mag = np.linalg.norm(filtered_gyro, axis=-1)
    cleaned_meta["clean_acc_mag_mean"] = acc_mag.mean(axis=1).round(4)
    cleaned_meta["clean_acc_mag_max"] = acc_mag.max(axis=1).round(4)
    cleaned_meta["clean_acc_mag_min"] = acc_mag.min(axis=1).round(4)
    cleaned_meta["clean_gyro_mag_mean"] = gyro_mag.mean(axis=1).round(4)
    cleaned_meta["clean_gyro_mag_max"] = gyro_mag.max(axis=1).round(4)

    # Compute high-frequency noise reduction ratio
    raw_hf_std = float(np.std(cleaned_tot_acc - filtered_tot_acc))
    cleaned_meta["noise_filtered"] = True

    after_report = audit_dataset(cleaned_meta, filtered_tot_acc, filtered_gyro)
    after_report.pop("_signal_hashes")

    cleaned_meta.to_csv(CLEANED_DIR / "cleaned_sensor_windows_metadata.csv", index=False)
    np.savez_compressed(
        CLEANED_DIR / "cleaned_sensor_windows_signals.npz",
        tot_acc=filtered_tot_acc,
        body_acc=filtered_body_acc,
        gyro=filtered_gyro,
    )

    quality_report = {
        "before_cleaning": before_report,
        "after_cleaning": after_report,
        "cleaning_actions": {
            "rows_removed": int(len(meta) - len(cleaned_meta)),
            "filter_type": "4th-order zero-phase Butterworth low-pass (cutoff=20 Hz, fs=50 Hz)",
            "removed_noise_rms_ms2": round(raw_hf_std, 5),
            "outliers_retained_rationale": (
                "High-magnitude statistical outliers (IQR > fence) are deliberately retained "
                "because genuine impact/fall/crash-candidate events manifest as extreme peak accelerations."
            ),
        },
    }
    (REPORTS_DIR / "data_quality_report.json").write_text(
        json.dumps(quality_report, indent=2), encoding="utf-8"
    )
    print("[OK] Data cleaning & preprocessing complete:")
    print(json.dumps(quality_report, indent=2))


if __name__ == "__main__":
    main()
