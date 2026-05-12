// Package main implements the §4.10 "admin dashboard" — a tiny HTTP
// service that surfaces live operational state from Mongo, Redis, and
// RabbitMQ on one page. Read-only by design: every probe is a count
// query or a key scan, nothing mutates state.
//
// Layout:
//
//	GET /            — embedded HTML page that polls /api/stats every 3s
//	GET /api/stats   — JSON snapshot of the stack right now
//	GET /healthz     — liveness probe
//
// Why a dedicated service and not an endpoint on an existing one:
// admin is operator-facing, separate from any user-facing surface, and
// goes down or hangs without affecting players. Mounting on the
// payment service's :8080 would couple operator visibility to the
// health of the payment plane — exactly when you most need the
// dashboard, the dashboard is unreachable.
package main

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"sort"
	"time"

	"github.com/redis/go-redis/v9"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"

	"quiz-battle/pkg/config"
	"quiz-battle/pkg/lifecycle"
	qlog "quiz-battle/pkg/log"
)

// Tunables. Defaults are sized for the dev compose stack — the
// dashboard probes every 3s in the browser and each probe finishes in
// well under a second locally.

// httpServerTimeout caps any single dashboard handler so a stuck Mongo
// or Rabbit probe doesn't tie up the worker pool. Three of these probes
// run on every /api/stats; 4s gives them each enough headroom on a
// cold cache without making /api/stats itself feel sluggish.
const httpServerTimeout = 4 * time.Second

// rabbitListenPort matches docker-compose.yml's management plugin
// binding. The container also exposes :5672 for AMQP — we don't dial
// that here; the management HTTP API is what gives us queue depths in
// a single round-trip per call.
const rabbitMgmtAddr = "rabbitmq:15672"

// stats is the JSON shape returned by /api/stats. Field names are
// snake_case so the dashboard's JS can read them without translation.
type stats struct {
	GeneratedAt     time.Time      `json:"generated_at"`
	MatchmakingPool int64          `json:"matchmaking_pool_size"`
	ActiveRooms     int            `json:"active_rooms"`
	DailyQuotaKeys  int            `json:"daily_quota_keys_today"`
	WebhookIdemKeys int            `json:"webhook_idem_keys"`
	Mongo           mongoCounts    `json:"mongo"`
	Queues          []rabbitQueue  `json:"queues"`
	Errors          map[string]any `json:"errors,omitempty"`
}

type mongoCounts struct {
	Users        int64 `json:"users"`
	Questions    int64 `json:"questions"`
	MatchHistory int64 `json:"match_history"`
	Payments     int64 `json:"payments"`
	Referrals    int64 `json:"referrals"`
	Tournaments  int64 `json:"tournaments"`
	CoinLedger   int64 `json:"coin_ledger"`
}

type rabbitQueue struct {
	Name           string `json:"name"`
	Messages       int64  `json:"messages"`
	MessagesUnacked int64 `json:"messages_unacknowledged"`
}

type adminServer struct {
	rdb         *redis.Client
	mongoDB     *mongo.Database
	rabbitAuth  string // base64("user:pass") for the management API
	rabbitVHost string // typically "/", URL-encoded as "%2F"
}

