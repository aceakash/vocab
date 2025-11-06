# syntax=docker/dockerfile:1
FROM golang:1.21-alpine AS build
WORKDIR /app
COPY go.mod ./
RUN go mod download
COPY . .
RUN go build -o vocab ./cmd/web

FROM alpine:3.19
WORKDIR /app
# Non-root user for safety
RUN adduser -D appuser
COPY --from=build /app/vocab ./vocab
ENV PORT=8080
USER appuser
EXPOSE 8080
ENTRYPOINT ["./vocab"]
