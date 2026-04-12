# Stage 1: Build all four Go service binaries
FROM golang:1.25-alpine AS builder

WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 go build -o /out/matchmaking    ./services/matchmaking && \
    CGO_ENABLED=0 go build -o /out/quiz           ./services/quiz && \
    CGO_ENABLED=0 go build -o /out/scoring         ./services/scoring && \
    CGO_ENABLED=0 go build -o /out/auth            ./services/auth && \
    CGO_ENABLED=0 go build -o /out/payment         ./services/payment && \
    CGO_ENABLED=0 go build -o /out/notification    ./services/notification && \
    CGO_ENABLED=0 go build -o /out/seed            ./seed

# Stage 2: Minimal runtime image
FROM alpine:3.20

RUN apk add --no-cache ca-certificates

COPY --from=builder /out/ /usr/local/bin/
COPY seed/questions.json /data/questions.json