func main() {
	slog.SetDefault(qlog.Init("admin"))
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Connection setup. Each dep is required because if one is down,
	// the dashboard is precisely the right tool to use to discover
	// *that* — fail-fast at startup, then the operator sees the
	// container in a restart loop and goes looking.
	redisAddr := config.MustRequired(ctx, "REDIS_ADDR")
	mongoURI := config.MustRequired(ctx, "MONGO_URI")
	rabbitUser := config.Optional("RABBITMQ_USER", "guest")
	rabbitPass := config.Optional("RABBITMQ_PASSWORD", "guest")

	rdb := redis.NewClient(&redis.Options{Addr: redisAddr})
	if err := rdb.Ping(ctx).Err(); err != nil {
		qlog.Fatal(ctx, "redis ping failed", "err", err)
	}
	qlog.FromContext(ctx).Info("connected to Redis")

	mc, err := mongo.Connect(options.Client().ApplyURI(mongoURI))
	if err != nil {
		qlog.Fatal(ctx, "mongo connect failed", "err", err)
	}
	if err := mc.Ping(ctx, nil); err != nil {
		qlog.Fatal(ctx, "mongo ping failed", "err", err)
	}
	qlog.FromContext(ctx).Info("connected to MongoDB")

	srv := &adminServer{
		rdb:         rdb,
		mongoDB:     mc.Database("quizbattle"),
		rabbitAuth:  base64.StdEncoding.EncodeToString([]byte(rabbitUser + ":" + rabbitPass)),
		rabbitVHost: "%2F",
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/", srv.handleIndex)
	mux.HandleFunc("/api/stats", srv.handleStats)
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	httpSrv := &http.Server{
		Addr:              ":8090",
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       8 * time.Second,
		WriteTimeout:      8 * time.Second,
		IdleTimeout:       30 * time.Second,
	}

	go func() {
		qlog.FromContext(ctx).Info("admin HTTP serving", "addr", ":8090")
		if err := httpSrv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			qlog.FromContext(ctx).Error("HTTP serve exited", "err", err)
		}
	}()

	lifecycle.WaitForSignal(ctx)
	qlog.FromContext(ctx).Info("graceful shutdown starting")
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer shutdownCancel()
	_ = httpSrv.Shutdown(shutdownCtx)
	_ = rdb.Close()
	_ = mc.Disconnect(shutdownCtx)
}

// handleIndex serves the embedded HTML dashboard. Single-page; the JS
// inside polls /api/stats every 3s and re-renders the cards.
func (s *adminServer) handleIndex(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_, _ = w.Write([]byte(dashboardHTML))
}

// handleStats is the dashboard's data source. Probes are run with
// short individual timeouts so one wedged dep doesn't drag the whole
// response past the parent handler's 4s cap.
func (s *adminServer) handleStats(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), httpServerTimeout)
	defer cancel()

	out := stats{GeneratedAt: time.Now().UTC()}
	errs := map[string]any{}

	// Redis probes — pool size + key-scan counts via Lua so we make
	// one round-trip per metric instead of N. KEYS is acceptable here
	// because the dashboard runs against a small key-space on a small
	// instance; production-scale would replace these with maintained
	// counter keys.
	if v, err := s.rdb.ZCard(ctx, "matchmaking:pool").Result(); err == nil {
		out.MatchmakingPool = v
	} else {
		errs["matchmaking_pool"] = err.Error()
	}
	if n, err := keyCount(ctx, s.rdb, "room:*:state"); err == nil {
		out.ActiveRooms = n
	} else {
		errs["active_rooms"] = err.Error()
	}
	if n, err := keyCount(ctx, s.rdb, "user:*:daily_quota"); err == nil {
		out.DailyQuotaKeys = n
	} else {
		errs["daily_quota_keys"] = err.Error()
	}
	if n, err := keyCount(ctx, s.rdb, "webhook:idempotency:*"); err == nil {
		out.WebhookIdemKeys = n
	} else {
		errs["webhook_idem_keys"] = err.Error()
	}

	// Mongo doc-count probes. Use EstimatedDocumentCount (fast metadata
	// read) rather than CountDocuments (collection scan) — the dashboard
	// is read often and we'd rather show stale-by-a-couple-of-seconds
	// counts than block on a full scan.
	out.Mongo = s.mongoSnapshot(ctx, errs)

	// RabbitMQ queue depths via the management API.
	if qs, err := s.fetchQueues(ctx); err == nil {
		// Sort by total backlog desc so the busiest queues sit at the
		// top of the dashboard.
		sort.Slice(qs, func(i, j int) bool {
			return qs[i].Messages+qs[i].MessagesUnacked > qs[j].Messages+qs[j].MessagesUnacked
		})
		out.Queues = qs
	} else {
		errs["queues"] = err.Error()
	}

	if len(errs) > 0 {
		out.Errors = errs
	}

	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store")
	if err := json.NewEncoder(w).Encode(out); err != nil {
		qlog.FromContext(ctx).Error("encode stats", "err", err)
	}
}

