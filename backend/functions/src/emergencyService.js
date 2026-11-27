/**
 * Core emergency dispatch, acknowledgement, escalation, and safety check-in service.
 * Dependency-injected with Firestore + Messaging adapters for full unit testability.
 */

const {
  validateIncidentPayload,
  validateContactRecord,
  formatEmergencyMessage,
  buildMapsLink,
  isCallerAuthorizedForIncident,
} = require("./validators");

/**
 * Dispatches notifications for a newly created incident.
 * Strictly blocks external FCM delivery for simulation/demo incidents.
 */
async function handleIncidentCreated({ db, messaging, incidentId, incident, now = new Date() }) {
  const validation = validateIncidentPayload(incident);
  if (!validation.valid) {
    return { dispatched: false, reason: "invalid_payload", errors: validation.errors };
  }

  // Idempotency guard: prevent duplicate dispatch
  if (incident.notificationsDispatched === true) {
    return { dispatched: false, reason: "already_dispatched" };
  }

  // Never send real emergency notifications in Demo Mode!
  if (incident.isSimulation === true) {
    await db.collection("incidents").doc(incidentId).update({
      notificationsDispatched: false,
      simulationNotice: "Demo mode: external family notifications suppressed.",
      updatedAt: now.toISOString(),
    });
    return { dispatched: false, reason: "simulation_suppressed" };
  }

  // Only dispatch when incident has passed verification or is manual SOS / missed check-in
  if (incident.status === "pending_verification" || incident.status === "cancelled") {
    return { dispatched: false, reason: `status_${incident.status}` };
  }

  const userSnap = await db.collection("users").doc(incident.userId).get();
  const userData = userSnap.exists ? userSnap.data() : {};
  const userName = userData.displayName || "SOSense User";

  const contactsSnap = await db
    .collection("users")
    .doc(incident.userId)
    .collection("contacts")
    .get();

  const contacts = contactsSnap.docs
    .map((d) => ({ id: d.id, ...d.data() }))
    .filter((c) => validateContactRecord(c).valid);

  // Primary contacts notified immediately; secondary contacts notified on escalation
  // (or immediately if no primary contacts exist).
  const primaryContacts = contacts.filter((c) => c.priority === "primary");
  const targetContacts = primaryContacts.length > 0 ? primaryContacts : contacts;

  if (targetContacts.length === 0) {
    await db.collection("incidents").doc(incidentId).update({
      notificationsDispatched: false,
      dispatchError: "No valid emergency contacts configured.",
      updatedAt: now.toISOString(),
    });
    return { dispatched: false, reason: "no_contacts" };
  }

  const msg = formatEmergencyMessage(userName, incident.eventType);
  const mapsLink = buildMapsLink(incident.location);
  const tokens = [];
  const notifiedContactIds = [];

  for (const contact of targetContacts) {
    notifiedContactIds.push(contact.id);
    if (contact.fcmToken && typeof contact.fcmToken === "string") {
      tokens.push(contact.fcmToken);
    }
    await db.collection("notifications").add({
      incidentId,
      senderUid: incident.userId,
      recipientUid: contact.linkedUid || null,
      contactId: contact.id,
      contactName: contact.name,
      priority: contact.priority,
      title: msg.title,
      body: mapsLink ? `${msg.body} Location: ${mapsLink}` : msg.body,
      locationLink: mapsLink,
      eventType: incident.eventType,
      isSimulation: false,
      deliveryState: contact.fcmToken ? "queued_fcm" : "no_fcm_token_in_app_only",
      createdAt: now.toISOString(),
    });
  }

  let fcmSuccessCount = 0;
  let fcmFailureCount = 0;
  if (tokens.length > 0 && messaging) {
    const fcmResponse = await messaging.sendEachForMulticast({
      tokens,
      notification: {
        title: msg.title,
        body: msg.body,
      },
      data: {
        incidentId,
        eventType: incident.eventType,
        locationLink: mapsLink || "",
        timestamp: now.toISOString(),
        action: "ACKNOWLEDGE_INCIDENT",
      },
    });
    fcmSuccessCount = fcmResponse.successCount || 0;
    fcmFailureCount = fcmResponse.failureCount || 0;
  }

  const escalationDelayMs = (userData.escalationDelaySeconds || 120) * 1000;
  const escalationDueAt = new Date(now.getTime() + escalationDelayMs).toISOString();

  await db.collection("incidents").doc(incidentId).update({
    notificationsDispatched: true,
    status: "dispatched",
    notifiedContactIds,
    escalationDueAt,
    escalationStopped: false,
    fcmSuccessCount,
    fcmFailureCount,
    updatedAt: now.toISOString(),
  });

  return {
    dispatched: true,
    notifiedCount: targetContacts.length,
    fcmSuccessCount,
    fcmFailureCount,
  };
}

