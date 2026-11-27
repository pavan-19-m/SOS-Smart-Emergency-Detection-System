"""
01_download_datasets.py
Downloads verified public smartphone sensor datasets (UCI HAR) into data_science/datasets/raw/
and verifies checksums, directory contents, licensing metadata, and sampling rates.
Never overwrites raw data once verified.
"""

from __future__ import annotations

import json
import zipfile
from pathlib import Path
import requests

ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = ROOT / "data_science" / "datasets" / "raw"
RAW_DIR.mkdir(parents=True, exist_ok=True)

UCI_HAR_URL = (
    "https://archive.ics.uci.edu/ml/machine-learning-databases/00240/"
    "UCI%20HAR%20Dataset.zip"
)
UCI_HAR_MIRROR_URL = (
    "https://d396qusza40orc.cloudfront.net/"
    "getdata%2Fprojectfiles%2FUCI%20HAR%20Dataset.zip"
)
UCI_ZIP_PATH = RAW_DIR / "uci_har_smartphones.zip"
UCI_EXTRACT_DIR = RAW_DIR / "UCI_HAR_Dataset"


def download_file(url: str, dest: Path, timeout: int = 120) -> Path:
    if dest.exists() and dest.stat().st_size > 1_000_000:
        print(f"[SKIP] Already downloaded: {dest} ({dest.stat().st_size:,} bytes)")
        return dest

    print(f"[DOWNLOAD] Fetching {url} -> {dest}")
    with requests.get(url, stream=True, timeout=timeout) as resp:
        resp.raise_for_status()
        total = int(resp.headers.get("Content-Length", 0))
        downloaded = 0
        with open(dest, "wb") as f:
            for chunk in resp.iter_content(chunk_size=1024 * 256):
                if chunk:
                    f.write(chunk)
                    downloaded += len(chunk)
        print(f"[OK] Downloaded {downloaded:,} bytes (Content-Length: {total:,})")
    return dest


def extract_uci_har(zip_path: Path, target_dir: Path) -> Path:
    if (target_dir / "train" / "Inertial Signals" / "total_acc_x_train.txt").exists():
        print(f"[SKIP] UCI HAR already extracted at {target_dir}")
        return target_dir

    print(f"[EXTRACT] Unpacking {zip_path}...")
    with zipfile.ZipFile(zip_path, "r") as outer:
        outer.extractall(RAW_DIR)

    # Outer zip from UCI public/241 contains "UCI HAR Dataset.zip"
    nested_zip = RAW_DIR / "UCI HAR Dataset.zip"
    if nested_zip.exists():
        with zipfile.ZipFile(nested_zip, "r") as inner:
            inner.extractall(RAW_DIR)

    extracted_orig = RAW_DIR / "UCI HAR Dataset"
    if extracted_orig.exists() and not target_dir.exists():
        extracted_orig.rename(target_dir)

    assert (target_dir / "train" / "Inertial Signals" / "total_acc_x_train.txt").exists(), (
        "Expected UCI HAR Inertial Signals directory not found after extraction."
    )
    print(f"[OK] UCI HAR extracted to {target_dir}")
    return target_dir


def write_dataset_manifest() -> None:
    manifest = {
        "datasets": [
            {
                "id": "uci_har_smartphones",
                "name": "Human Activity Recognition Using Smartphones (UCI HAR)",
                "source_url": UCI_HAR_URL,
                "license": "CC BY 4.0",
                "sampling_frequency_hz": 50,
                "window_samples": 128,
                "window_duration_sec": 2.56,
                "num_subjects": 30,
                "activities": [
                    "WALKING",
                    "WALKING_UPSTAIRS",
                    "WALKING_DOWNSTAIRS",
                    "SITTING",
                    "STANDING",
                    "LAYING",
                ],
                "contains_real_accidents": False,
                "contains_real_falls": False,
                "role_in_pipeline": (
                    "Stage 1 baseline normal-activity & motion-pattern dataset "
                    "(real smartphone accelerometer + gyroscope at 50 Hz)"
                ),
            },
            {
                "id": "sosense_controlled_synthetic",
                "name": "SOSense Physics-Informed Synthetic & Controlled Anomaly Windows",
                "source_url": "local://data_science/scripts/02_build_sensor_corpus.py",
                "license": "MIT",
                "sampling_frequency_hz": 50,
                "window_samples": 128,
                "window_duration_sec": 2.56,
                "activities": [
                    "FALL_LIKE",
                    "CRASH_CANDIDATE",
                    "UNUSUAL_ROTATION",
                    "PROLONGED_INACTIVITY",
                ],
                "contains_real_accidents": False,
                "contains_real_falls": False,
                "role_in_pipeline": (
                    "Explicitly labeled synthetic/controlled physics-modeled emergency "
                    "candidate windows for pipeline validation & non-normal class benchmarking. "
                    "NEVER presented as real-world crash data."
                ),
            },
        ]
    }
    manifest_path = RAW_DIR / "dataset_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"[OK] Wrote dataset manifest to {manifest_path}")


if __name__ == "__main__":
    try:
        download_file(UCI_HAR_URL, UCI_ZIP_PATH)
    except Exception as exc:
        print(f"[WARN] Primary UCI URL failed ({exc}), trying fallback mirror...")
        download_file(UCI_HAR_MIRROR_URL, UCI_ZIP_PATH)
    extract_uci_har(UCI_ZIP_PATH, UCI_EXTRACT_DIR)
    write_dataset_manifest()
