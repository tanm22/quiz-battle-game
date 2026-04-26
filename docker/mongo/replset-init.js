// Idempotent replica-set initiator. Runs once on first launch via
// /docker-entrypoint-initdb.d/. The healthcheck in docker-compose.yml
// re-runs the same logic on every container start, so volumes that
// pre-date the rs0 migration also get initiated on first up after the
// upgrade — no manual `docker compose down -v` required.
try {
  rs.status();
  print("[replset-init] rs0 already initiated");
} catch (e) {
  rs.initiate({
    _id: "rs0",
    members: [{ _id: 0, host: "mongo:27017" }],
  });
  print("[replset-init] rs0 initiated");
}
