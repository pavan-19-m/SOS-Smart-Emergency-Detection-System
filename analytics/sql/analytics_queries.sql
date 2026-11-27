-- SOSense Relational Analytics Queries (SQLite / ANSI-compatible)
-- Executed against analytics/sosense_analytics.db

-- Q1: Total sensor events processed by data source & event category
SELECT
    data_source,
    event_category,
    COUNT(*) AS total_windows,
    ROUND(AVG(acc_mag_max), 3) AS avg_peak_acc_ms2,
    ROUND(MAX(acc_mag_max), 3) AS max_peak_acc_ms2,
    ROUND(AVG(gyro_mag_max), 3) AS avg_peak_gyro_rads
FROM sensor_events
GROUP BY data_source, event_category
ORDER BY total_windows DESC;

-- Q2: Total potential emergencies vs normal events
SELECT
    CASE WHEN event_category = 'normal' THEN 'Normal' ELSE 'Potential Emergency' END AS classification_group,
    COUNT(*) AS event_count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM sensor_events), 2) AS pct_share
FROM sensor_events
GROUP BY classification_group;

-- Q3: Incident counts by event type and simulation tag
SELECT
    event_type,
    is_simulation,
    COUNT(*) AS incident_count,
    SUM(CASE WHEN status = 'acknowledged' THEN 1 ELSE 0 END) AS acknowledged_count,
    SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled_count,
    SUM(CASE WHEN status = 'escalated' THEN 1 ELSE 0 END) AS escalated_count,
    SUM(CASE WHEN is_false_alarm = 1 THEN 1 ELSE 0 END) AS false_alarm_count
FROM incident_logs
GROUP BY event_type, is_simulation
ORDER BY incident_count DESC;

-- Q4: Daily event counts (Sensor Events + Incidents)
SELECT
    substr(timestamp_utc, 1, 10) AS event_date,
    COUNT(*) AS total_incidents,
    SUM(CASE WHEN status IN ('dispatched', 'acknowledged', 'escalated', 'resolved') THEN 1 ELSE 0 END) AS confirmed_or_dispatched,
    SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) AS user_cancelled
FROM incident_logs
GROUP BY event_date
ORDER BY event_date ASC;

-- Q5: Weekly incident trends
SELECT
    strftime('%Y-W%W', timestamp_utc) AS iso_week,
    COUNT(*) AS weekly_incidents,
    SUM(CASE WHEN event_type = 'possible_fall' THEN 1 ELSE 0 END) AS fall_candidates,
    SUM(CASE WHEN event_type = 'possible_accident' THEN 1 ELSE 0 END) AS accident_candidates,
    SUM(CASE WHEN event_type = 'manual_sos' THEN 1 ELSE 0 END) AS manual_sos_count
FROM incident_logs
GROUP BY iso_week
ORDER BY iso_week ASC;

-- Q6: Monthly incident trends
SELECT
    strftime('%Y-%m', timestamp_utc) AS year_month,
    COUNT(*) AS monthly_incidents,
    ROUND(AVG(detection_confidence), 3) AS avg_confidence
FROM incident_logs
GROUP BY year_month
ORDER BY year_month ASC;

-- Q7: False alarm frequency and detection cancellation rate
SELECT
    event_type,
    COUNT(*) AS total_detected,
    SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled_by_user,
    ROUND(100.0 * SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) / COUNT(*), 2) AS cancellation_rate_pct,
    SUM(CASE WHEN is_false_alarm = 1 THEN 1 ELSE 0 END) AS confirmed_false_alarms,
    ROUND(100.0 * SUM(CASE WHEN is_false_alarm = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS false_alarm_rate_pct
FROM incident_logs
GROUP BY event_type
ORDER BY cancellation_rate_pct DESC;

-- Q8: Alert acknowledgement time statistics (seconds)
SELECT
    event_type,
    COUNT(*) AS acknowledged_alerts,
    ROUND(AVG(ack_latency_seconds), 2) AS avg_ack_seconds,
    MIN(ack_latency_seconds) AS min_ack_seconds,
    MAX(ack_latency_seconds) AS max_ack_seconds
FROM incident_logs
WHERE ack_latency_seconds IS NOT NULL
GROUP BY event_type
ORDER BY avg_ack_seconds ASC;

-- Q9: Unacknowledged alerts & escalated incidents
SELECT
    incident_id,
    event_type,
    status,
    timestamp_utc,
    contacts_notified_count,
    escalation_triggered
FROM incident_logs
WHERE status IN ('dispatched', 'escalated', 'unanswered')
  AND ack_latency_seconds IS NULL
ORDER BY timestamp_utc DESC
LIMIT 25;

-- Q10: Emergency response & contact priority statistics
SELECT
    recipient_priority,
    COUNT(*) AS notifications_sent,
    SUM(CASE WHEN acknowledged = 1 THEN 1 ELSE 0 END) AS notifications_acknowledged,
    ROUND(100.0 * SUM(CASE WHEN acknowledged = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS ack_rate_pct,
    ROUND(AVG(CASE WHEN acknowledged = 1 THEN response_seconds END), 2) AS avg_response_seconds
FROM notifications_log
GROUP BY recipient_priority;

-- Q11: Model prediction distribution on held-out test set
SELECT
    actual_event,
    random_forest_pred,
    COUNT(*) AS window_count,
    ROUND(AVG(random_forest_conf), 4) AS avg_confidence
FROM test_predictions
GROUP BY actual_event, random_forest_pred
ORDER BY actual_event, window_count DESC;

-- Q12: Detection performance comparison across evaluated models
SELECT
    model_name,
    test_accuracy,
    macro_precision,
    macro_recall,
    macro_f1,
    false_positive_rate,
    false_negative_rate
FROM ml_model_metrics
ORDER BY macro_f1 DESC;