/**
 * Records acknowledgement by an authorized family contact or user and halts escalation.
 */
async function handleAcknowledgeIncident({ db, incidentId, caller, note = "", now = new Date() }) {
  const docRef = db.collection("incidents").doc(incidentId);
  const snap = await docRef.get();
  if (!snap.exists) {
    throw new Error("NOT_FOUND: Incident does not exist.");
  }

  const incident = snap.data();
  if (!isCallerAuthorizedForIncident(incident, caller)) {
    throw new Error("PERMISSION_DENIED: Caller is not authorized for this incident.");
  }

  if (incident.status === "acknowledged" || incident.status === "resolved") {
    return { alreadyAcknowledged: true, status: incident.status };
  }

  const createdTime = Date.parse(incident.createdAt || now.toISOString());
  const ackLatencySeconds = Number.isFinite(createdTime)
    ? Math.max(0, Math.round((now.getTime() - createdTime) / 1000))
    : 0;

  await docRef.update({
    status: "acknowledged",
    acknowledgedBy: caller.uid,
    acknowledgedByEmail: caller.email || null,
    acknowledgedAt: now.toISOString(),
    acknowledgementNote: String(note || "").slice(0, 300),
    ackLatencySeconds,
    escalationStopped: true,
    updatedAt: now.toISOString(),
  });

  return {
    alreadyAcknowledged: false,
    status: "acknowledged",
    ackLatencySeconds,
  };
}

/**
 * Escalates unacknowledged active/dispatched incidents to secondary contacts once due.
 */
async function handleEscalationSweep({ db, messaging, now = new Date() }) {
  const nowIso = now.toISOString();
  const pendingSnap = await db
    .collection("incidents")
    .where("status", "==", "dispatched")
    .get();

  let escalatedCount = 0;

  for (const doc of pendingSnap.docs) {
    const incident = doc.data();
    if (
      incident.isSimulation === true ||
      incident.escalationStopped === true ||
      incident.acknowledgedAt != null ||
      !incident.escalationDueAt ||
      incident.escalationDueAt > nowIso
    ) {
      continue;
    }

    const alreadyNotified = new Set(incident.notifiedContactIds || []);
    const contactsSnap = await db
      .collection("users")
      .doc(incident.userId)
      .collection("contacts")
      .get();

    const secondaryContacts = contactsSnap.docs
      .map((d) => ({ id: d.id, ...d.data() }))
      .filter((c) => validateContactRecord(c).valid && !alreadyNotified.has(c.id));

    if (secondaryContacts.length === 0) {
      await doc.ref.update({
        escalationStopped: true,
        updatedAt: nowIso,
      });
      continue;
    }

    const userSnap = await db.collection("users").doc(incident.userId).get();
    const userName = userSnap.exists ? userSnap.data().displayName : "SOSense User";
    const msg = formatEmergencyMessage(userName, incident.eventType);
    const mapsLink = buildMapsLink(incident.location);
    const tokens = [];
    const newNotified = [...alreadyNotified];

    for (const contact of secondaryContacts) {
      newNotified.push(contact.id);
      if (contact.fcmToken) tokens.push(contact.fcmToken);
      await db.collection("notifications").add({
        incidentId: doc.id,
        senderUid: incident.userId,
        recipientUid: contact.linkedUid || null,
        contactId: contact.id,
        contactName: contact.name,
        priority: contact.priority,
        title: `[ESCALATION] ${msg.title}`,
        body: mapsLink ? `${msg.body} Location: ${mapsLink}` : msg.body,
        locationLink: mapsLink,
        eventType: incident.eventType,
        isEscalation: true,
        isSimulation: false,
        deliveryState: contact.fcmToken ? "queued_fcm" : "no_fcm_token_in_app_only",
        createdAt: nowIso,
      });
    }

    if (tokens.length > 0 && messaging) {
      await messaging.sendEachForMulticast({
        tokens,
        notification: {
          title: `[ESCALATION] ${msg.title}`,
          body: msg.body,
        },
        data: {
          incidentId: doc.id,
          eventType: incident.eventType,
          isEscalation: "true",
          locationLink: mapsLink || "",
        },
      });
    }

    await doc.ref.update({
      status: "escalated",
      notifiedContactIds: newNotified,
      escalatedAt: nowIso,
      escalationStopped: true,
      updatedAt: nowIso,
    });
    escalatedCount += 1;
  }

  return { escalatedCount };
}

module.exports = {
  handleIncidentCreated,
  handleAcknowledgeIncident,
  handleEscalationSweep,
};
