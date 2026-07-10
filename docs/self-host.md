# Self-host Crucible on a VPS

Crucible's MVP self-host path is designed for a single Linux VPS accessed over Tailscale.

The installer does not install Docker or Tailscale. It preflights those dependencies, writes a Docker Compose project under `/opt/crucible`, generates secrets, mounts persistent storage, mounts the Docker socket, and starts the web and worker containers.

## Prerequisites

- Linux VPS with root or sudo access
- Docker Engine
- Docker Compose v2 plugin
- Tailscale installed and connected, recommended
- A published Crucible image available to the VPS

## Install

Set `CRUCIBLE_IMAGE` to the image you published, then run the installer:

```sh
curl -fsSL https://example.com/crucible/install.sh | sudo env CRUCIBLE_IMAGE=ghcr.io/your-org/crucible:latest bash
```

For local testing from a checkout, copy or execute `install/self-host/install.sh` directly on the VPS.

The installer creates:

- `/opt/crucible/compose.yml`
- `/opt/crucible/.env`
- `/opt/crucible/storage`
- `/opt/crucible/log`

The generated Compose stack runs:

- `crucible`, the Rails web process
- `worker`, the Solid Queue worker used for agent lifecycle jobs

Both containers share `/opt/crucible/storage` and mount `/var/run/docker.sock`. The MVP execution boundary is Docker Compose through that socket.

## First administrator

The installer generates `CRUCIBLE_SETUP_TOKEN` and prints a one-time setup URL:

```text
http://<tailscale-ip>:3000/sign_up?setup_token=<token>
```

Use that URL to create the first administrator account. After the first user exists, registration closes automatically and `/sign_up` redirects to sign in.

If Tailscale is not available, Crucible binds to `127.0.0.1` and the installer prints SSH tunnel guidance:

```sh
ssh -L 3000:127.0.0.1:3000 root@<vps-host>
```

## Configuration

Supported installer environment variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `CRUCIBLE_IMAGE` | `ghcr.io/crucible-app/crucible:latest` | Container image to run |
| `CRUCIBLE_INSTALL_DIR` | `/opt/crucible` | Install directory |
| `CRUCIBLE_HTTP_PORT` | `3000` | Host port |
| `CRUCIBLE_BIND_ADDRESS` | Tailscale IPv4 or `127.0.0.1` | Host bind address |
| `DOCKER_SOCKET` | `/var/run/docker.sock` | Docker socket path |

To update the stack after publishing a new image:

```sh
cd /opt/crucible
docker compose pull
docker compose up -d
```

## Uninstall

```sh
cd /opt/crucible
docker compose down
```

Remove `/opt/crucible` only if you also want to delete the SQLite databases, runtime project files, logs, and generated secrets.
