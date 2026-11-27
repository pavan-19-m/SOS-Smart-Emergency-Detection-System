/**
 * Firebase Cloud Functions entry point for SOSense.
 */

const admin = require("firebase-admin");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const safetySnapshot = require("../safety_summary.json");
const safetyRegistry = require("../safety_registry.json");
const { handleSafetyRequest } = require("./safetyService");

const {
  handleIncidentCreated,
  handleAcknowledgeIncident,
  handleEscalationSweep,
} = require("./emergencyService");

admin.initializeApp();

// Public, aggregate historical data only. This endpoint never accepts or stores
// user GPS coordinates and does not expose incident-level records.
exports.safetyData = onRequest({ cors: true }, (request, response) => {
  response.set("Cache-Control", "public, max-age=300, stale-while-revalidate=3600");
  response.set("X-Content-Type-Options", "nosniff");
  const path = request.path.replace(/\/$/, "");
  const result = handleSafetyRequest({ method: request.method, path, snapshot: safetySnapshot, registry: safetyRegistry });
  if (result.status === 405) response.set("Allow", "GET");
  response.status(result.status).json(result.body);
});

exports.onIncidentCreated = onDocumentCreated("incidents/{incidentId}", async (event) => {
  const snap = event.data;
  if (!snap) return null;
  const db = admin.firestore();
  const messaging = admin.messaging();
  return handleIncidentCreated({
    db,
    messaging,
    incidentId: event.params.incidentId,
    incident: snap.data(),
  });
});

exports.onIncidentVerified = onDocumentUpdated("incidents/{incidentId}", async (event) => {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();
  if (!before || !after) return null;
  if (before.status === "pending_verification" && after.status === "active") {
    return handleIncidentCreated({
      db: admin.firestore(),
      messaging: admin.messaging(),
      incidentId: event.params.incidentId,
      incident: after,
    });
  }
  return null;
});

exports.acknowledgeIncident = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication is required to acknowledge an incident.");
  }
  const { incidentId, note } = request.data || {};
  if (!incidentId || typeof incidentId !== "string") {
    throw new HttpsError("invalid-argument", "incidentId is required.");
  }
  try {
    return await handleAcknowledgeIncident({
      db: admin.firestore(),
      incidentId,
      caller: {
        uid: request.auth.uid,
        email: request.auth.token?.email || null,
      },
      note,
    });
  } catch (err) {
    if (String(err.message).startsWith("NOT_FOUND")) {
      throw new HttpsError("not-found", err.message);
    }
    if (String(err.message).startsWith("PERMISSION_DENIED")) {
      throw new HttpsError("permission-denied", err.message);
    }
    throw new HttpsError("internal", "Failed to acknowledge incident.");
  }
});

exports.processEscalations = onSchedule("every 1 minutes", async () => {
  return handleEscalationSweep({
    db: admin.firestore(),
    messaging: admin.messaging(),
  });
});

exports.deleteUserAccountData = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }
  const uid = request.auth.uid;
  const db = admin.firestore();

  const contactsSnap = await db.collection("users").doc(uid).collection("contacts").get();
  const batch = db.batch();
  contactsSnap.docs.forEach((doc) => batch.delete(doc.ref));

  const incidentsSnap = await db.collection("incidents").where("userId", "==", uid).get();
  incidentsSnap.docs.forEach((doc) => batch.delete(doc.ref));

  const sessionsSnap = await db.collection("safety_sessions").where("userId", "==", uid).get();
  sessionsSnap.docs.forEach((doc) => batch.delete(doc.ref));

  batch.delete(db.collection("users").doc(uid));
  await batch.commit();
  await admin.auth().deleteUser(uid);

  return { deleted: true, uid };
});
