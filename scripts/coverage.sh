#!/usr/bin/env bash
# §4.9 coverage report: per-function coverage on the five pure-logic
# pieces the spec calls out by name. Package-level coverage hides this
# because each package mixes pure logic with gRPC handlers, Mongo
# readers, and server boot — diluting the % down to "looks low" even
# when every targeted function is fully tested.
#
# Usage: scripts/coverage.sh    (typically via `make coverage`)
#
# Exits 0 if all targeted functions are >= 70% covered, 1 otherwise.
# Prints a table either way so the failure is obvious in CI output.

set -uo pipefail

THRESHOLD=70.0

# Packages where the spec's pure-logic functions live. Same five used
# in the coverage measurement and the function-level filter below.
PKGS="./pkg/keys/... ./pkg/auth/... ./services/payment/... ./services/scoring/... ./services/auth/..."

# Each row: function name (as Go reports it), the source-file path
# fragment to match, and a short label for the report. The function
# name alone isn't unique across packages, so we anchor on the path
# fragment too.
TARGETS=(
  "computeRoundScore|services/scoring/main.go|Scoring formula"
  "CheckQuota|pkg/keys/redis.go|Daily quota: consume"
  "RefundQuota|pkg/keys/redis.go|Daily quota: refund"
  "processStreak|services/auth/main.go|Streak progression"
  "verifyRazorpaySignature|services/payment/main.go|Razorpay HMAC verify"
  "handleReferralEvent|services/scoring/coins.go|Referral grant consumer"
)

bold()  { printf '\033[1m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m' "$1"; }
red()   { printf '\033[31m%s\033[0m' "$1"; }
dim()   { printf '\033[2m%s\033[0m\n' "$1"; }

cover="$(mktemp)"
trap 'rm -f "$cover"' EXIT

bold "▍ Measuring coverage on §4.9 pure-logic functions"
dim "  packages: $PKGS"
echo ""

# -coverpkg makes go test count coverage across the listed packages even
# when the test itself sits in a different package. Without this the
# integration-style tests in services/* would only credit their own
# package; functions in pkg/* called from those tests would show 0%.
#
# Capture stdout/stderr to a temp file so on failure we can tail the
# operator-relevant slice without re-running the whole (slow,
# Mongo-touching) test pass.
test_log="$(mktemp)"
trap 'rm -f "$cover" "$test_log"' EXIT
if ! go test -count=1 -coverpkg="$(echo "$PKGS" | tr ' ' ',')" \
  -coverprofile="$cover" $PKGS >"$test_log" 2>&1; then
  red "go test failed — coverage report skipped"
  echo ""
  tail -40 "$test_log"
  echo ""
  dim "Full output saved at $test_log"
  exit 1
fi

# `go tool cover -func` prints one row per function: "path/file.go:LINE:
# FuncName    NN.N%". Build a function→percent map keyed by path fragment
# so each TARGETS entry resolves to exactly one row.
func_report="$(go tool cover -func="$cover")"

printf '%-30s %-44s %10s %8s\n' "AREA" "FUNCTION" "COVERAGE" "STATUS"
printf '%-30s %-44s %10s %8s\n' "----" "--------" "--------" "------"

failed=0
for row in "${TARGETS[@]}"; do
  fn="${row%%|*}"
  rest="${row#*|}"
  path="${rest%%|*}"
  label="${rest##*|}"

  # Match "<...>/path/file.go:LINE: fn  NN.N%". Anchor both path and
  # function name so a same-named helper in a different package isn't
  # picked up by accident.
  line=$(printf '%s' "$func_report" | grep -E "${path}:.*\b${fn}\b" | head -n 1)
  if [ -z "$line" ]; then
    pct="NOT FOUND"
    status="$(red 'MISS')"
    failed=1
  else
    pct=$(echo "$line" | awk '{print $3}')
    pct_num=$(echo "$pct" | tr -d '%')
    above=$(awk -v p="$pct_num" -v t="$THRESHOLD" 'BEGIN{print (p+0 >= t+0) ? 1 : 0}')
    if [ "$above" = "1" ]; then
      status="$(green 'PASS')"
    else
      status="$(red 'FAIL')"
      failed=1
    fi
  fi
  printf '%-30s %-44s %10s %8b\n' "$label" "$fn" "$pct" "$status"
done

echo ""
if [ "$failed" -eq 0 ]; then
  green "All §4.9 targeted functions ≥ ${THRESHOLD}%"
  echo ""
  exit 0
else
  red "One or more §4.9 functions below ${THRESHOLD}% coverage"
  echo ""
  dim "Hint: open '$cover' or run 'go tool cover -html=$cover' to see uncovered lines."
  exit 1
fi
