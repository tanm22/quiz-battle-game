// Single-node replica set initiation. Mounted into mongo's
// /docker-entrypoint-initdb.d/ on first boot and re-runnable from healthcheck.
// Mongo transactions require a replica set, even when there's only one node.
try {
  rs.status();
  print("replica set already initiated");
} catch (e) {
  rs.initiate({
    _id: "rs0",
    members: [{ _id: 0, host: "mongo:27017" }],
  });
  print("replica set rs0 initiated");
}
