"""
07_build_sql_and_exports.py
Builds the relational SQLite analytics database (analytics/sosense_analytics.db),
generates clearly labeled simulation/evaluation incident & notification logs,
prepares clean Power BI-ready CSV exports in analytics/exports/,
and executes all SQL analytics queries in analytics/sql/analytics_queries.sql.
"""

from __future__ import annotations

import hashlib
import json
import sqlite3
from pathlib import Path
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
PROCESSED_PATH = ROOT / "data_science" / "datasets" / "processed" / "sensor_features_full.csv"
CLEANED_NPZ_PATH = ROOT / "data_science" / "datasets" / "cleaned" / "cleaned_sensor_windows_signals.npz"
CLEANED_META_PATH = ROOT / "data_science" / "datasets" / "cleaned" / "cleaned_sensor_windows_metadata.csv"
EXPORTS_DIR = ROOT / "analytics" / "exports"
SQL_PATH = ROOT / "analytics" / "sql" / "analytics_queries.sql"
DB_PATH = ROOT / "analytics" / "sosense_analytics.db"
REPORTS_DIR = ROOT / "data_science" / "reports"

EXPORTS_DIR.mkdir(parents=True, exist_ok=True)
REPORTS_DIR.mkdir(parents=True, exist_ok=True)


def build_simulation_incident_logs(sensor_df: pd.DataFrame, seed: int = 42) -> tuple[pd.DataFrame, pd.DataFrame]:
    """
    Creates clearly tagged simulation/evaluation incident & notification lifecycle logs
    derived from held-out sensor test detections + manual SOS & check-in scenarios.
    Strict privacy: uses SHA-256 pseudonymized user_hash, zero PII.
    """
    rng = np.random.default_rng(seed)
    test_rows = sensor_df[sensor_df["split_group"] == "test"].copy()
    non_normal = test_rows[test_rows["event_category"] != "normal"].copy()
    # Sample 40 normal windows that triggered false-alarm verification drills + all 360 non-normal test windows
    normal_drills = test_rows[test_rows["event_category"] == "normal"].sample(n=40, random_state=seed)
    combined = pd.concat([non_normal, normal_drills], ignore_index=True)

    incidents = []
    notifications = []
    base_dt = pd.Timestamp("2026-10-15T06:00:00Z")

    for idx, row in combined.iterrows():
        inc_id = f"INC-{idx + 1:04d}"
        user_hash = hashlib.sha256(f"subject_{row['subject_id']}".encode()).hexdigest()[:12]
        ts = base_dt + pd.Timedelta(hours=int(idx * 1.75), minutes=int(rng.integers(0, 59)))

        ev_cat = row["event_category"]
        if ev_cat == "fall_like":
            event_type = "possible_fall"
            det_method = "random_forest_plus_rule"
            conf = float(rng.uniform(0.76, 0.96))
        elif ev_cat == "crash_candidate":
            event_type = "possible_accident"
            det_method = "random_forest_plus_rule"
            conf = float(rng.uniform(0.82, 0.98))
        elif ev_cat == "unusual_movement":
            event_type = "unusual_movement"
            det_method = "isolation_forest_plus_rf"
            conf = float(rng.uniform(0.68, 0.91))
        else:
            event_type = "possible_fall" if idx % 2 == 0 else "unusual_movement"
            det_method = "rule_baseline_trigger"
            conf = float(rng.uniform(0.52, 0.69))

        # Outcome lifecycle (honest simulation evaluation)
        if ev_cat == "normal":
            status = "cancelled" if rng.random() < 0.8 else "false_alarm"
            user_resp = "i_am_safe"
            is_false_alarm = 1
            ack_latency = None
            esc_triggered = 0
            contacts_notified = 0 if status == "cancelled" else 1
        else:
            roll = rng.random()
            if roll < 0.62:
                status = "acknowledged"
                user_resp = "no_response_timeout"
                is_false_alarm = 0
                ack_latency = int(rng.integers(18, 115))
                esc_triggered = 0
                contacts_notified = 1
            elif roll < 0.78:
                status = "escalated"
                user_resp = "no_response_timeout"
                is_false_alarm = 0
                ack_latency = int(rng.integers(125, 240)) if rng.random() < 0.65 else None
                esc_triggered = 1
                contacts_notified = 2
            elif roll < 0.90:
                status = "cancelled"
                user_resp = "i_am_safe"
                is_false_alarm = 1
                ack_latency = None
                esc_triggered = 0
                contacts_notified = 0
            else:
                status = "dispatched"
                user_resp = "confirmed_emergency"
                is_false_alarm = 0
                ack_latency = None
                esc_triggered = 0
                contacts_notified = 1

        severity = (
            "critical"
            if event_type in ("possible_accident", "manual_sos")
            else ("high" if event_type == "possible_fall" else "medium")
        )

        incidents.append({
            "incident_id": inc_id,
            "user_hash": user_hash,
            "window_id": row["window_id"],
            "timestamp_utc": ts.isoformat(timespec="seconds"),
            "event_type": event_type,
            "severity": severity,
            "detection_method": det_method,
            "detection_confidence": round(conf, 4),
            "user_response": user_resp,
            "status": status,
            "contacts_notified_count": contacts_notified,
            "ack_latency_seconds": ack_latency,
            "escalation_triggered": esc_triggered,
            "is_false_alarm": is_false_alarm,
            "is_simulation": 1,
            "data_source": "evaluation_simulation",
        })

        # Create notification records for incidents where contacts were notified
        for c_idx in range(contacts_notified):
            prio = "primary" if c_idx == 0 else "secondary"
            ack_flag = 1 if (ack_latency is not None and (c_idx == 1 or esc_triggered == 0)) else 0
            notifications.append({
                "notification_id": f"NOTIF-{len(notifications) + 1:05d}",
                "incident_id": inc_id,
                "user_hash": user_hash,
                "timestamp_utc": (ts + pd.Timedelta(seconds=15 if c_idx == 0 else 135)).isoformat(timespec="seconds"),
                "event_type": event_type,
                "recipient_priority": prio,
                "channel": "fcm_push_simulated",
                "delivery_status": "delivered_simulated",
                "acknowledged": ack_flag,
                "response_seconds": ack_latency if ack_flag else None,
                "is_simulation": 1,
            })

    # Add 40 simulated Manual SOS and Missed Check-In evaluation events
    for j in range(40):
        inc_id = f"INC-{len(incidents) + 1:04d}"
        user_hash = hashlib.sha256(f"subject_{908 + (j % 3)}".encode()).hexdigest()[:12]
        ts = base_dt + pd.Timedelta(days=int(j % 28), hours=int(rng.integers(0, 23)))
        ev_type = "manual_sos" if j % 2 == 0 else "missed_check_in"
        ack_lat = int(rng.integers(12, 95)) if rng.random() < 0.85 else None
        status = "acknowledged" if ack_lat is not None else "escalated"
        incidents.append({
            "incident_id": inc_id,
            "user_hash": user_hash,
            "window_id": None,
            "timestamp_utc": ts.isoformat(timespec="seconds"),
            "event_type": ev_type,
            "severity": "critical" if ev_type == "manual_sos" else "high",
            "detection_method": "user_manual_trigger" if ev_type == "manual_sos" else "check_in_grace_timeout",
            "detection_confidence": 1.0,
            "user_response": "confirmed_emergency" if ev_type == "manual_sos" else "missed_check_in",
            "status": status,
            "contacts_notified_count": 1 if status == "acknowledged" else 2,
            "ack_latency_seconds": ack_lat,
            "escalation_triggered": 1 if status == "escalated" else 0,
            "is_false_alarm": 0,
            "is_simulation": 1,
            "data_source": "evaluation_simulation",
        })
        notifications.append({
            "notification_id": f"NOTIF-{len(notifications) + 1:05d}",
            "incident_id": inc_id,
            "user_hash": user_hash,
            "timestamp_utc": (ts + pd.Timedelta(seconds=2)).isoformat(timespec="seconds"),
            "event_type": ev_type,
            "recipient_priority": "primary",
            "channel": "fcm_push_simulated",
            "delivery_status": "delivered_simulated",
            "acknowledged": 1 if ack_lat is not None else 0,
            "response_seconds": ack_lat,
            "is_simulation": 1,
        })

    return pd.DataFrame(incidents), pd.DataFrame(notifications)


