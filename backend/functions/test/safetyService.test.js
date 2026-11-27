const test = require("node:test");
const assert = require("node:assert/strict");
const { handleSafetyRequest } = require("../src/safetyService");

const snapshot = { availability: "unavailable", dataStatus: "historical", accidents: { records: [] }, crimes: { records: [] } };
const registry = { datasets: [{ id: "public-aggregate", status: "catalogued_not_ingested", secret: "must not be returned" }] };

test("serves aggregate snapshot and named views only on GET", () => {
  assert.deepEqual(handleSafetyRequest({ method: "GET", path: "/summary", snapshot, registry }).body.availability, "unavailable");
  assert.deepEqual(handleSafetyRequest({ method: "GET", path: "/accidents", snapshot, registry }).body, { records: [] });
  assert.equal(handleSafetyRequest({ method: "GET", path: "/", snapshot, registry }).status, 200);
});

test("rejects unsupported methods and paths", () => {
  assert.equal(handleSafetyRequest({ method: "POST", path: "/", snapshot, registry }).status, 405);
  assert.equal(handleSafetyRequest({ method: "GET", path: "/nearby", snapshot, registry }).status, 404);
});

test("refresh status excludes unrelated registry properties", () => {
  const result = handleSafetyRequest({ method: "GET", path: "/refresh-status", snapshot, registry });
  assert.equal(result.body[0].secret, undefined);
  assert.equal(result.body[0].id, "public-aggregate");
});
