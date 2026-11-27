"""
06_train_and_evaluate_ml.py
Trains, tunes (via subject-grouped GroupKFold), benchmarks, and exports:
  1. Event Risk Classifier (4-class: normal, fall_like, crash_candidate, unusual_movement)
     comparing Rule-Based Baseline vs Logistic Regression, Decision Tree, Random Forest, XGBoost.
  2. Real-Data UCI HAR Activity Classifier (6-class real smartphone activities).
  3. Unsupervised Anomaly Detector (Isolation Forest fit ONLY on real normal windows).
  4. Portable JSON Random Forest + Scaler inference bundle for on-device Flutter inference.
"""

from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path
import joblib
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns
from sklearn.ensemble import IsolationForest, RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
)
from sklearn.model_selection import GridSearchCV, GroupKFold
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import LabelEncoder, StandardScaler
from sklearn.tree import DecisionTreeClassifier
from xgboost import XGBClassifier

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "data_science" / "scripts"))

from importlib import import_module
feat_mod = import_module("04_feature_engineering")
rule_mod = import_module("05_rule_based_detector")
FEATURE_COLUMNS = feat_mod.FEATURE_COLUMNS
evaluate_rule_baseline = rule_mod.evaluate_rule_baseline

TRAIN_PATH = ROOT / "data_science" / "datasets" / "training" / "train_features.csv"
TEST_PATH = ROOT / "data_science" / "datasets" / "testing" / "test_features.csv"
MODELS_DIR = ROOT / "data_science" / "models"
REPORTS_DIR = ROOT / "data_science" / "reports"
VIZ_DIR = ROOT / "data_science" / "visualizations"
EXPORTS_DIR = ROOT / "analytics" / "exports"
MOBILE_MODELS_DIR = ROOT / "mobile_app" / "assets" / "models"

for d in (MODELS_DIR, REPORTS_DIR, VIZ_DIR, EXPORTS_DIR, MOBILE_MODELS_DIR):
    d.mkdir(parents=True, exist_ok=True)


def compute_emergency_binary_metrics(y_true: np.ndarray, y_pred: np.ndarray, normal_label: str = "normal") -> dict:
    """Computes binary safety metrics: any non-normal event = positive (emergency candidate)."""
    yt_bin = (y_true != normal_label).astype(int)
    yp_bin = (y_pred != normal_label).astype(int)
    tn, fp, fn, tp = confusion_matrix(yt_bin, yp_bin, labels=[0, 1]).ravel()
    fpr = float(fp / max(fp + tn, 1))
    fnr = float(fn / max(fn + tp, 1))
    recall_em = float(tp / max(tp + fn, 1))
    prec_em = float(tp / max(tp + fp, 1))
    return {
        "emergency_tp": int(tp),
        "emergency_fp": int(fp),
        "emergency_tn": int(tn),
        "emergency_fn": int(fn),
        "false_positive_rate": round(fpr, 5),
        "false_negative_rate": round(fnr, 5),
        "emergency_recall": round(recall_em, 5),
        "emergency_precision": round(prec_em, 5),
    }


def export_rf_to_json(rf_model: RandomForestClassifier, classes: list[str], scaler: StandardScaler, out_path: Path) -> None:
    """Exports Random Forest decision trees + scaler parameters to portable JSON for Dart/Flutter."""
    trees = []
    for est in rf_model.estimators_:
        t = est.tree_
        trees.append({
            "children_left": t.children_left.tolist(),
            "children_right": t.children_right.tolist(),
            "feature": t.feature.tolist(),
            "threshold": [round(float(x), 6) for x in t.threshold.tolist()],
            "value": [
                [round(float(v), 6) for v in row[0]]
                for row in t.value
            ],
        })
    bundle = {
        "model_type": "RandomForestClassifier",
        "version": "1.0.0",
        "classes": classes,
        "feature_columns": FEATURE_COLUMNS,
        "scaler_mean": [round(float(x), 6) for x in scaler.mean_],
        "scaler_scale": [round(float(x), 6) for x in scaler.scale_],
        "n_estimators": len(trees),
        "trees": trees,
    }
    out_path.write_text(json.dumps(bundle), encoding="utf-8")


