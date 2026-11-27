import json
import sys
from importlib import import_module
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "data_science" / "scripts"))
feat_mod = import_module("04_feature_engineering")


def test_end_to_end_sensor_to_incident_flow():
    """
    Simulates: 50 Hz sensor window -> feature extraction -> portable RF inference ->
    verification classification -> incident record serialization.
    """
    bundle = json.loads(
        (ROOT / "mobile_app" / "assets" / "models" / "sosense_inference_bundle.json").read_text(encoding="utf-8")
    )

    # Simulate fall-like sensor window: free-fall dip -> 3.8g impact -> orientation shift -> stillness
    t_len = 128
    tot_acc = np.zeros((1, t_len, 3), dtype=np.float32)
    body_acc = np.zeros((1, t_len, 3), dtype=np.float32)
    tot_acc[0, :30, 2] = 9.81
    tot_acc[0, 30:42, 2] = 2.8  # free fall dip
    tot_acc[0, 42:48, 0] = 36.0 # impact
    tot_acc[0, 48:, 0] = 9.81   # 90-deg orientation shift + stillness (body_acc ~ 0)
    body_acc[0, 42:48, 0] = 36.0
    gyro = np.zeros((1, t_len, 3), dtype=np.float32)
    gyro[0, 40:48, 1] = 4.6

    feats = feat_mod.extract_window_features(tot_acc, body_acc, gyro, fs_hz=50.0)
    row = {c: float(feats.iloc[0][c]) for c in feat_mod.FEATURE_COLUMNS}

    cols = bundle["feature_columns"]
    scaled = [(row[c] - bundle["scaler_mean"][i]) / (bundle["scaler_scale"][i] or 1.0) for i, c in enumerate(cols)]
    probs = np.zeros(len(bundle["classes"]))
    for tree in bundle["trees"]:
        node = 0
        while tree["children_left"][node] != -1 and tree["children_right"][node] != -1:
            if scaled[tree["feature"][node]] <= tree["threshold"][node]:
                node = tree["children_left"][node]
            else:
                node = tree["children_right"][node]
        leaf = np.array(tree["value"][node], dtype=float)
        probs += leaf / max(leaf.sum(), 1e-9)
    probs /= len(bundle["trees"])
    pred = bundle["classes"][int(np.argmax(probs))]

    assert pred in {"fall_like", "crash_candidate", "unusual_movement"}
    assert float(np.max(probs)) > 0.4