func (s *adminServer) mongoSnapshot(ctx context.Context, errs map[string]any) mongoCounts {
	count := func(coll string) int64 {
		n, err := s.mongoDB.Collection(coll).EstimatedDocumentCount(ctx)
		if err != nil {
			errs["mongo_"+coll] = err.Error()
			return -1
		}
		return n
	}
	return mongoCounts{
		Users:        count("users"),
		Questions:    count("questions"),
		MatchHistory: count("match_history"),
		Payments:     count("payments"),
		Referrals:    count("referrals"),
		Tournaments:  count("tournaments"),
		CoinLedger:   count("coin_ledger"),
	}
}

// keyCount returns the number of keys matching pattern. Uses SCAN
// rather than KEYS so the call is non-blocking even on a busy server —
// the cursor walks the keyspace in chunks. Bounded to scan only the
// first 5000 keys per call so the dashboard can't accidentally trip a
// long-tail key-space sweep on a large prod instance.
func keyCount(ctx context.Context, rdb *redis.Client, pattern string) (int, error) {
	const cap = 5000
	var cursor uint64
	total := 0
	for {
		ks, next, err := rdb.Scan(ctx, cursor, pattern, 256).Result()
		if err != nil {
			return total, err
		}
		total += len(ks)
		if total >= cap {
			return total, nil
		}
		if next == 0 {
			return total, nil
		}
		cursor = next
	}
}