def main() -> None:
    train_df = pd.read_csv(TRAIN_PATH)
    test_df = pd.read_csv(TEST_PATH)

    X_train = train_df[FEATURE_COLUMNS].to_numpy(dtype=np.float32)
    X_test = test_df[FEATURE_COLUMNS].to_numpy(dtype=np.float32)
    groups_train = train_df["subject_id"].to_numpy()

    le = LabelEncoder()
    y_train = le.fit_transform(train_df["event_category"])
    y_test = le.transform(test_df["event_category"])
    classes = list(le.classes_)

    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)

    gkf = GroupKFold(n_splits=5)

    # 1. Rule-Based Baseline
    rule_preds_str = evaluate_rule_baseline(test_df).to_numpy()
    y_test_str = test_df["event_category"].to_numpy()

    results = []
    predictions_store = pd.DataFrame({
        "window_id": test_df["window_id"],
        "subject_id": test_df["subject_id"],
        "data_source": test_df["data_source"],
        "activity_category": test_df["activity_category"],
        "actual_event": y_test_str,
        "rule_based_pred": rule_preds_str,
    })

    def record_model_eval(name: str, y_true_str: np.ndarray, y_pred_str: np.ndarray, cv_f1: float | None) -> dict:
        acc = accuracy_score(y_true_str, y_pred_str)
        prec = precision_score(y_true_str, y_pred_str, average="macro", zero_division=0)
        rec = recall_score(y_true_str, y_pred_str, average="macro", zero_division=0)
        f1_mac = f1_score(y_true_str, y_pred_str, average="macro", zero_division=0)
        f1_wt = f1_score(y_true_str, y_pred_str, average="weighted", zero_division=0)
        bin_metrics = compute_emergency_binary_metrics(y_true_str, y_pred_str)
        row = {
            "model_name": name,
            "cv_macro_f1": round(cv_f1, 5) if cv_f1 is not None else None,
            "test_accuracy": round(float(acc), 5),
            "macro_precision": round(float(prec), 5),
            "macro_recall": round(float(rec), 5),
            "macro_f1": round(float(f1_mac), 5),
            "weighted_f1": round(float(f1_wt), 5),
            **bin_metrics,
        }
        results.append(row)
        return row

    record_model_eval("Rule-Based Baseline", y_test_str, rule_preds_str, cv_f1=None)

    # 2. Logistic Regression (tuned with GroupKFold)
    lr_grid = GridSearchCV(
        LogisticRegression(max_iter=1500, class_weight="balanced", random_state=42),
        param_grid={"C": [0.1, 1.0, 5.0]},
        cv=gkf,
        scoring="f1_macro",
        n_jobs=-1,
    )
    lr_grid.fit(X_train_scaled, y_train, groups=groups_train)
    lr_best = lr_grid.best_estimator_
    lr_pred = le.inverse_transform(lr_best.predict(X_test_scaled))
    predictions_store["logistic_regression_pred"] = lr_pred
    record_model_eval("Logistic Regression", y_test_str, lr_pred, cv_f1=float(lr_grid.best_score_))

    # 3. Decision Tree (tuned with GroupKFold)
    dt_grid = GridSearchCV(
        DecisionTreeClassifier(class_weight="balanced", random_state=42),
        param_grid={"max_depth": [4, 6, 10, None], "min_samples_leaf": [1, 3, 5]},
        cv=gkf,
        scoring="f1_macro",
        n_jobs=-1,
    )
    dt_grid.fit(X_train_scaled, y_train, groups=groups_train)
    dt_best = dt_grid.best_estimator_
    dt_pred = le.inverse_transform(dt_best.predict(X_test_scaled))
    predictions_store["decision_tree_pred"] = dt_pred
    record_model_eval("Decision Tree", y_test_str, dt_pred, cv_f1=float(dt_grid.best_score_))

    # 4. Random Forest (tuned with GroupKFold, depth-capped for compact mobile export)
    rf_grid = GridSearchCV(
        RandomForestClassifier(class_weight="balanced", random_state=42),
        param_grid={"n_estimators": [30, 50], "max_depth": [8, 12], "min_samples_leaf": [1, 2]},
        cv=gkf,
        scoring="f1_macro",
        n_jobs=-1,
    )
    rf_grid.fit(X_train_scaled, y_train, groups=groups_train)
    rf_best = rf_grid.best_estimator_
    rf_pred = le.inverse_transform(rf_best.predict(X_test_scaled))
    rf_probs = rf_best.predict_proba(X_test_scaled).max(axis=1)
    predictions_store["random_forest_pred"] = rf_pred
    predictions_store["random_forest_conf"] = np.round(rf_probs, 4)
    record_model_eval("Random Forest", y_test_str, rf_pred, cv_f1=float(rf_grid.best_score_))

    # 5. XGBoost (tuned with GroupKFold)
    xgb_grid = GridSearchCV(
        XGBClassifier(
            eval_metric="mlogloss",
            random_state=42,
            n_jobs=2,
        ),
        param_grid={"n_estimators": [50, 100], "max_depth": [4, 6], "learning_rate": [0.1, 0.2]},
        cv=gkf,
        scoring="f1_macro",
        n_jobs=-1,
    )
    xgb_grid.fit(X_train_scaled, y_train, groups=groups_train)
    xgb_best = xgb_grid.best_estimator_
    xgb_pred = le.inverse_transform(xgb_best.predict(X_test_scaled))
    predictions_store["xgboost_pred"] = xgb_pred
    record_model_eval("XGBoost", y_test_str, xgb_pred, cv_f1=float(xgb_grid.best_score_))

    # 6. Isolation Forest (Unsupervised anomaly detection fit ONLY on real UCI normal train data)
    real_normal_train = train_df[
        (train_df["data_source"] == "uci_har_public_real") & (train_df["event_category"] == "normal")
    ]
    X_real_norm = scaler.transform(real_normal_train[FEATURE_COLUMNS].to_numpy(dtype=np.float32))
    iso_forest = IsolationForest(n_estimators=100, contamination=0.02, random_state=42)
    iso_forest.fit(X_real_norm)
    iso_raw = iso_forest.predict(X_test_scaled)  # 1 = normal, -1 = anomaly
    iso_pred_bin = np.where(iso_raw == -1, "unusual_movement", "normal")
    iso_bin_metrics = compute_emergency_binary_metrics(y_test_str, iso_pred_bin)
    predictions_store["isolation_forest_is_anomaly"] = (iso_raw == -1).astype(int)

    # 7. Real-Only UCI HAR 6-Class Activity Recognition Benchmark (100% real data, zero simulation)
    uci_train = train_df[train_df["data_source"] == "uci_har_public_real"]
    uci_test = test_df[test_df["data_source"] == "uci_har_public_real"]
    uci_le = LabelEncoder()
    y_uci_train = uci_le.fit_transform(uci_train["activity_category"])
    y_uci_test = uci_le.transform(uci_test["activity_category"])
    uci_pipe = Pipeline([
        ("scaler", StandardScaler()),
        ("rf", RandomForestClassifier(n_estimators=80, max_depth=14, random_state=42)),
    ])
    uci_pipe.fit(uci_train[FEATURE_COLUMNS], y_uci_train)
    uci_pred = uci_pipe.predict(uci_test[FEATURE_COLUMNS])
    uci_metrics = {
        "real_only_test_samples": int(len(uci_test)),
        "accuracy": round(float(accuracy_score(y_uci_test, uci_pred)), 5),
        "macro_f1": round(float(f1_score(y_uci_test, uci_pred, average="macro")), 5),
        "classification_report": classification_report(
            y_uci_test, uci_pred, target_names=list(uci_le.classes_), output_dict=True
        ),
    }

    # Save models & exports
    joblib.dump({"model": rf_best, "label_encoder": le, "scaler": scaler}, MODELS_DIR / "best_event_classifier.joblib")
    joblib.dump({"model": xgb_best, "label_encoder": le, "scaler": scaler}, MODELS_DIR / "xgboost_event_classifier.joblib")
    joblib.dump({"model": uci_pipe, "label_encoder": uci_le}, MODELS_DIR / "uci_activity_classifier.joblib")
    joblib.dump({"model": iso_forest, "scaler": scaler}, MODELS_DIR / "isolation_forest.joblib")

    # Export portable Random Forest bundle for Flutter local inference
    bundle_path = MODELS_DIR / "sosense_inference_bundle.json"
    export_rf_to_json(rf_best, classes, scaler, bundle_path)
    shutil.copy2(bundle_path, MOBILE_MODELS_DIR / "sosense_inference_bundle.json")

    results_df = pd.DataFrame(results)
    results_df.to_csv(EXPORTS_DIR / "ml_model_comparison.csv", index=False)
    predictions_store.to_csv(EXPORTS_DIR / "test_predictions.csv", index=False)

    # Confusion matrix for Random Forest (mobile-deployed model) & XGBoost
    cm_rf = confusion_matrix(y_test_str, rf_pred, labels=classes)
    cm_rows = []
    for i, actual_lbl in enumerate(classes):
        for j, pred_lbl in enumerate(classes):
            cm_rows.append({
                "model_name": "Random Forest",
                "actual_class": actual_lbl,
                "predicted_class": pred_lbl,
                "count": int(cm_rf[i, j]),
            })
    pd.DataFrame(cm_rows).to_csv(EXPORTS_DIR / "ml_confusion_matrix.csv", index=False)

    # Save evaluation report JSON
    eval_summary = {
        "model_comparison": results,
        "best_ml_hyperparameters": {
            "logistic_regression": lr_grid.best_params_,
            "decision_tree": dt_grid.best_params_,
            "random_forest": rf_grid.best_params_,
            "xgboost": xgb_grid.best_params_,
        },
        "isolation_forest_binary_emergency_eval": iso_bin_metrics,
        "uci_har_real_only_6class_eval": uci_metrics,
        "mobile_deployed_model": "Random Forest (exported to sosense_inference_bundle.json)",
        "classes": classes,
        "confusion_matrix_random_forest": cm_rf.tolist(),
    }
    (REPORTS_DIR / "ml_evaluation_results.json").write_text(json.dumps(eval_summary, indent=2), encoding="utf-8")

    # --- Visualizations ---
    sns.set_theme(style="whitegrid")

    # 1. Model Comparison Bar Chart
    fig, ax = plt.subplots(figsize=(10, 5.5))
    plot_df = results_df.melt(
        id_vars="model_name",
        value_vars=["test_accuracy", "macro_precision", "macro_recall", "macro_f1"],
        var_name="Metric",
        value_name="Score",
    )
    sns.barplot(data=plot_df, x="model_name", y="Score", hue="Metric", ax=ax, palette="viridis")
    ax.set_ylim(0, 1.08)
    ax.set_title("SOSense Model Performance Comparison (Subject-Disjoint Test Set)")
    ax.set_xlabel("Model")
    ax.set_ylabel("Score")
    plt.xticks(rotation=15)
    plt.tight_layout()
    fig.savefig(VIZ_DIR / "model_comparison_metrics.png", dpi=150)
    plt.close(fig)

    # 2. Confusion Matrix Heatmap (Random Forest)
    fig, ax = plt.subplots(figsize=(7, 5.5))
    sns.heatmap(cm_rf, annot=True, fmt="d", cmap="Blues", xticklabels=classes, yticklabels=classes, ax=ax)
    ax.set_title("Random Forest Confusion Matrix (Subject-Disjoint Test Set)")
    ax.set_xlabel("Predicted Event Category")
    ax.set_ylabel("Actual Event Category")
    plt.tight_layout()
    fig.savefig(VIZ_DIR / "confusion_matrix_random_forest.png", dpi=150)
    plt.close(fig)

    # 3. Feature Importance (Random Forest)
    importances = pd.Series(rf_best.feature_importances_, index=FEATURE_COLUMNS).sort_values(ascending=True)
    fig, ax = plt.subplots(figsize=(9, 6.5))
    importances.plot(kind="barh", color="#1D4ED8", ax=ax)
    ax.set_title("Random Forest Feature Importances (Time-Domain Sensor Features)")
    ax.set_xlabel("Mean Decrease in Impurity")
    plt.tight_layout()
    fig.savefig(VIZ_DIR / "feature_importance_rf.png", dpi=150)
    plt.close(fig)

    # 4. False-Positive vs False-Negative Tradeoff
    fig, ax = plt.subplots(figsize=(8.5, 5))
    trade_df = results_df.melt(
        id_vars="model_name",
        value_vars=["false_positive_rate", "false_negative_rate"],
        var_name="Error Type",
        value_name="Rate",
    )
    sns.barplot(data=trade_df, x="model_name", y="Rate", hue="Error Type", ax=ax, palette=["#F59E0B", "#DC2626"])
    ax.set_title("Safety-Critical Error Analysis: False-Positive Rate vs Missed-Emergency Rate")
    ax.set_xlabel("Model")
    ax.set_ylabel("Error Rate")
    plt.xticks(rotation=15)
    plt.tight_layout()
    fig.savefig(VIZ_DIR / "false_alarm_vs_missed_emergency.png", dpi=150)
    plt.close(fig)

    print("[OK] ML Training & Evaluation Complete:")
    print(results_df.to_string(index=False))
    print(f"\n[OK] Isolation Forest binary eval: {iso_bin_metrics}")
    print(f"[OK] Real-Only UCI HAR 6-Class Accuracy: {uci_metrics['accuracy']}, Macro F1: {uci_metrics['macro_f1']}")


if __name__ == "__main__":
    main()
