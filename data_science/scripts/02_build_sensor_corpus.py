"""
02_build_sensor_corpus.py
Ingests the real UCI HAR 50 Hz smartphone sensor dataset (accelerometer + gyroscope)
preserving subject-level splits, and appends clearly labeled physics-informed
controlled anomaly / emergency-candidate windows for end-to-end validation.

IMPORTANT SCIENTIFIC INTEGRITY RULE:
- Real public records are tagged `data_source = "uci_har_public_real"`.
- Controlled simulation records are tagged `data_source = "controlled_physics_simulation"`.
- Simulated records are NEVER labeled or presented as real-world accident data.
"""

from __future__ import annotations

import json
from pathlib import Path
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = ROOT / "data_science" / "datasets" / "raw"
UCI_DIR = RAW_DIR / "UCI_HAR_Dataset"

ACTIVITY_MAP = {
    1: "WALKING",
    2: "WALKING_UPSTAIRS",
    3: "WALKING_DOWNSTAIRS",
    4: "SITTING",
    5: "STANDING",
    6: "LAYING",
}


def load_uci_split(split: str) -> dict:
    split_dir = UCI_DIR / split
    sig_dir = split_dir / "Inertial Signals"

    # Total acceleration (in g, 9.81 m/s^2 = 1g) -> convert to m/s^2 for physical consistency
    G = 9.80665
    tot_ax = np.loadtxt(sig_dir / f"total_acc_x_{split}.txt") * G
    tot_ay = np.loadtxt(sig_dir / f"total_acc_y_{split}.txt") * G
    tot_az = np.loadtxt(sig_dir / f"total_acc_z_{split}.txt") * G

    body_ax = np.loadtxt(sig_dir / f"body_acc_x_{split}.txt") * G
    body_ay = np.loadtxt(sig_dir / f"body_acc_y_{split}.txt") * G
    body_az = np.loadtxt(sig_dir / f"body_acc_z_{split}.txt") * G

    # Gyroscope in rad/s
    gx = np.loadtxt(sig_dir / f"body_gyro_x_{split}.txt")
    gy = np.loadtxt(sig_dir / f"body_gyro_y_{split}.txt")
    gz = np.loadtxt(sig_dir / f"body_gyro_z_{split}.txt")

    subjects = np.loadtxt(split_dir / f"subject_{split}.txt", dtype=int)
    labels = np.loadtxt(split_dir / f"y_{split}.txt", dtype=int)

    n_windows = len(labels)
    activities = [ACTIVITY_MAP[int(y)] for y in labels]

    return {
        "tot_acc": np.stack([tot_ax, tot_ay, tot_az], axis=-1),   # (N, 128, 3)
        "body_acc": np.stack([body_ax, body_ay, body_az], axis=-1),
        "gyro": np.stack([gx, gy, gz], axis=-1),
        "subjects": subjects,
        "activities": activities,
        "uci_split": [split] * n_windows,
        "data_source": ["uci_har_public_real"] * n_windows,
        "event_category": ["normal"] * n_windows,
        "is_anomaly_ground_truth": np.zeros(n_windows, dtype=int),
    }


