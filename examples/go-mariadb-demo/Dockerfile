FROM golang:1.22-alpine AS builder
WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY cmd ./cmd
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /out/go-mariadb-demo ./cmd/api

FROM alpine:3.20
RUN adduser -D -u 10001 appuser
USER appuser
WORKDIR /app
COPY --from=builder /out/go-mariadb-demo /app/go-mariadb-demo

EXPOSE 8080
ENTRYPOINT ["/app/go-mariadb-demo"]
