.PHONY: proto proto-go proto-dart test vet lint build clean status coverage

PROTO_SRC := proto/quiz.proto

proto: proto-go proto-dart

proto-go:
	# -I . (not -I proto) so the source-relative output keeps the proto/
	# prefix and lands in proto/quiz.pb.go, matching go_package in the proto.
	protoc -I . \
	  --go_out=. --go_opt=paths=source_relative \
	  --go-grpc_out=. --go-grpc_opt=paths=source_relative \
	  $(PROTO_SRC)

# Requires `dart pub global activate protoc_plugin` and ~/.pub-cache/bin on PATH.
# Skip-friendly: `make proto-go` regenerates only Go stubs when the dart plugin
# isn't installed (e.g. on CI runners that don't need Flutter codegen).
#
# `-I proto` (not `-I .`) so the dart_out path resolution drops the `proto/`
# prefix — the generated files land at flutter/lib/proto/quiz.pb*.dart, which
# is what every Flutter import (`import '../proto/quiz.pbgrpc.dart';`) reaches.
proto-dart:
	protoc -I proto \
	  --dart_out=grpc:flutter/lib/proto \
	  quiz.proto

test:
	go test ./...

vet:
	go vet ./...

lint:
	@bad="$$(gofmt -l . | grep -v '^flutter/' || true)"; \
	if [ -n "$$bad" ]; then \
	  echo "gofmt needed in:"; echo "$$bad"; exit 1; \
	fi
	go vet ./...

build:
	go build ./...

# §4.10 — one-command live snapshot of the running stack. Read-only;
# wraps scripts/status.sh so the actual probe logic stays in shell
# (easier to iterate than embedded recipe lines, plus the file can be
# invoked standalone outside `make`).
status:
	@bash scripts/status.sh

# §4.9 — per-function coverage report on the five pure-logic pieces the
# spec calls out (scoring formula, daily quota, streak, webhook
# signature, referral). Exits non-zero if any drop below 70%.
coverage:
	@bash scripts/coverage.sh
