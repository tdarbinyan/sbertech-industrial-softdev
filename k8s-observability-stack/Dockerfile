FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY . .

RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux go build -o main .

FROM alpine:latest

WORKDIR /app
COPY --from=builder /app/main .

RUN mkdir -p /app/logs

EXPOSE 5000

CMD ["./main"] 