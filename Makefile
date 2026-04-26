.PHONY: proto test lint vet build clean

# proto regen runs from inside proto/ so paths=source_relative matches the
# existing checked-in `source: quiz.proto` headers in proto/quiz.pb.go and
# the dart bindings under flutter/lib/proto/. Running with -I from outside
# emits files at the wrong relative path.
proto:
	cd proto && protoc \
	  --go_out=. --go_opt=paths=source_relative \
	  --go-grpc_out=. --go-grpc_opt=paths=source_relative \
	  quiz.proto
	cd proto && protoc \
	  --dart_out=grpc:../flutter/lib/proto \
	  quiz.proto

test:
	go test ./...

vet:
	go vet ./...

lint:
	@out=$$(gofmt -l .); if [ -n "$$out" ]; then echo "$$out" >&2; exit 1; fi
	go vet ./...

build:
	go build ./...

clean:
	go clean ./...
