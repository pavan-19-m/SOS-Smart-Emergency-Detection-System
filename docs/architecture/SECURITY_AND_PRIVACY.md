# Security and Privacy Architecture

1. **Authentication & Credential Hygiene:**
   - Managed exclusively via **Firebase Authentication**.
   - `firestore.rules` explicitly enforces `hasNoForbiddenSecretFields` rejecting any document containing `password`, `passwordHash`, `rawPassword`, or `secretToken`.
2. **Least-Privilege Firestore Rules (`backend/firestore.rules`):**
   - `users/{userId}` and `users/{userId}/contacts/{contactId}`: Readable and writable only by the owning authenticated user (`request.auth.uid == userId`).
   - `incidents/{incidentId}`: Readable by owner or authorized family contacts (`authorizedContactUids` / `authorizedContactEmails`). Contacts may only update `status`, `acknowledgedBy`, `acknowledgedAt`, and `updatedAt`.
   - `notifications/{notificationId}`: Client `create` and `delete` are completely blocked (`allow create, delete: if false`); only Firebase Admin SDK inside Cloud Functions can create notification records.
3. **Demo Mode Isolation:** Both client (`NotificationService`) and server (`handleIncidentCreated`) enforce `if (incident.isSimulation === true)` to suppress all external FCM push dispatches.
4. **Location Privacy:** Stale or cached coordinates are flagged `isStale: true` and excluded from Google Maps dispatch links (`buildMapsLink` returns `null` when `isStale === true`).
5. **Analytics Anonymization:** All analytics CSVs and SQLite tables use SHA-256 truncated `user_hash` identifiers and contain zero names, emails, phone numbers, or GPS coordinates. `firestore.rules` blocks PII fields in `analytics_anonymized`.
6. **Account & Data Deletion:** `EmergencyProfileScreen` and Cloud Function `deleteUserAccountData` delete user profiles, contacts, incidents, safety sessions, and Firebase Auth accounts cleanly.
