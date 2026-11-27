const { describe, it } = require("node:test");
const assert = require("node:assert/strict");

const {
  validateIncidentPayload,
  validateContactRecord,
  formatEmergencyMessage,
  buildMapsLink,
  isCallerAuthorizedForIncident,
} = require("../src/validators");

const {
  handleIncidentCreated,
  handleAcknowledgeIncident,
  handleEscalationSweep,
} = require("../src/emergencyService");

function createMockFirestore(initialData = {}) {
  const store = {
    users: new Map(Object.entries(initialData.users || {})),
    incidents: new Map(Object.entries(initialData.incidents || {})),
    notifications: new Map(),
  };

  let autoId = 1;

  function makeDocRef(collectionName, docId, subCollectionName = null, subDocId = null) {
    return {
      id: subDocId || docId,
      async get() {
        if (subCollectionName) {
          const user = store.users.get(docId);
          const item = user?.contacts?.[subDocId];
          return { exists: Boolean(item), data: () => item };
        }
        const item = store[collectionName]?.get(docId);
        return { exists: Boolean(item), data: () => item };
      },
      async update(patch) {
        if (subCollectionName) {
          const user = store.users.get(docId);
          user.contacts[subDocId] = { ...user.contacts[subDocId], ...patch };
          return;
        }
        const existing = store[collectionName].get(docId) || {};
        store[collectionName].set(docId, { ...existing, ...patch });
      },
    };
  }

  return {
    _store: store,
    collection(name) {
      return {
        doc(id) {
          const base = makeDocRef(name, id);
          base.collection = (subName) => ({
            async get() {
              const user = store.users.get(id) || {};
              const subMap = user[subName] || {};
              const docs = Object.entries(subMap).map(([k, v]) => ({
                id: k,
                data: () => v,
              }));
              return { docs };
            },
          });
          return base;
        },
        async add(data) {
          const id = `notif_${autoId++}`;
          store[name].set(id, data);
          return { id };
        },
        where(field, op, value) {
          return {
            async get() {
              const docs = [];
              for (const [id, data] of store[name].entries()) {
                if (op === "==" && data[field] === value) {
                  docs.push({
                    id,
                    data: () => data,
                    ref: makeDocRef(name, id),
                  });
                }
              }
              return { docs };
            },
          };
        },
      };
    },
  };
}

describe("Validators", () => {
  it("rejects forbidden secret fields in incidents", () => {
    const res = validateIncidentPayload({
      userId: "u1",
      eventType: "manual_sos",
      isSimulation: false,
      password: "leak",
    });
    assert.equal(res.valid, false);
    assert.match(res.errors[0], /Forbidden secret/);
  });

  it("rejects stale or invalid coordinates for Maps links", () => {
    assert.equal(buildMapsLink({ latitude: 12.9716, longitude: 77.5946, isStale: true }), null);
    assert.equal(buildMapsLink({ latitude: 999, longitude: 77.5, isStale: false }), null);
    assert.equal(
      buildMapsLink({ latitude: 12.9716, longitude: 77.5946, isStale: false }),
      "https://maps.google.com/?q=12.971600,77.594600"
    );
  });

  it("validates contact records and caller authorization", () => {
    assert.equal(validateContactRecord({ name: "Mom", priority: "primary", phone: "+919999999999" }).valid, true);
    assert.equal(validateContactRecord({ name: "", priority: "invalid" }).valid, false);

    const incident = {
      userId: "u1",
      authorizedContactUids: ["c_uid_1"],
      authorizedContactEmails: ["family@example.com"],
    };
    assert.equal(isCallerAuthorizedForIncident(incident, { uid: "c_uid_1" }), true);
    assert.equal(isCallerAuthorizedForIncident(incident, { uid: "other", email: "family@example.com" }), true);
    assert.equal(isCallerAuthorizedForIncident(incident, { uid: "stranger", email: "bad@example.com" }), false);
  });

  it("formats honest emergency notifications", () => {
    const msg = formatEmergencyMessage("Aarav", "possible_accident");
    assert.equal(msg.title, "Possible Accident Detected");
    assert.match(msg.body, /Possible accident detected/);
  });
});

