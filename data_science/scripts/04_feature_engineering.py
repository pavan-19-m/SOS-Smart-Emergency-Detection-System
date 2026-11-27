"""
04_feature_engineering.py
Extracts physics-informed time-domain and sliding-window features from cleaned
50 Hz accelerometer & gyroscope windows (128 samples = 2.56s).

Prevents data leakage by:
1. Computing every feature purely within its own 2.56s window.
2. Splitting strictly on subject-disjoint `split_group` ('train' vs 'test').
3. Fitting any normalization/scaler parameters ONLY on the training split.
"""

from __future__ import annotations

import json
from pathlib import Path
import numpy as np
import pandas as pd
from sklearn.preprocessing import StandardScaler
import joblib

ROOT = Path(__file__).resolve().parents[2]
CLEANED_DIR = ROOT / "data_science" / "datasets" / "cleaned"
PROCESSED_DIR = ROOT / "data_science" / "datasets" / "processed"
TRAIN_DIR = ROOT / "data_science" / "datasets" / "training"
TEST_DIR = ROOT / "data_science" / "datasets" / "testing"
MODELS_DIR = ROOT / "data_science" / "models"

for d in (PROCESSED_DIR, TRAIN_DIR, TEST_DIR, MODELS_DIR):
    d.mkdir(parents=True, exist_ok=True)


FEATURE_COLUMNS = [
    "acc_mag_mean",
    "acc_mag_max",
    "acc_mag_min",
    "acc_mag_std",
    "acc_mag_var",
    "acc_sma",
    "acc_energy",
    "acc_jerk_max",
    "acc_peak_count",
    "free_fall_ratio",
    "gyro_mag_mean",
    "gyro_mag_max",
    "gyro_mag_std",
    "gyro_energy",
    "orientation_change_deg",
    "post_peak_inactivity_ratio",
    "body_acc_mag_mean",
    "body_acc_mag_std",
    "event_duration_sec",
    "inactivity_duration_sec",
]


def extract_window_features(
    tot_acc: np.ndarray,
    body_acc: np.ndarray,
    gyro: np.ndarray,
    fs_hz: float = 50.0,
) -> pd.DataFrame:
    """
    Computes interpretable features for each (128, 3) window.
    Can also be imported directly by inference or real-time verification tests.
    """
    n, t_len, _ = tot_acc.shape
    dt = 1.0 / fs_hz

    acc_mag = np.linalg.norm(tot_acc, axis=-1)      # (N, T)
    body_mag = np.linalg.norm(body_acc, axis=-1)    # (N, T)
    gyro_mag = np.linalg.norm(gyro, axis=-1)        # (N, T)

    acc_mag_mean = acc_mag.mean(axis=1)
    acc_mag_max = acc_mag.max(axis=1)
    acc_mag_min = acc_mag.min(axis=1)
    acc_mag_std = acc_mag.std(axis=1)
    acc_mag_var = acc_mag.var(axis=1)

    # Signal Magnitude Area (SMA) across 3 axes of body acceleration
    acc_sma = np.sum(np.abs(body_acc), axis=(1, 2)) / t_len

    # Signal energy
    acc_energy = np.mean(acc_mag ** 2, axis=1)
    gyro_energy = np.mean(gyro_mag ** 2, axis=1)

    # Jerk magnitude max (|d(acc_mag)/dt|)
    jerk = np.abs(np.diff(acc_mag, axis=1)) / dt
    acc_jerk_max = jerk.max(axis=1)

    # Peak count above 1.8g (~17.65 m/s^2)
    acc_peak_count = np.sum(acc_mag > 17.65, axis=1).astype(float)

    # Free-fall ratio: fraction of samples < 0.55g (~5.4 m/s^2)
    free_fall_ratio = np.mean(acc_mag < 5.4, axis=1)

    gyro_mag_mean = gyro_mag.mean(axis=1)
    gyro_mag_max = gyro_mag.max(axis=1)
    gyro_mag_std = gyro_mag.std(axis=1)

    # Orientation change (degrees) between first 16 samples and last 16 samples mean gravity vector
    v_start = tot_acc[:, :16, :].mean(axis=1)
    v_end = tot_acc[:, -16:, :].mean(axis=1)
    dot = np.sum(v_start * v_end, axis=1)
    norms = (np.linalg.norm(v_start, axis=1) * np.linalg.norm(v_end, axis=1)) + 1e-8
    cos_theta = np.clip(dot / norms, -1.0, 1.0)
    orientation_change_deg = np.degrees(np.arccos(cos_theta))

    # Post-peak inactivity ratio & inactivity duration
    # Look at the second half of the window (or post-peak slice) where body_mag < 1.2 m/s^2 and gyro_mag < 0.35 rad/s
    quiet_mask = (body_mag < 1.2) & (gyro_mag < 0.35)
    peak_idx = np.argmax(acc_mag, axis=1)
    post_ratios = np.zeros(n, dtype=np.float32)
    inactivity_dur = np.zeros(n, dtype=np.float32)
    event_dur = np.zeros(n, dtype=np.float32)

    for i in range(n):
        p = int(peak_idx[i])
        tail = quiet_mask[i, min(p + 6, t_len - 1) :]
        post_ratios[i] = float(np.mean(tail)) if len(tail) > 0 else float(np.mean(quiet_mask[i]))
        inactivity_dur[i] = float(np.sum(quiet_mask[i]) * dt)
        # Active high-motion duration (body_mag > 2.5 m/s^2 or gyro_mag > 1.0 rad/s)
        active = (body_mag[i] > 2.5) | (gyro_mag[i] > 1.0)
        event_dur[i] = float(np.sum(active) * dt)

    return pd.DataFrame({
        "acc_mag_mean": acc_mag_mean,
        "acc_mag_max": acc_mag_max,
        "acc_mag_min": acc_mag_min,
        "acc_mag_std": acc_mag_std,
        "acc_mag_var": acc_mag_var,
        "acc_sma": acc_sma,
        "acc_energy": acc_energy,
        "acc_jerk_max": acc_jerk_max,
        "acc_peak_count": acc_peak_count,
        "free_fall_ratio": free_fall_ratio,
        "gyro_mag_mean": gyro_mag_mean,
        "gyro_mag_max": gyro_mag_max,
        "gyro_mag_std": gyro_mag_std,
        "gyro_energy": gyro_energy,
        "orientation_change_deg": orientation_change_deg,
        "post_peak_inactivity_ratio": post_ratios,
        "body_acc_mag_mean": body_mag.mean(axis=1),
        "body_acc_mag_std": body_mag.std(axis=1),
        "event_duration_sec": event_dur,
        "inactivity_duration_sec": inactivity_dur,
    })


