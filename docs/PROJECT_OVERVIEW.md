# Project Overview

## Identity
- **Project Name:** SOS — Intelligent Sensor-Based Emergency Detection & Data Analytics System
- **Application Name:** SOSense
- **Primary Tracks:**
  - **Track A (AI/ML Engineering):** Real-time 50 Hz sensor signal processing, feature extraction, rule-based + Random Forest classification, Isolation Forest anomaly detection, and pure-Dart on-device inference.
  - **Track B (Data Science & Analytics):** Data engineering, quality auditing, EDA notebook, SQLite relational analytics, Power BI dashboard specifications, and model error analysis.

## End-to-End Capabilities
1. **User Authentication & Profile:** Form-validated sign-in/registration, password reset, emergency medical notes, and full account deletion.
2. **Sensor Monitoring & Verification:** Continuous foreground accelerometer/gyroscope streaming with a configurable countdown prompt ("Are you okay?") before notifying contacts.
3. **Manual SOS & Safe Check-In:** One-tap/long-press SOS plus timed solo-travel check-in sessions with grace periods.
4. **Family Alerting & Escalation:** Primary contact notification first via Firebase Cloud Messaging, escalating to secondary contacts if unacknowledged.
5. **Offline & Demo Resilience:** Local incident queue with duplicate suppression and a 10-scenario safe Demo Center that never sends real alerts.
