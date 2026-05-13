#!/usr/bin/env bash
# §4.10 "one-command way to see what's happening right now". Prints a
# compact live snapshot of the stack: container health, RabbitMQ queue
# depths, Redis pool / active rooms / per-user metric keys, Mongo doc
# counts. Read-only — never mutates state.
#
# Usage: scripts/status.sh    (typically via `make status`)
#
# Exits 0 even if individual probes fail — the goal is to print as much
# as can be reached, not to gate on every dep being up. Each probe is
# wrapped in `|| true` and prints a "(unavailable)" placeholder.

set -uo pipefail

bold()  { printf '\033[1m%s\033[0m\n' "$1"; }
dim()   { printf '\033[2m%s\033[0m\n' "$1"; }
hr()    { printf '%.0s─' {1..72}; printf '\n'; }

# Resolve container names without assuming a project prefix (compose v2
# uses the directory name; older v1 uses underscores). The `--filter
# name=` match below is loose enough that either variant resolves.
mongo_c=$(docker ps --filter "name=mongo" --format '{{.Names}}' | head -n1)
redis_c=$(docker ps --filter "name=redis" --format '{{.Names}}' | head -n1)
rabbit_c=$(docker ps --filter "name=rabbitmq" --format '{{.Names}}' | head -n1)

bold "▍ Containers"
docker compose ps --format 'table {{.Name}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null \
  || dim "(docker compose ps unavailable — is the stack up?)"
echo

bold "▍ RabbitMQ queue depths (top 12 by depth)"
# guest:guest is the dev default per docker-compose.yml. The API path
# /api/queues returns one row per queue with messages_ready /
# messages_unacknowledged — print queues that have any backlog first
# so a stuck consumer pops to the top.
if [ -n "$rabbit_c" ]; then
  # rabbitmqctl -q ("quiet") still emits a header line — strip it with
  # awk's NR>1 before sorting so it doesn't land in the middle of the
  # ranked rows.
  docker exec "$rabbit_c" rabbitmqctl list_queues -q name messages messages_unacknowledged 2>/dev/null \
    | awk 'NR>1' | sort -k2 -nr | head -n 12 \
    | awk 'BEGIN{printf "%-40s %10s %10s\n","name","ready","unacked"; printf "%-40s %10s %10s\n","----","-----","-------"} {printf "%-40s %10s %10s\n",$1,$2,$3}' \
    || dim "(rabbitmqctl failed)"
else
  dim "(rabbitmq container not found)"
fi
echo

bold "▍ Redis: matchmaking pool, active rooms, daily quota keys"
if [ -n "$redis_c" ]; then
  pool=$(docker exec "$redis_c" redis-cli ZCARD matchmaking:pool 2>/dev/null || echo "?")
  rooms=$(docker exec "$redis_c" redis-cli --raw eval 'return #redis.call("keys","room:*:state")' 0 2>/dev/null || echo "?")
  quotas=$(docker exec "$redis_c" redis-cli --raw eval 'return #redis.call("keys","user:*:daily_quota")' 0 2>/dev/null || echo "?")
  webhook_idem=$(docker exec "$redis_c" redis-cli --raw eval 'return #redis.call("keys","webhook:idempotency:*")' 0 2>/dev/null || echo "?")
  printf '  matchmaking pool size       : %s\n' "$pool"
  printf '  active rooms (room:*:state) : %s\n' "$rooms"
  printf '  daily-quota keys today      : %s\n' "$quotas"
  printf '  webhook idem keys (72h ttl) : %s\n' "$webhook_idem"
else
  dim "(redis container not found)"
fi
echo

bold "▍ Mongo: collection counts"
if [ -n "$mongo_c" ]; then
  docker exec "$mongo_c" mongosh quizbattle --quiet --eval '
    function r(name) {
      try { return db.getCollection(name).estimatedDocumentCount(); }
      catch (e) { return "?"; }
    }
    const rows = [
      ["users",         r("users")],
      ["questions",     r("questions")],
      ["match_history", r("match_history")],
      ["payments",      r("payments")],
      ["referrals",     r("referrals")],
      ["tournaments",   r("tournaments")],
      ["coin_ledger",   r("coin_ledger")],
    ];
    for (const [n, v] of rows) print("  " + n.padEnd(16) + ": " + v);
  ' 2>/dev/null || dim "(mongosh failed)"
else
  dim "(mongo container not found)"
fi
echo

bold "▍ Endpoints"
echo "  RabbitMQ UI : http://localhost:15672  (guest / guest)"
echo "  Webhook     : http://localhost:8080/webhook/razorpay"
echo "  Admin       : http://localhost:8090/         (live dashboard, §4.10 bonus)"
echo "  Prometheus  : http://localhost:2112/metrics  (per-service; ports 2112-2117)"
echo

hr
dim "Probe time: $(date '+%Y-%m-%d %H:%M:%S %Z')"
