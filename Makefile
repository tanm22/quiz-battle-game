.PHONY: proto proto-go proto-dart test vet lint build clean

PROTO_SRC := proto/quiz.proto

proto: proto-go proto-dart

proto-go:
	protoc -I proto \
	  --go_out=. --go_opt=paths=source_relative \
	  --go-grpc_out=. --go-grpc_opt=paths=source_relative \
	  $(PROTO_SRC)

# Requires `dart pub global activate protoc_plugin` and ~/.pub-cache/bin on PATH.
# Skip-friendly: `make proto-go` regenerates only Go stubs when the dart plugin
# isn't installed (e.g. on CI runners that don't need Flutter codegen).
proto-dart:
	protoc -I proto \
	  --dart_out=grpc:flutter/lib/proto \
	  $(PROTO_SRC)

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