def export_timeseries_sample() -> pd.DataFrame:
    """Exports 1 representative window per class (128 samples each = 1,280 rows) for Power BI Page 2."""
    meta = pd.read_csv(CLEANED_META_PATH)
    npz = np.load(CLEANED_NPZ_PATH)
    tot_acc = npz["tot_acc"]
    gyro = npz["gyro"]

    rows = []
    for act in meta["activity_category"].unique():
        idx = int(meta[meta["activity_category"] == act].index[0])
        win_id = meta.loc[idx, "window_id"]
        ev_cat = meta.loc[idx, "event_category"]
        src = meta.loc[idx, "data_source"]
        for s in range(tot_acc.shape[1]):
            ax, ay, az = tot_acc[idx, s]
            gx, gy, gz = gyro[idx, s]
            rows.append({
                "window_id": win_id,
                "activity_category": act,
                "event_category": ev_cat,
                "data_source": src,
                "sample_index": s,
                "time_sec": round(s * 0.02, 2),
                "acc_x": round(float(ax), 4),
                "acc_y": round(float(ay), 4),
                "acc_z": round(float(az), 4),
                "acc_magnitude": round(float(np.sqrt(ax**2 + ay**2 + az**2)), 4),
                "gyro_x": round(float(gx), 4),
                "gyro_y": round(float(gy), 4),
                "gyro_z": round(float(gz), 4),
                "gyro_magnitude": round(float(np.sqrt(gx**2 + gy**2 + gz**2)), 4),
            })
    df_ts = pd.DataFrame(rows)
    df_ts.to_csv(EXPORTS_DIR / "sensor_timeseries_sample.csv", index=False)
    return df_ts


