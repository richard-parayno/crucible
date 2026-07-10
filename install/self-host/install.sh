#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${CRUCIBLE_INSTALL_DIR:-/opt/crucible}"
IMAGE="${CRUCIBLE_IMAGE:-ghcr.io/crucible-app/crucible:latest}"
HTTP_PORT="${CRUCIBLE_HTTP_PORT:-3000}"
DOCKER_SOCKET="${DOCKER_SOCKET:-/var/run/docker.sock}"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

warn() {
  printf 'warning: %s\n' "$*" >&2
}

need_command() {
  command -v "$1" >/dev/null 2>&1 || fail "$2"
}

random_secret() {
  openssl rand -hex "$1"
}

if [ "$(id -u)" -ne 0 ]; then
  fail "run this installer as root, for example: curl -fsSL <install-url> | sudo bash"
fi

need_command docker "Docker is required but was not found. Install Docker Engine, then rerun this installer."
need_command openssl "openssl is required to generate secrets. Install openssl, then rerun this installer."

docker compose version >/dev/null 2>&1 || fail "Docker Compose v2 is required. Install the Docker Compose plugin, then rerun this installer."
[ -S "$DOCKER_SOCKET" ] || fail "Docker socket not found at $DOCKER_SOCKET. Start Docker or set DOCKER_SOCKET."

TAILSCALE_IP=""
if command -v tailscale >/dev/null 2>&1; then
  TAILSCALE_IP="$(tailscale ip -4 2>/dev/null | head -n 1 || true)"
  if [ -n "$TAILSCALE_IP" ]; then
    BIND_ADDRESS="${CRUCIBLE_BIND_ADDRESS:-$TAILSCALE_IP}"
    ACCESS_HOST="$TAILSCALE_IP"
  else
    warn "Tailscale is installed but no Tailscale IPv4 address was detected."
    BIND_ADDRESS="${CRUCIBLE_BIND_ADDRESS:-127.0.0.1}"
    ACCESS_HOST="127.0.0.1"
  fi
else
  warn "Tailscale was not found. Crucible will bind to localhost; use an SSH tunnel or install/connect Tailscale and rerun."
  BIND_ADDRESS="${CRUCIBLE_BIND_ADDRESS:-127.0.0.1}"
  ACCESS_HOST="127.0.0.1"
fi

DOCKER_SOCKET_GID="$(stat -c '%g' "$DOCKER_SOCKET")"

umask 077
mkdir -p "$APP_DIR/storage" "$APP_DIR/log"

ENV_FILE="$APP_DIR/.env"
COMPOSE_FILE="$APP_DIR/compose.yml"

if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  SECRET_KEY_BASE="${SECRET_KEY_BASE:?existing .env is missing SECRET_KEY_BASE}"
  CRUCIBLE_SETUP_TOKEN="${CRUCIBLE_SETUP_TOKEN:?existing .env is missing CRUCIBLE_SETUP_TOKEN}"
else
  SECRET_KEY_BASE="$(random_secret 64)"
  CRUCIBLE_SETUP_TOKEN="$(random_secret 24)"
fi

cat >"$ENV_FILE" <<ENV
RAILS_ENV=production
RAILS_LOG_LEVEL=info
RAILS_SERVE_STATIC_FILES=true
SECRET_KEY_BASE=$SECRET_KEY_BASE
CRUCIBLE_SETUP_TOKEN=$CRUCIBLE_SETUP_TOKEN
CRUCIBLE_IMAGE=$IMAGE
CRUCIBLE_BIND_ADDRESS=$BIND_ADDRESS
CRUCIBLE_HTTP_PORT=$HTTP_PORT
DOCKER_SOCKET=$DOCKER_SOCKET
DOCKER_SOCKET_GID=$DOCKER_SOCKET_GID
ENV

cat >"$COMPOSE_FILE" <<'YAML'
x-crucible-app: &crucible-app
  image: ${CRUCIBLE_IMAGE}
  restart: unless-stopped
  env_file:
    - .env
  volumes:
    - ./storage:/rails/storage
    - ./log:/rails/log
    - ${DOCKER_SOCKET}:/var/run/docker.sock
  group_add:
    - "${DOCKER_SOCKET_GID}"

services:
  crucible:
    <<: *crucible-app
    ports:
      - "${CRUCIBLE_BIND_ADDRESS}:${CRUCIBLE_HTTP_PORT}:80"
    healthcheck:
      test: ["CMD", "curl", "-fsS", "http://127.0.0.1/up"]
      interval: 30s
      timeout: 5s
      retries: 5
      start_period: 30s

  worker:
    <<: *crucible-app
    command: ["./bin/jobs"]
    depends_on:
      crucible:
        condition: service_healthy
YAML

docker compose --project-directory "$APP_DIR" -f "$COMPOSE_FILE" pull
docker compose --project-directory "$APP_DIR" -f "$COMPOSE_FILE" up -d

SETUP_URL="http://$ACCESS_HOST:$HTTP_PORT/sign_up?setup_token=$CRUCIBLE_SETUP_TOKEN"

cat <<INFO

Crucible is starting.

Compose project: $APP_DIR/compose.yml
Persistent data:  $APP_DIR/storage
Docker socket:    $DOCKER_SOCKET

Create the first administrator account:
  $SETUP_URL
INFO

if [ "$ACCESS_HOST" = "127.0.0.1" ]; then
  cat <<INFO

No Tailscale address was detected, so Crucible is bound to localhost.
From your workstation, open an SSH tunnel:
  ssh -L $HTTP_PORT:127.0.0.1:$HTTP_PORT root@<vps-host>

Then visit:
  http://127.0.0.1:$HTTP_PORT/sign_up?setup_token=$CRUCIBLE_SETUP_TOKEN
INFO
fi

cat <<INFO

After the first administrator account is created, registration closes automatically.
Manage the stack with:
  docker compose --project-directory $APP_DIR -f $COMPOSE_FILE ps
  docker compose --project-directory $APP_DIR -f $COMPOSE_FILE logs -f
INFO