describe("Emergency Dispatch, Acknowledgement & Escalation", () => {
  it("suppresses external FCM notifications in Demo Mode", async () => {
    const db = createMockFirestore({
      users: { u1: { displayName: "Aarav" } },
      incidents: {
        inc_sim: {
          userId: "u1",
          eventType: "possible_fall",
          status: "active",
          isSimulation: true,
        },
      },
    });
    let fcmCalled = false;
    const messaging = {
      async sendEachForMulticast() {
        fcmCalled = true;
        return { successCount: 1, failureCount: 0 };
      },
    };

    const res = await handleIncidentCreated({
      db,
      messaging,
      incidentId: "inc_sim",
      incident: db._store.incidents.get("inc_sim"),
    });
    assert.equal(res.dispatched, false);
    assert.equal(res.reason, "simulation_suppressed");
    assert.equal(fcmCalled, false);
    assert.equal(db._store.notifications.size, 0);
  });

  it("dispatches to primary contact first, then escalates to secondary if unacknowledged", async () => {
    const t0 = new Date("2026-11-26T10:00:00.000Z");
    const db = createMockFirestore({
      users: {
        u1: {
          displayName: "Aarav",
          escalationDelaySeconds: 120,
          contacts: {
            c1: { name: "Mom", priority: "primary", linkedUid: "u_mom", fcmToken: "tok_mom" },
            c2: { name: "Dad", priority: "secondary", linkedUid: "u_dad", fcmToken: "tok_dad" },
          },
        },
      },
      incidents: {
        inc_1: {
          userId: "u1",
          eventType: "manual_sos",
          status: "active",
          isSimulation: false,
          createdAt: t0.toISOString(),
          authorizedContactUids: ["u_mom", "u_dad"],
          location: { latitude: 12.9716, longitude: 77.5946, isStale: false },
        },
      },
    });

    const sentBatches = [];
    const messaging = {
      async sendEachForMulticast(payload) {
        sentBatches.push(payload);
        return { successCount: payload.tokens.length, failureCount: 0 };
      },
    };

    const dispatchRes = await handleIncidentCreated({
      db,
      messaging,
      incidentId: "inc_1",
      incident: db._store.incidents.get("inc_1"),
      now: t0,
    });

    assert.equal(dispatchRes.dispatched, true);
    assert.equal(dispatchRes.notifiedCount, 1);
    assert.deepEqual(sentBatches[0].tokens, ["tok_mom"]);

    // Duplicate trigger is blocked
    const dupRes = await handleIncidentCreated({
      db,
      messaging,
      incidentId: "inc_1",
      incident: db._store.incidents.get("inc_1"),
      now: t0,
    });
    assert.equal(dupRes.dispatched, false);
    assert.equal(dupRes.reason, "already_dispatched");

    // Before escalation delay: 0 escalations
    const earlySweep = await handleEscalationSweep({
      db,
      messaging,
      now: new Date("2026-11-26T10:01:00.000Z"),
    });
    assert.equal(earlySweep.escalatedCount, 0);

    // After escalation delay: escalates to secondary contact
    const lateSweep = await handleEscalationSweep({
      db,
      messaging,
      now: new Date("2026-11-26T10:03:00.000Z"),
    });
    assert.equal(lateSweep.escalatedCount, 1);
    assert.deepEqual(sentBatches[1].tokens, ["tok_dad"]);
    assert.equal(db._store.incidents.get("inc_1").status, "escalated");
  });

  it("acknowledges incident by authorized contact and stops escalation", async () => {
    const t0 = new Date("2026-11-26T10:00:00.000Z");
    const t1 = new Date("2026-11-26T10:00:45.000Z");
    const db = createMockFirestore({
      incidents: {
        inc_2: {
          userId: "u1",
          eventType: "possible_accident",
          status: "dispatched",
          isSimulation: false,
          createdAt: t0.toISOString(),
          authorizedContactUids: ["u_mom"],
          escalationStopped: false,
        },
      },
    });

    await assert.rejects(
      () => handleAcknowledgeIncident({ db, incidentId: "inc_2", caller: { uid: "stranger" }, now: t1 }),
      /PERMISSION_DENIED/
    );

    const ackRes = await handleAcknowledgeIncident({
      db,
      incidentId: "inc_2",
      caller: { uid: "u_mom", email: "mom@example.com" },
      note: "Called Aarav, he is safe.",
      now: t1,
    });
    assert.equal(ackRes.status, "acknowledged");
    assert.equal(ackRes.ackLatencySeconds, 45);
    assert.equal(db._store.incidents.get("inc_2").escalationStopped, true);
  });
});