def main() -> None:
    meta = pd.read_csv(CLEANED_DIR / "cleaned_sensor_windows_metadata.csv")
    npz = np.load(CLEANED_DIR / "cleaned_sensor_windows_signals.npz")
    tot_acc = npz["tot_acc"]
    body_acc = npz["body_acc"]
    gyro = npz["gyro"]

    feats_df = extract_window_features(tot_acc, body_acc, gyro, fs_hz=50.0)
    full_df = pd.concat([meta.reset_index(drop=True), feats_df.reset_index(drop=True)], axis=1)

    # Save full processed dataset
    full_path = PROCESSED_DIR / "sensor_features_full.csv"
    full_df.to_csv(full_path, index=False)

    # Subject-disjoint train / test split (prevents leakage)
    train_df = full_df[full_df["split_group"] == "train"].reset_index(drop=True)
    test_df = full_df[full_df["split_group"] == "test"].reset_index(drop=True)

    train_subjects = set(train_df["subject_id"].unique())
    test_subjects = set(test_df["subject_id"].unique())
    overlap = train_subjects.intersection(test_subjects)
    assert len(overlap) == 0, f"Subject leakage detected: {overlap}"

    # Fit StandardScaler ONLY on train split
    scaler = StandardScaler()
    scaler.fit(train_df[FEATURE_COLUMNS])
    joblib.dump(scaler, MODELS_DIR / "feature_scaler.joblib")

    scaler_params = {
        "feature_columns": FEATURE_COLUMNS,
        "mean": [float(x) for x in scaler.mean_],
        "scale": [float(x) for x in scaler.scale_],
    }
    (MODELS_DIR / "feature_scaler.json").write_text(json.dumps(scaler_params, indent=2), encoding="utf-8")

    train_df.to_csv(TRAIN_DIR / "train_features.csv", index=False)
    test_df.to_csv(TEST_DIR / "test_features.csv", index=False)

    print(f"[OK] Feature engineering complete. Total={len(full_df)}, Train={len(train_df)}, Test={len(test_df)}")
    print(f"[OK] Disjoint subjects verified: train={len(train_subjects)}, test={len(test_subjects)}, overlap=0")


if __name__ == "__main__":
    main()
