# Power BI Dashboard Specification & Setup

## Prepared Power BI Assets (`analytics/powerbi/` & `analytics/exports/`)
- **Clean Dashboard-Ready CSVs (`analytics/exports/`):** `fact_sensor_events.csv`, `fact_incidents.csv`, `fact_notifications.csv`, `dim_date.csv`, `ml_model_comparison.csv`, `ml_confusion_matrix.csv`, `sensor_timeseries_sample.csv`.
- **DAX Measures:** [DAX_Measures.dax](file:///C:/Users/Erica%20Work/Desktop/Emergency-Tracking-System/SOS-Smart-Emergency-Detection-System/analytics/powerbi/DAX_Measures.dax)
- **Power Query Import Script:** [powerbi_queries.m](file:///C:/Users/Erica%20Work/Desktop/Emergency-Tracking-System/SOS-Smart-Emergency-Detection-System/analytics/powerbi/powerbi_queries.m)
- **Theme File:** [sosense_theme.json](file:///C:/Users/Erica%20Work/Desktop/Emergency-Tracking-System/SOS-Smart-Emergency-Detection-System/analytics/powerbi/sosense_theme.json)

## 5-Page Dashboard Design

1. **Page 1 — Executive Overview:** KPI cards (`Total Sensor Events` = 11,499, `Normal Sensor Events` = 10,299, `Potential Emergency Sensor Events` = 1,200, `Confirmed Alerts`, `Canceled Alerts`, `Unanswered Alerts`, `Average Acknowledgement Time (Sec)`, `Incident False Alarm Rate (%)`) + simulation disclaimer banner (`is_simulation = 1`).
2. **Page 2 — Sensor Analytics:** Line charts from `sensor_timeseries_sample.csv` (`acc_x/y/z`, `gyro_x/y/z`, `acc_magnitude`, `gyro_magnitude` across `0..2.54s`), distribution histograms, and peak-accel vs peak-gyro scatter plots.
3. **Page 3 — Emergency Analytics:** Event counts & daily/weekly trends by `event_type`, severity stacked bar, `detection_confidence` histogram, and fall/accident candidate trendlines.
4. **Page 4 — Family Response Analytics:** `Notifications Dispatched` (419), `Notifications Acknowledged` (297), `Notification Ack Rate (%)`, primary vs secondary response latency comparison, and `Escalation Rate (%)`.
5. **Page 5 — ML Performance:** Clustered bar chart comparing `Rule-Based Baseline`, `Logistic Regression`, `Decision Tree`, `Random Forest`, and `XGBoost` (`test_accuracy`, `macro_precision`, `macro_recall`, `macro_f1`), confusion matrix heatmap (`ml_confusion_matrix.csv`), and FPR vs FNR safety chart.

**Global Slicers:** `dim_date[date_key]`, `fact_incidents[event_type]`, `fact_incidents[status]`, `fact_sensor_events[activity_category]`, `fact_sensor_events[data_source]`.

## Opening in Microsoft Power BI Desktop
1. Open Power BI Desktop -> **Get Data -> Text/CSV** (or paste `powerbi_queries.m` into Blank Query -> Advanced Editor after replacing `<REPO_ROOT>`).
2. Load all 7 CSV tables from `analytics/exports/`.
3. Import `sosense_theme.json` via **View -> Themes -> Browse for themes**.
4. Create relationships: `dim_date[date_key]` -> `fact_incidents[timestamp_utc]` (date part), `fact_incidents[incident_id]` -> `fact_notifications[incident_id]`, `fact_sensor_events[window_id]` -> `fact_incidents[window_id]`.
5. Copy measures from `DAX_Measures.dax` into a dedicated `_Measures` table and build the 5 report pages.
