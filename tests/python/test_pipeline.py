import json
import sqlite3
import sys
from importlib import import_module
from pathlib import Path
import joblib
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "data_science" / "scripts"))

feat_mod = import_module("04_feature_engineering")
rule_mod = import_module("05_rule_based_detector")


def predict_from_json_bundle(bundle: dict, feature_row: dict[str, float]) -> tuple[str, float]:
    """Mirrors the Dart MlInferenceService tree traversal for train/serve parity verification."""
    cols = bundle["feature_columns"]
    mean = bundle["scaler_mean"]
    scale = bundle["scaler_scale"]
    scaled = [(feature_row[c] - mean[i]) / (scale[i] or 1.0) for i, c in enumerate(cols)]

    classes = bundle["classes"]
    probs = np.zeros(len(classes), dtype=float)
    for tree in bundle["trees"]:
        node = 0
        while tree["children_left"][node] != -1 and tree["children_right"][node] != -1:
            f_idx = tree["feature"][node]
            if scaled[f_idx] <= tree["threshold"][node]:
                node = tree["children_left"][node]
            else:
                node = tree["children_right"][node]
        leaf = np.array(tree["value"][node], dtype=float)
        probs += leaf / max(leaf.sum(), 1e-9)
    probs /= len(bundle["trees"])
    best = int(np.argmax(probs))
    return classes[best], float(probs[best])


def test_data_cleaning_and_quality_report():
    report_path = ROOT / "data_science" / "reports" / "data_quality_report.json"
    assert report_path.exists()
    report = json.loads(report_path.read_text(encoding="utf-8"))
    after = report["after_cleaning"]
    assert after["row_count"] == 11499
    assert after["missing_metadata_cells"] == 0
    assert after["non_finite_acc_values"] == 0
    assert after["non_finite_gyro_values"] == 0
    assert after["invalid_timestamps"] == 0
    assert after["inconsistent_sampling_windows"] == 0


def test_subject_disjoint_split_zero_leakage():
    train_df = pd.read_csv(ROOT / "data_science" / "datasets" / "training" / "train_features.csv")
    test_df = pd.read_csv(ROOT / "data_science" / "datasets" / "testing" / "test_features.csv")

    train_subjects = set(train_df["subject_id"].unique())
    test_subjects = set(test_df["subject_id"].unique())
    assert len(train_subjects.intersection(test_subjects)) == 0
    assert not train_df[feat_mod.FEATURE_COLUMNS].isna().any().any()
    assert not test_df[feat_mod.FEATURE_COLUMNS].isna().any().any()


def test_data_source_provenance_honesty():
    df = pd.read_csv(ROOT / "data_science" / "datasets" / "processed" / "sensor_features_full.csv")
    sources = set(df["data_source"].unique())
    assert sources == {"uci_har_public_real", "controlled_physics_simulation"}
    real_events = set(df[df["data_source"] == "uci_har_public_real"]["event_category"].unique())
    assert real_events == {"normal"}


def test_feature_extraction_and_rule_detector():
    # Construct synthetic crash-like window (1, 128, 3)
    tot_acc = np.zeros((1, 128, 3), dtype=np.float32)
    tot_acc[:, :, 2] = 9.81
    tot_acc[0, 40:44, 0] = 65.0
    body_acc = tot_acc.copy()
    body_acc[:, :, 2] -= 9.81
    gyro = np.zeros((1, 128, 3), dtype=np.float32)
    gyro[0, 40:44, 1] = 5.5

    feats = feat_mod.extract_window_features(tot_acc, body_acc, gyro, fs_hz=50.0)
    assert list(feats.columns) == feat_mod.FEATURE_COLUMNS
    decision = rule_mod.classify_window_rule_based(feats.iloc[0])
    assert decision.predicted_event == "crash_candidate"
    assert decision.confidence >= 0.65


def test_sklearn_to_json_inference_parity():
    bundle_path = ROOT / "mobile_app" / "assets" / "models" / "sosense_inference_bundle.json"
    assert bundle_path.exists()
    bundle = json.loads(bundle_path.read_text(encoding="utf-8"))

    saved = joblib.load(ROOT / "data_science" / "models" / "best_event_classifier.joblib")
    rf = saved["model"]
    le = saved["label_encoder"]
    scaler = saved["scaler"]

    test_df = pd.read_csv(ROOT / "data_science" / "datasets" / "testing" / "test_features.csv").sample(40, random_state=7)
    X_scaled = scaler.transform(test_df[feat_mod.FEATURE_COLUMNS].to_numpy(dtype=np.float32))
    sk_preds = le.inverse_transform(rf.predict(X_scaled))

    for i, (_, row) in enumerate(test_df.iterrows()):
        row_dict = {c: float(row[c]) for c in feat_mod.FEATURE_COLUMNS}
        json_pred, _ = predict_from_json_bundle(bundle, row_dict)
        assert json_pred == sk_preds[i]


def test_sql_database_and_powerbi_exports():
    db_path = ROOT / "analytics" / "sosense_analytics.db"
    assert db_path.exists()
    with sqlite3.connect(db_path) as conn:
        tables = {r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()}
        assert {"sensor_events", "incident_logs", "notifications_log", "ml_model_metrics", "ml_confusion_matrix"}.issubset(tables)
        cnt = conn.execute("SELECT COUNT(*) FROM sensor_events").fetchone()[0]
        assert cnt == 11499

    exports = ROOT / "analytics" / "exports"
    for fname in [
        "fact_sensor_events.csv",
        "fact_incidents.csv",
        "fact_notifications.csv",
        "dim_date.csv",
        "ml_model_comparison.csv",
        "ml_confusion_matrix.csv",
        "sensor_timeseries_sample.csv",
    ]:
        assert (exports / fname).exists(), f"Missing export: {fname}"


def test_firestore_security_rules_policy():
    rules = (ROOT / "backend" / "firestore.rules").read_text(encoding="utf-8")
    assert "hasNoForbiddenSecretFields" in rules
    assert "passwordHash" in rules
    assert "allow create, delete: if false;" in rules  # notifications locked from client writes
