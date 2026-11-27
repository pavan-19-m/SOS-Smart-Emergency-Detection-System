# Firebase Setup Guide

## 1. Create & Configure Firebase Project
1. Open [Firebase Console](https://console.firebase.google.com/) and create a project (e.g., `sosense-emergency-prod`).
2. Enable **Authentication** -> **Email/Password** provider.
3. Enable **Cloud Firestore** in production mode.
4. Enable **Firebase Cloud Messaging (FCM)** and **Firebase App Check** (Play Integrity for Android).
5. Upgrade project to **Blaze Plan** if deploying scheduled Cloud Functions (`onSchedule("every 1 minutes")`).

## 2. Connect Android App
1. Register Android package ID `com.sosense.emergency_tracking` in Firebase Console.
2. Download `google-services.json` and place it at `mobile_app/android/app/google-services.json` (git-ignored).
3. Copy `.env.example` to `.env` and populate project IDs (never commit `.env` or service account keys).

## 3. Deploy Rules, Indexes & Functions
```powershell
npm install -g firebase-tools
firebase login
firebase use --add <your-project-id>
cd backend/functions && npm install && cd ..
firebase deploy --only firestore:rules,firestore:indexes,functions
```
