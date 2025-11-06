# vocab

Minimal Go web application exposing a health check endpoint.

## Endpoints

- `GET /healthz` returns `200 OK`.

## Running locally (no Docker)

```bash
# Ensure Go 1.21+
export PORT=8080  # optional, defaults to 8080
go run ./cmd/web
# Visit http://localhost:8080/healthz
```

## Running with Docker

### Build image

```bash
docker build -t vocab .
```

### Run container

```bash
docker run -e PORT=8080 -p 8080:8080 vocab
# Then curl
curl http://localhost:8080/healthz
```

## Running with Docker Compose

```bash
docker compose up --build
# Then curl
curl http://localhost:8080/healthz
```

## Docker Compose environment override

Edit `docker-compose.yml` and change the `PORT` environment variable or override at runtime:

```bash
docker compose run -e PORT=9090 web
```

## Development notes

- Port comes from `PORT` env var (default 8080). You may specify with or without leading colon.

## License

See [LICENSE](LICENSE).