def generate_controlled_anomaly_windows(seed: int = 42) -> dict:
    """
    Generates physics-informed controlled simulation windows at 50 Hz (128 samples = 2.56s)
    explicitly tagged `controlled_physics_simulation` for:
      - FALL_LIKE (subjects 901..910)
      - CRASH_CANDIDATE (subjects 901..910)
      - UNUSUAL_ROTATION (subjects 901..910)
      - PROLONGED_INACTIVITY (subjects 901..910)
    Subjects 901..907 are assigned to 'train' and 908..910 to 'test' to enforce
    strict subject-disjoint evaluation.
    """
    rng = np.random.default_rng(seed)
    G = 9.80665
    n_per_class = 300
    t = np.linspace(0.0, 2.54, 128)

    tot_acc_list = []
    body_acc_list = []
    gyro_list = []
    subjects_list = []
    activities_list = []
    splits_list = []
    event_cat_list = []

    for cls_name, event_cat in [
        ("FALL_LIKE", "fall_like"),
        ("CRASH_CANDIDATE", "crash_candidate"),
        ("UNUSUAL_ROTATION", "unusual_movement"),
        ("PROLONGED_INACTIVITY", "unusual_movement"),
    ]:
        for i in range(n_per_class):
            subj = 901 + (i % 10)
            split = "train" if subj <= 907 else "test"

            # Base gravity vector in random phone orientation
            gravity_dir = rng.normal(0, 1, size=3)
            gravity_dir /= np.linalg.norm(gravity_dir) + 1e-8
            gravity = gravity_dir * G

            noise_acc = rng.normal(0, 0.18, size=(128, 3))
            noise_gyro = rng.normal(0, 0.05, size=(128, 3))
            body_acc = np.zeros((128, 3))
            gyro = noise_gyro.copy()
            tot_acc = np.tile(gravity, (128, 1)) + noise_acc

            if cls_name == "FALL_LIKE":
                # Pre-impact free-fall dip (samples 25..42) -> impact peak (43..52) -> post-impact stillness
                impact_idx = rng.integers(38, 56)
                ff_start = max(10, impact_idx - 16)
                tot_acc[ff_start:impact_idx] *= rng.uniform(0.15, 0.38)
                peak_g = rng.uniform(2.8, 5.2) * G
                impact_dir = rng.normal(0, 1, size=3)
                impact_dir /= np.linalg.norm(impact_dir) + 1e-8
                pulse = np.exp(-0.5 * ((np.arange(128) - impact_idx) / 2.2) ** 2)[:, None]
                body_acc += pulse * peak_g * impact_dir
                # Orientation flip after fall
                post_gravity_dir = rng.normal(0, 1, size=3)
                post_gravity_dir /= np.linalg.norm(post_gravity_dir) + 1e-8
                tot_acc[impact_idx + 4 :] = post_gravity_dir * G + rng.normal(0, 0.08, size=(128 - impact_idx - 4, 3))
                tot_acc[: impact_idx + 4] += body_acc[: impact_idx + 4]
                gyro += pulse * rng.uniform(3.0, 6.5) * rng.normal(0, 1, size=3)
                # Post-fall inactivity
                gyro[impact_idx + 8 :] = rng.normal(0, 0.02, size=(128 - impact_idx - 8, 3))

            elif cls_name == "CRASH_CANDIDATE":
                # Sudden high-G deceleration/impact pulse (4.5G - 9.5G) + high angular impulse + stillness
                impact_idx = rng.integers(30, 55)
                peak_g = rng.uniform(4.5, 9.5) * G
                impact_dir = rng.normal(0, 1, size=3)
                impact_dir /= np.linalg.norm(impact_dir) + 1e-8
                pulse = np.exp(-0.5 * ((np.arange(128) - impact_idx) / 1.8) ** 2)[:, None]
                body_acc += pulse * peak_g * impact_dir
                # Secondary rebound
                rebound = 0.35 * np.exp(-0.5 * ((np.arange(128) - (impact_idx + 7)) / 2.0) ** 2)[:, None]
                body_acc -= rebound * peak_g * impact_dir
                tot_acc += body_acc
                gyro += pulse * rng.uniform(4.5, 9.5) * rng.normal(0, 1, size=3)
                gyro[impact_idx + 14 :] = rng.normal(0, 0.015, size=(128 - impact_idx - 14, 3))

            elif cls_name == "UNUSUAL_ROTATION":
                # Chaotic multi-axis spin/tumble without steady walking cadence
                burst_idx = rng.integers(25, 80)
                env = np.exp(-0.5 * ((np.arange(128) - burst_idx) / 8.0) ** 2)[:, None]
                freq = rng.uniform(2.5, 5.5)
                spin = np.stack([
                    np.sin(2 * np.pi * freq * t),
                    np.cos(2 * np.pi * freq * 1.3 * t),
                    np.sin(2 * np.pi * freq * 0.7 * t + 0.9),
                ], axis=-1)
                gyro += env * rng.uniform(4.2, 7.5) * spin
                body_acc += env * rng.uniform(1.2, 2.8) * G * spin
                tot_acc += body_acc

            elif cls_name == "PROLONGED_INACTIVITY":
                # Very low variance static reading (e.g., unresponsive phone)
                tot_acc = np.tile(gravity, (128, 1)) + rng.normal(0, 0.015, size=(128, 3))
                body_acc = rng.normal(0, 0.01, size=(128, 3))
                gyro = rng.normal(0, 0.008, size=(128, 3))

            tot_acc_list.append(tot_acc)
            body_acc_list.append(body_acc)
            gyro_list.append(gyro)
            subjects_list.append(subj)
            activities_list.append(cls_name)
            splits_list.append(split)
            event_cat_list.append(event_cat)

    n_total = len(activities_list)
    return {
        "tot_acc": np.array(tot_acc_list, dtype=np.float32),
        "body_acc": np.array(body_acc_list, dtype=np.float32),
        "gyro": np.array(gyro_list, dtype=np.float32),
        "subjects": np.array(subjects_list, dtype=int),
        "activities": activities_list,
        "uci_split": splits_list,
        "data_source": ["controlled_physics_simulation"] * n_total,
        "event_category": event_cat_list,
        "is_anomaly_ground_truth": np.ones(n_total, dtype=int),
    }


