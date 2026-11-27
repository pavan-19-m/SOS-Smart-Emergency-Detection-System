# System Architecture

SOSense uses a decoupled modular architecture separating mobile sensing/on-device inference, serverless Firebase dispatch/escalation, and offline Python/SQL/Power BI analytics.

## 1. High-Level System Architecture (Input → Processing → Output)

```mermaid
flowchart TB
    subgraph Mobile["Flutter Mobile Application (Android-First)"]
        S1[50 Hz Accelerometer & Gyroscope] --> S2[EMA Low-Pass Filter + 2.56s Window]
        S2 --> S3[20 Time-Domain Feature Extractor]
        S3 --> S4[On-Device Random Forest + Rule Baseline]
        GPS[Geolocator GPS Module] --> V1
        UI[20 Material 3 Screens / Manual SOS / Check-In] --> V1
        S4 -->|Candidate Event| V1[Verification Countdown Dialog]
        V1 -->|I'm Safe| C1[Local + Cloud Cancelled Log]
        V1 -->|Confirm or Timeout| Q1[Offline Queue / Incident Dispatcher]
    end

    subgraph Cloud["Firebase Serverless Backend"]
        Auth[Firebase Auth + App Check]
        FS[(Cloud Firestore)]
        CF[Cloud Functions: Dispatch, Ack, Escalation, Deletion]
        FCM[Firebase Cloud Messaging]
        Q1 --> FS
        FS -->|onCreate / onUpdate| CF
        CF -->|Primary then Secondary| FCM
    end

    subgraph Analytics["Data Science & BI Layer (Tracks A & B)"]
        DS1[Python Corpus + Butterworth Cleaning] --> DS2[EDA Notebook + Feature Engineering]
        DS2 --> DS3[Scikit-Learn / XGBoost / Isolation Forest]
        DS3 -->|Export JSON Model| S4
        DS3 --> SQL[(SQLite Analytics Warehouse)]
        SQL --> PBI[Power BI 5-Page Dashboard Exports]
    end
```

## 2. ML Training & Inference Workflow

```mermaid
flowchart LR
    R[UCI HAR Real 50 Hz + Controlled Physics Sim] --> C[03_clean_and_preprocess.py: Butterworth 20 Hz + Audit]
    C --> F[04_feature_engineering.py: 20 Features + Subject-Disjoint Split]
    F --> CV[GroupKFold CV on 28 Train Subjects]
    CV --> M[Rule Baseline / LogReg / DT / RF / XGBoost / Isolation Forest]
    M --> E[Evaluate on 12 Unseen Test Subjects]
    E --> X[Export sosense_inference_bundle.json -> Flutter Assets]
```

## 3. Deployment Architecture

```mermaid
flowchart LR
    Dev[Developer Repo] --> Android[Android Release APK / AAB]
    Dev --> FB[Firebase CLI: Firestore Rules, Indexes & Cloud Functions]
    Dev --> Py[Python Data & ML Pipeline -> SQLite + CSV Exports]
    Py --> PBI[Power BI Desktop Report]
```
