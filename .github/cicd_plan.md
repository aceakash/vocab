# GitHub Actions Deployment Plan (vocab.untilfalse.com)

This file documents a CI/CD pattern for deploying the vocab web app container and its Caddy route without modifying Terraform user_data (no droplet replacement). You will move this to the app repo.

## Goals

- Build & push image to GHCR.
- Update (or create) Caddy site snippet.
- Ensure vocab service exists in docker-compose.
- Pull and run updated container.
- Reload Caddy for new routing.
- Keep process idempotent.

## Required Repository Secrets

- DROPLET_HOST: Droplet IPv4.
- DROPLET_USER: akash
- DROPLET_SSH_KEY: Private key (PEM). Use a deploy key with least privilege.
- GHCR_PAT: Personal access token with read:packages (and write if building here).

Optional future secrets:

- WATCHTOWER_WEBHOOK
- SLACK_WEBHOOK_URL

## Workflow Outline

1. On push to main (app repo): build image, tag with SHA + semver (e.g. 0.1.0).
2. Push image(s) to GHCR.
3. Deploy job (SSH):
   - Create /opt/caddy/sites if missing.
   - Upload vocab.caddy.
   - Append import directive to main Caddyfile if absent.
   - Append vocab service block to docker-compose.yml if absent.
   - docker compose pull vocab; docker compose up -d vocab.
   - Reload Caddy.
   - Health check.

## Caddy Site Snippet (uploaded as /opt/caddy/sites/vocab.caddy)

```caddy
vocab.untilfalse.com {
    encode zstd gzip
    header {
        Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        Referrer-Policy "strict-origin-when-cross-origin"
        Content-Security-Policy "default-src 'self';"
    }
    reverse_proxy vocab:8080
    log {
        output file /var/log/caddy/vocab.access.log
        format json
    }
}
```

## docker-compose.yml Service Block (append if missing)

```yaml
vocab:
  image: ghcr.io/aceakash/vocab:0.1.0
  container_name: vocab
  restart: unless-stopped
  networks:
    - proxy
  environment:
    APP_LOG_LEVEL: info
  labels:
    com.centurylinklabs.watchtower.enable: "true"
```

## Example Workflow (app repo)

```yaml
name: Deploy vocab

on:
  push:
    branches: [main]
    paths:
      - "Dockerfile"
      - "src/**"
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Login GHCR
        run: echo "${{ secrets.GHCR_PAT }}" | docker login ghcr.io -u ${{ github.actor }} --password-stdin
      - name: Set tags
        run: |
          echo "IMAGE_SHA=ghcr.io/aceakash/vocab:${{ github.sha }}" >> $GITHUB_ENV
          echo "IMAGE_SEMVER=ghcr.io/aceakash/vocab:0.1.0" >> $GITHUB_ENV
      - name: Build
        run: docker build -t $IMAGE_SHA -t $IMAGE_SEMVER .
      - name: Push
        run: |
          docker push $IMAGE_SHA
          docker push $IMAGE_SEMVER

  deploy:
    needs: build
    runs-on: ubuntu-latest
    concurrency: vocab-deploy
    steps:
      - name: Generate site snippet
        run: |
          cat > vocab.caddy <<'EOF'
          vocab.untilfalse.com {
              encode zstd gzip
              header {
                  Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
                  X-Content-Type-Options "nosniff"
                  X-Frame-Options "DENY"
                  Referrer-Policy "strict-origin-when-cross-origin"
                  Content-Security-Policy "default-src 'self';"
              }
              reverse_proxy vocab:8080
              log {
                  output file /var/log/caddy/vocab.access.log
                  format json
              }
          }
          EOF
      - name: Upload site file
        uses: appleboy/scp-action@v0.2.4
        with:
          host: ${{ secrets.DROPLET_HOST }}
          username: ${{ secrets.DROPLET_USER }}
          key: ${{ secrets.DROPLET_SSH_KEY }}
          source: "vocab.caddy"
          target: "/opt/caddy/sites/"
      - name: Remote deploy
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.DROPLET_HOST }}
          username: ${{ secrets.DROPLET_USER }}
          key: ${{ secrets.DROPLET_SSH_KEY }}
          script: |
            set -e
            cd /opt/caddy
            sudo mkdir -p sites
            # Ensure import
            grep -q '/opt/caddy/sites/*.caddy' Caddyfile || echo 'import /opt/caddy/sites/*.caddy' | sudo tee -a Caddyfile
            # Add service if missing
            if ! grep -q '^vocab:' docker-compose.yml; then
              sudo tee -a docker-compose.yml >/dev/null <<'YML'
              vocab:
                image: ghcr.io/aceakash/vocab:0.1.0
                container_name: vocab
                restart: unless-stopped
                networks:
                  - proxy
                environment:
                  APP_LOG_LEVEL: info
                labels:
                  com.centurylinklabs.watchtower.enable: "true"
              YML
            fi
            sudo docker compose pull vocab || true
            sudo docker compose up -d vocab
            sudo docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile || sudo docker compose restart caddy
            curl -fsS https://vocab.untilfalse.com/health || echo "Health endpoint failed."
```

## Health Check

- Prefer /health returning 200.
- Extend workflow to fail job if curl returns non-zero after retries.

## Rollback

- Re-run deploy with previous semver tag (e.g. 0.1.0).
- To remove route: delete vocab.caddy and reload Caddy.
- To remove container: docker compose rm -f vocab.

## Future Enhancements

- Add Watchtower notifications.
- Add structured log shipping.
- Pin digest tags (image@sha256:...).
- Use caddy-docker-proxy to eliminate manual file writes (requires base change).