def run_sql_queries(conn: sqlite3.Connection) -> dict:
    sql_text = SQL_PATH.read_text(encoding="utf-8")
    statements = [s.strip() for s in sql_text.split(";") if s.strip() and not s.strip().startswith("--") or "SELECT" in s.upper()]
    results = {}
    q_idx = 1
    for stmt in sql_text.split(";"):
        clean = "\n".join(line for line in stmt.splitlines() if not line.strip().startswith("--")).strip()
        if not clean:
            continue
        cur = conn.execute(clean)
        cols = [d[0] for d in cur.description] if cur.description else []
        rows = [dict(zip(cols, r)) for r in cur.fetchall()]
        results[f"Q{q_idx}"] = {
            "sql": clean,
            "row_count": len(rows),
            "rows": rows[:25],
        }
        q_idx += 1
    return results


def main() -> None:
    sensor_df = pd.read_csv(PROCESSED_PATH)
    test_preds_df = pd.read_csv(EXPORTS_DIR / "test_predictions.csv")
    model_comp_df = pd.read_csv(EXPORTS_DIR / "ml_model_comparison.csv")
    cm_df = pd.read_csv(EXPORTS_DIR / "ml_confusion_matrix.csv")

    incidents_df, notifications_df = build_simulation_incident_logs(sensor_df)
    export_timeseries_sample()

    # Export Power BI-ready fact & dimension CSVs
    sensor_export = sensor_df.merge(
        test_preds_df[["window_id", "random_forest_pred", "random_forest_conf", "isolation_forest_is_anomaly"]],
        on="window_id",
        how="left",
    )
    sensor_export.to_csv(EXPORTS_DIR / "fact_sensor_events.csv", index=False)
    incidents_df.to_csv(EXPORTS_DIR / "fact_incidents.csv", index=False)
    notifications_df.to_csv(EXPORTS_DIR / "fact_notifications.csv", index=False)

    # Date dimension table covering all event dates
    all_dates = pd.to_datetime(
        pd.concat([
            sensor_df["timestamp_utc"].str.slice(0, 10),
            incidents_df["timestamp_utc"].str.slice(0, 10),
        ]).unique()
    ).sort_values()
    dim_date = pd.DataFrame({
        "date_key": all_dates.strftime("%Y-%m-%d"),
        "year": all_dates.year,
        "month_num": all_dates.month,
        "month_name": all_dates.strftime("%B"),
        "week_num": all_dates.isocalendar().week.astype(int),
        "day_of_week": all_dates.strftime("%A"),
    })
    dim_date.to_csv(EXPORTS_DIR / "dim_date.csv", index=False)

    # Build SQLite analytics warehouse
    if DB_PATH.exists():
        DB_PATH.unlink()

    with sqlite3.connect(DB_PATH) as conn:
        sensor_export.to_sql("sensor_events", conn, index=False, if_exists="replace")
        incidents_df.to_sql("incident_logs", conn, index=False, if_exists="replace")
        notifications_df.to_sql("notifications_log", conn, index=False, if_exists="replace")
        test_preds_df.to_sql("test_predictions", conn, index=False, if_exists="replace")
        model_comp_df.to_sql("ml_model_metrics", conn, index=False, if_exists="replace")
        cm_df.to_sql("ml_confusion_matrix", conn, index=False, if_exists="replace")

        sql_results = run_sql_queries(conn)

    (REPORTS_DIR / "sql_query_results.json").write_text(json.dumps(sql_results, indent=2), encoding="utf-8")
    print(f"[OK] Built SQLite warehouse at {DB_PATH}")
    print(f"[OK] Executed {len(sql_results)} SQL analytical queries -> data_science/reports/sql_query_results.json")
    print(f"[OK] Exported Power BI CSVs in {EXPORTS_DIR}")


if __name__ == "__main__":
    main()
