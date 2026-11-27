# Deployment Guide

## 1. Python Data Science & Analytics Artifacts
All data cleaning, feature engineering, ML training, SQLite warehouse creation, and Power BI CSV exports are reproducible locally:
```powershell
.venv\Scripts\python.exe data_science\scripts\01_download_datasets.py
.venv\Scripts\python.exe data_science\scripts\02_build_sensor_corpus.py
.venv\Scripts\python.exe data_science\scripts\03_clean_and_preprocess.py
.venv\Scripts\python.exe data_science\scripts\04_feature_engineering.py
.venv\Scripts\python.exe data_science\scripts\06_train_and_evaluate_ml.py
.venv\Scripts\python.exe data_science\scripts\07_build_sql_and_exports.py
```

## 2. Firebase Backend Deployment
1. Install Firebase CLI (`npm install -g firebase-tools`) and authenticate (`firebase login`).
2. Install function dependencies: `cd backend/functions && npm install`.
3. Validate locally: `npm run lint && npm test`.
4. Deploy: `cd backend && firebase deploy --only firestore:rules,firestore:indexes,functions`.

## 3. Android Release Build (APK & App Bundle)
*Requires Flutter SDK (>=3.22) and Android SDK (API 34) installed locally:*
```powershell
cd mobile_app
flutter pub get
flutter analyze
flutter test
flutter build apk --release
flutter build appbundle --release
```
Configure `mobile_app/android/key.properties` (git-ignored) with your upload keystore before Play Store distribution.
- Output paths after build:
  - Debug/Release APK: `mobile_app/build/app/outputs/flutter-apk/app-release.apk`
  - Android App Bundle: `mobile_app/build/app/outputs/bundle/release/app-release.aab`

## 4. Power BI Dashboard Publishing
Open `analytics/exports/*.csv` in Microsoft Power BI Desktop, apply `analytics/powerbi/sosense_theme.json`, paste measures from `analytics/powerbi/DAX_Measures.dax`, save as `.pbix`, and optionally publish to Power BI Service.