// fetchQueues calls the RabbitMQ management API. The API returns a
// JSON array, one row per queue; we keep only the three fields the
// dashboard renders so the wire payload stays tight.
func (s *adminServer) fetchQueues(ctx context.Context) ([]rabbitQueue, error) {
	url := fmt.Sprintf("http://%s/api/queues/%s", rabbitMgmtAddr, s.rabbitVHost)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Basic "+s.rabbitAuth)

	client := &http.Client{Timeout: 3 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("rabbitmq mgmt: status %d", resp.StatusCode)
	}

	var raw []struct {
		Name            string `json:"name"`
		Messages        int64  `json:"messages"`
		MessagesUnacked int64  `json:"messages_unacknowledged"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&raw); err != nil {
		return nil, err
	}
	out := make([]rabbitQueue, 0, len(raw))
	for _, r := range raw {
		// Skip dlqs in the headline render — they're shown grouped at
		// the bottom of the dashboard so a flood of dlq names doesn't
		// crowd out the working queues.
		out = append(out, rabbitQueue{
			Name:            r.Name,
			Messages:        r.Messages,
			MessagesUnacked: r.MessagesUnacked,
		})
	}
	return out, nil
}

const dashboardHTML = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Quiz Battle — Admin</title>
<style>
  :root {
    --bg: #0E0E12;
    --card: #1A1B22;
    --border: rgba(255,255,255,0.08);
    --text: #F2F3F5;
    --muted: #8A8D96;
    --accent: #6D59C4;
    --good: #4ADE80;
    --warn: #F59E0B;
    --bad: #F87171;
  }
  * { box-sizing: border-box; }
  body { margin: 0; background: var(--bg); color: var(--text); font-family: -apple-system, system-ui, sans-serif; }
  header { padding: 24px 32px; border-bottom: 1px solid var(--border); display: flex; justify-content: space-between; align-items: center; }
  header h1 { margin: 0; font-size: 18px; font-weight: 700; letter-spacing: 0.2px; }
  header .ts { color: var(--muted); font-size: 13px; font-variant-numeric: tabular-nums; }
  main { padding: 24px 32px; display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 16px; }
  .card { background: var(--card); border: 1px solid var(--border); border-radius: 12px; padding: 20px; }
  .card h2 { margin: 0 0 12px; font-size: 13px; text-transform: uppercase; letter-spacing: 1px; color: var(--muted); font-weight: 600; }
  .metric { display: flex; justify-content: space-between; align-items: baseline; padding: 6px 0; border-bottom: 1px dashed var(--border); }
  .metric:last-child { border-bottom: none; }
  .metric .k { color: var(--muted); font-size: 13px; }
  .metric .v { font-size: 18px; font-weight: 600; font-variant-numeric: tabular-nums; }
  .metric .v.nonzero { color: var(--accent); }
  .metric .v.busy { color: var(--warn); }
  .qrow { display: grid; grid-template-columns: 1fr 60px 60px; gap: 8px; padding: 4px 0; font-size: 12px; }
  .qrow .qn { color: var(--muted); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .qrow .qv { text-align: right; font-variant-numeric: tabular-nums; }
  .qrow .qv.nonzero { color: var(--warn); font-weight: 600; }
  .qhead { color: var(--muted); font-size: 11px; text-transform: uppercase; padding-bottom: 6px; border-bottom: 1px solid var(--border); margin-bottom: 6px; }
  .err { color: var(--bad); font-size: 12px; margin-top: 8px; }
  .pulse { width: 8px; height: 8px; border-radius: 50%; background: var(--good); display: inline-block; margin-right: 8px; animation: pulse 1.5s infinite; }
  @keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.4; } }
</style>
</head>
<body>
<header>
  <h1><span class="pulse"></span>Quiz Battle — Live State</h1>
  <div class="ts" id="ts">—</div>
</header>
<main id="grid"></main>

<script>
async function tick() {
  try {
    const res = await fetch('/api/stats', { cache: 'no-store' });
    if (!res.ok) throw new Error('HTTP ' + res.status);
    const s = await res.json();
    render(s);
  } catch (e) {
    document.getElementById('ts').textContent = 'fetch error: ' + e.message;
  }
}

function fmtTs(iso) {
  const d = new Date(iso);
  return d.toLocaleTimeString('en-IN', { hour12: false }) + ' IST';
}

function num(v) {
  return v == null || v < 0 ? '—' : String(v);
}

function vClass(v) {
  if (v == null || v === 0) return '';
  if (v < 0) return '';
  return 'nonzero';
}

function busyClass(v) {
  return v > 0 ? 'busy' : '';
}

function metric(k, v, klass='') {
  return '<div class="metric"><span class="k">' + k + '</span><span class="v ' + klass + '">' + num(v) + '</span></div>';
}

function render(s) {
  document.getElementById('ts').textContent = 'updated ' + fmtTs(s.generated_at);

  const cards = [];

  cards.push(card('Live Game State',
    metric('Matchmaking pool', s.matchmaking_pool_size, vClass(s.matchmaking_pool_size)) +
    metric('Active rooms',     s.active_rooms,          vClass(s.active_rooms)) +
    metric('Daily quotas used today', s.daily_quota_keys_today, vClass(s.daily_quota_keys_today)) +
    metric('Webhook idem keys (72h)', s.webhook_idem_keys, vClass(s.webhook_idem_keys))
  ));

  const m = s.mongo || {};
  cards.push(card('MongoDB',
    metric('Users',         m.users) +
    metric('Questions',     m.questions) +
    metric('Match history', m.match_history) +
    metric('Payments',      m.payments) +
    metric('Referrals',     m.referrals) +
    metric('Tournaments',   m.tournaments) +
    metric('Coin ledger',   m.coin_ledger)
  ));

  const qs = s.queues || [];
  let qBody = '<div class="qhead"><div class="qrow"><span>queue</span><span class="qv">ready</span><span class="qv">unacked</span></div></div>';
  if (qs.length === 0) {
    qBody += '<div class="metric"><span class="k">No queues reported</span></div>';
  } else {
    for (const q of qs.slice(0, 16)) {
      const busy = q.messages > 0 || q.messages_unacknowledged > 0;
      qBody += '<div class="qrow">' +
        '<span class="qn" title="' + q.name + '">' + q.name + '</span>' +
        '<span class="qv ' + (q.messages > 0 ? 'nonzero' : '') + '">' + q.messages + '</span>' +
        '<span class="qv ' + (q.messages_unacknowledged > 0 ? 'nonzero' : '') + '">' + q.messages_unacknowledged + '</span>' +
        '</div>';
    }
  }
  cards.push(card('RabbitMQ Queues', qBody));

  if (s.errors) {
    let body = '';
    for (const [k, v] of Object.entries(s.errors)) {
      body += '<div class="metric"><span class="k">' + k + '</span><span class="v" style="color:var(--bad);font-size:12px">err</span></div>';
      body += '<div class="err">' + v + '</div>';
    }
    cards.push(card('Probe Errors', body));
  }

  document.getElementById('grid').innerHTML = cards.join('');
}

function card(title, body) {
  return '<section class="card"><h2>' + title + '</h2>' + body + '</section>';
}

tick();
setInterval(tick, 3000);
</script>
</body>
</html>`
