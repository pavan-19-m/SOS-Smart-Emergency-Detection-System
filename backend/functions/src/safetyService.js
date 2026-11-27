const REFRESH_FIELDS = ["id", "status", "lastCheckedAt", "lastDownloadedAt", "lastSuccessfulUpdateAt", "lastAttemptAt"];

function handleSafetyRequest({ method, path, snapshot, registry }) {
  if (method !== "GET") return { status: 405, body: { error: "method_not_allowed" } };
  const endpoints = {
    "": () => snapshot,
    "/summary": () => ({ availability: snapshot.availability, dataStatus: snapshot.dataStatus, generatedAt: snapshot.generatedAt, message: snapshot.message }),
    "/accidents": () => snapshot.accidents,
    "/crimes": () => snapshot.crimes,
    "/sources": () => registry.datasets,
    "/refresh-status": () => registry.datasets.map((dataset) => Object.fromEntries(REFRESH_FIELDS.filter((field) => field in dataset).map((field) => [field, dataset[field]]))),
  };
  const handler = endpoints[String(path || "").replace(/\/$/, "")];
  return handler ? { status: 200, body: handler() } : { status: 404, body: { error: "not_found" } };
}

module.exports = { handleSafetyRequest };
