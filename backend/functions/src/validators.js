/**
 * Pure validation & formatting helpers for SOSense Cloud Functions.
 * Kept framework-agnostic so they can be unit-tested deterministically.
 */

const VALID_EVENT_TYPES = new Set([
  "manual_sos",
  "possible_accident",
  "possible_fall",
  "unusual_movement",
  "missed_check_in",
]);

const VALID_PRIORITIES = new Set(["primary", "secondary"]);

/**
 * Validates that an incident payload has safe required fields and no leaked secrets.
 * @param {Record<string, any>} incident
 * @returns {{ valid: boolean, errors: string[] }}
 */
function validateIncidentPayload(incident) {
  const errors = [];
  if (!incident || typeof incident !== "object") {
    return { valid: false, errors: ["Incident payload must be an object."] };
  }
  if (!incident.userId || typeof incident.userId !== "string") {
    errors.push("Missing or invalid userId.");
  }
  if (!VALID_EVENT_TYPES.has(incident.eventType)) {
    errors.push(`Unsupported eventType: ${incident.eventType}`);
  }
  if (typeof incident.isSimulation !== "boolean") {
    errors.push("isSimulation boolean flag is required.");
  }
  if ("password" in incident || "passwordHash" in incident || "secretToken" in incident) {
    errors.push("Forbidden secret field present in incident payload.");
  }
  return { valid: errors.length === 0, errors };
}

/**
 * Validates a trusted contact object before notification routing.
 * @param {Record<string, any>} contact
 * @returns {{ valid: boolean, errors: string[] }}
 */
function validateContactRecord(contact) {
  const errors = [];
  if (!contact || typeof contact !== "object") {
    return { valid: false, errors: ["Contact must be an object."] };
  }
  if (!contact.name || typeof contact.name !== "string" || contact.name.trim().length === 0) {
    errors.push("Contact name is required.");
  }
  if (!VALID_PRIORITIES.has(contact.priority)) {
    errors.push(`Invalid priority: ${contact.priority}`);
  }
  if (!contact.phone && !contact.email && !contact.linkedUid) {
    errors.push("Contact must have at least one delivery channel (phone, email, or linkedUid).");
  }
  return { valid: errors.length === 0, errors };
}

/**
 * Formats an alert message based on the event type without making unsupported guarantees.
 * @param {string} userName
 * @param {string} eventType
 * @returns {{ title: string, body: string }}
 */
function formatEmergencyMessage(userName, eventType) {
  const safeName = (userName && String(userName).trim()) || "SOSense User";
  switch (eventType) {
    case "manual_sos":
      return {
        title: "Emergency SOS Activated",
        body: `Emergency SOS activated by ${safeName}. Please check immediately.`,
      };
    case "possible_accident":
      return {
        title: "Possible Accident Detected",
        body: `Possible accident detected for ${safeName}. Please check on the user.`,
      };
    case "possible_fall":
      return {
        title: "Possible Fall Detected",
        body: `Possible fall detected for ${safeName}. User did not respond to verification.`,
      };
    case "missed_check_in":
      return {
        title: "Safety Check-In Missed",
        body: `Safety check-in missed by ${safeName}. Please verify their status.`,
      };
    case "unusual_movement":
    default:
      return {
        title: "Unusual Motion Anomaly Detected",
        body: `Unusual movement anomaly detected for ${safeName}. Please check in.`,
      };
  }
}

/**
 * Generates a Google Maps link only when non-stale, finite coordinates are present.
 * @param {Record<string, any> | null | undefined} location
 * @returns {string | null}
 */
function buildMapsLink(location) {
  if (!location || typeof location !== "object") return null;
  const { latitude, longitude, isStale } = location;
  if (isStale === true) return null;
  if (typeof latitude !== "number" || typeof longitude !== "number") return null;
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return null;
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) return null;
  return `https://maps.google.com/?q=${latitude.toFixed(6)},${longitude.toFixed(6)}`;
}

/**
 * Checks whether a caller is authorized to read or acknowledge an incident.
 * @param {Record<string, any>} incident
 * @param {{ uid?: string, email?: string } | null | undefined} caller
 * @returns {boolean}
 */
function isCallerAuthorizedForIncident(incident, caller) {
  if (!incident || !caller || !caller.uid) return false;
  if (incident.userId === caller.uid) return true;
  if (Array.isArray(incident.authorizedContactUids) && incident.authorizedContactUids.includes(caller.uid)) {
    return true;
  }
  if (
    caller.email &&
    Array.isArray(incident.authorizedContactEmails) &&
    incident.authorizedContactEmails.includes(caller.email)
  ) {
    return true;
  }
  return false;
}

module.exports = {
  VALID_EVENT_TYPES,
  VALID_PRIORITIES,
  validateIncidentPayload,
  validateContactRecord,
  formatEmergencyMessage,
  buildMapsLink,
  isCallerAuthorizedForIncident,
};