def main() -> None:
    train_real = load_uci_split("train")
    test_real = load_uci_split("test")
    sim_anom = generate_controlled_anomaly_windows(seed=42)

    parts = [train_real, test_real, sim_anom]

    tot_acc = np.concatenate([p["tot_acc"] for p in parts], axis=0).astype(np.float32)
    body_acc = np.concatenate([p["body_acc"] for p in parts], axis=0).astype(np.float32)
    gyro = np.concatenate([p["gyro"] for p in parts], axis=0).astype(np.float32)

    subjects = np.concatenate([p["subjects"] for p in parts], axis=0)
    activities = sum([p["activities"] for p in parts], [])
    splits = sum([p["uci_split"] for p in parts], [])
    sources = sum([p["data_source"] for p in parts], [])
    event_cats = sum([p["event_category"] for p in parts], [])
    is_anom = np.concatenate([p["is_anomaly_ground_truth"] for p in parts], axis=0)

    n = len(activities)
    base_ts = pd.Timestamp("2026-10-01T08:00:00Z")
    timestamps = [
        (base_ts + pd.Timedelta(seconds=float(i * 2.56))).isoformat(timespec="milliseconds")
        for i in range(n)
    ]
    session_ids = [f"sess_{s}_{src[:4]}_{sp}" for s, src, sp in zip(subjects, sources, splits)]
    window_ids = [f"win_{i:05d}" for i in range(n)]

    # Inject a small realistic set of corrupt/duplicate diagnostic rows in a staging copy
    # ONLY? No: keep corpus clean and let 03_clean_and_preprocess.py audit and handle real anomalies/outliers!
    meta_df = pd.DataFrame({
        "window_id": window_ids,
        "session_id": session_ids,
        "subject_id": subjects,
        "split_group": splits,
        "timestamp_utc": timestamps,
        "sampling_hz": 50.0,
        "window_samples": 128,
        "activity_category": activities,
        "event_category": event_cats,
        "is_anomaly_ground_truth": is_anom,
        "data_source": sources,
    })

    # Compute raw summary columns for CSV inspection
    acc_mag = np.linalg.norm(tot_acc, axis=-1)
    gyro_mag = np.linalg.norm(gyro, axis=-1)
    meta_df["raw_acc_mag_mean"] = acc_mag.mean(axis=1).round(4)
    meta_df["raw_acc_mag_max"] = acc_mag.max(axis=1).round(4)
    meta_df["raw_acc_mag_min"] = acc_mag.min(axis=1).round(4)
    meta_df["raw_gyro_mag_mean"] = gyro_mag.mean(axis=1).round(4)
    meta_df["raw_gyro_mag_max"] = gyro_mag.max(axis=1).round(4)

    csv_path = RAW_DIR / "sensor_windows_metadata.csv"
    npz_path = RAW_DIR / "sensor_windows_signals.npz"

    meta_df.to_csv(csv_path, index=False)
    np.savez_compressed(
        npz_path,
        tot_acc=tot_acc,
        body_acc=body_acc,
        gyro=gyro,
    )

    summary = {
        "total_windows": int(n),
        "real_uci_windows": int((meta_df["data_source"] == "uci_har_public_real").sum()),
        "controlled_sim_windows": int((meta_df["data_source"] == "controlled_physics_simulation").sum()),
        "activity_counts": meta_df["activity_category"].value_counts().to_dict(),
        "event_category_counts": meta_df["event_category"].value_counts().to_dict(),
        "split_counts": meta_df["split_group"].value_counts().to_dict(),
    }
    (RAW_DIR / "corpus_summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print("[OK] Built unified sensor corpus:")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
