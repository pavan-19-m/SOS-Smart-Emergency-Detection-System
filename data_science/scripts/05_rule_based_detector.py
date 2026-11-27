"""
05_rule_based_detector.py
Interpretable multi-stage rule-based baseline for:
  - crash_candidate (high impact >= 4.0g + high jerk / rotation + post-impact stillness)
  - fall_like (free-fall dip + impact >= 2.6g + orientation shift >= 35 deg + post-peak stillness)
  - unusual_movement (extreme rotation or prolonged near-zero inactivity)
  - normal (everyday locomotion and postures)

Used as the Stage-1 interpretable baseline and benchmark against ML models.
Never claims to guarantee detection of all real-world road accidents.
"""

from __future__ import annotations

from dataclasses import dataclass
import pandas as pd

G = 9.80665


@dataclass
class RuleDecision:
    predicted_event: str
    confidence: float
    reason: str


def classify_window_rule_based(row: pd.Series | dict) -> RuleDecision:
    acc_max_g = float(row["acc_mag_max"]) / G
    acc_min_g = float(row["acc_mag_min"]) / G
    gyro_max = float(row["gyro_mag_max"])
    orient_deg = float(row["orientation_change_deg"])
    post_quiet = float(row["post_peak_inactivity_ratio"])
    free_fall_ratio = float(row["free_fall_ratio"])
    body_std = float(row["body_acc_mag_std"])
    gyro_mean = float(row["gyro_mag_mean"])

    # Stage 1: Crash-like high-G impact candidate
    if acc_max_g >= 4.2 and gyro_max >= 3.2 and post_quiet >= 0.45:
        conf = min(0.95, 0.65 + (acc_max_g - 4.2) * 0.06)
        return RuleDecision(
            predicted_event="crash_candidate",
            confidence=round(conf, 3),
            reason=(
                f"High impact peak ({acc_max_g:.2f}g), angular spike ({gyro_max:.2f} rad/s), "
                f"and post-event stillness ({post_quiet:.0%})."
            ),
        )

    # Stage 2: Fall-like candidate (free-fall dip + impact + orientation flip + stillness)
    if (
        acc_max_g >= 2.5
        and (free_fall_ratio >= 0.04 or acc_min_g <= 0.55)
        and orient_deg >= 30.0
        and post_quiet >= 0.45
    ):
        conf = min(0.92, 0.60 + (orient_deg / 180.0) * 0.25)
        return RuleDecision(
            predicted_event="fall_like",
            confidence=round(conf, 3),
            reason=(
                f"Free-fall dip ({acc_min_g:.2f}g), impact ({acc_max_g:.2f}g), "
                f"orientation shift ({orient_deg:.1f} deg), post-fall stillness ({post_quiet:.0%})."
            ),
        )

    # Stage 3: Unusual rotational tumble or prolonged sensor inactivity
    if gyro_max >= 4.0 and acc_max_g < 4.2:
        return RuleDecision(
            predicted_event="unusual_movement",
            confidence=0.72,
            reason=f"Abnormal rotational velocity burst ({gyro_max:.2f} rad/s) without steady gait.",
        )

    if body_std < 0.05 and gyro_mean < 0.025 and float(row["inactivity_duration_sec"]) >= 2.5:
        return RuleDecision(
            predicted_event="unusual_movement",
            confidence=0.65,
            reason="Prolonged near-zero motion anomaly across full monitoring window.",
        )

    return RuleDecision(
        predicted_event="normal",
        confidence=0.88,
        reason="Motion energy, orientation, and angular velocity within normal activity bounds.",
    )


def evaluate_rule_baseline(df: pd.DataFrame) -> pd.Series:
    return df.apply(lambda r: classify_window_rule_based(r).predicted_event, axis=1)


if __name__ == "__main__":
    from pathlib import Path
    from sklearn.metrics import classification_report

    root = Path(__file__).resolve().parents[2]
    test_df = pd.read_csv(root / "data_science" / "datasets" / "testing" / "test_features.csv")
    preds = evaluate_rule_baseline(test_df)
    print("Rule-Based Baseline on Subject-Disjoint Test Set:")
    print(classification_report(test_df["event_category"], preds, digits=4, zero_division=0))
