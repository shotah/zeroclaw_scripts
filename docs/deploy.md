# Deploy to an Ubuntu server

Run ZeroClaw on a remote Ubuntu box from this Windows (or Linux) workstation via **SSH + scp**. Docker only needs to run on the **server**.

```mermaid
flowchart LR
  Win[Windows workstation] -->|scp compose .env config| Srv[Ubuntu server]
  Win -->|ssh docker compose| Srv
  Srv --> TG[Telegram API]
  Srv --> GEM[Gemini API]
```

---

## Server prerequisites

On the Ubuntu host (once):

```bash
# Docker Engine + Compose plugin
sudo apt update
sudo apt install -y docker.io docker-compose-v2
sudo usermod -aG docker "$USER"   # then log out/in

# Project dir — match DEPLOY_PATH in .env (examples: /zeroclaw or /opt/zeroclaw)
sudo mkdir -p /zeroclaw
sudo chown "$USER:$USER" /zeroclaw
```

Set `ZEROCLAW_UID` / `ZEROCLAW_GID` in `.env` to your server user (`id -u` / `id -g`, usually `1000`). The container runs as that user so pairing and `data/` writes work without `chown 65534`.

Ensure outbound HTTPS works (Telegram + Gemini). **No inbound ports** required for Telegram polling.

---

## Workstation prerequisites (Windows)

1. **OpenSSH Client** — Settings → Apps → Optional features → OpenSSH Client
   Or: `Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0`
2. SSH key access to the server (`ssh ubuntu@your-host` works without a password prompt, or with your key).
3. This repo + `make` (Git Bash / chocolatey `make` / etc.).

You do **not** need Docker Desktop on Windows if you only use `make remote-*`.

---

## Configure `.env`

```env
# … Gemini + Telegram secrets …

DEPLOY_HOST=myserver.example.com
DEPLOY_USER=user
DEPLOY_PATH=/zeroclaw
DEPLOY_SSH_PORT=22
DEPLOY_SSH_KEY=C:/Users/you/.ssh/id_ed25519
```

Leave `DEPLOY_SSH_KEY` blank to use your default agent / `~/.ssh/id_*`.

---

## Deploy

```bash
make sync-config          # render config.toml locally
make remote-check         # SSH + docker available?
make remote-deploy        # sync files + docker compose up -d
make remote-logs          # follow server logs
```

Or step by step:

| Command | What it does |
|---|---|
| `make remote-sync` | scp compose, Makefile, `.env`, config, secrets, scripts |
| `make remote-up` | `docker compose build --pull && up -d` on server |
| `make remote-down` | stop stack on server |
| `make remote-restart` | restart |
| `make remote-ps` | compose ps |
| `make remote-status` | `zeroclaw status` |
| `make remote-pull` | rebuild thin image (pulls upstream base) |
| `make remote-ssh` | interactive shell in `DEPLOY_PATH` |

---

## What gets copied

Synced:

- `docker-compose.yml`, `Makefile`, `.env`, `.env.example`
- `config/config.toml.example`, `data/.zeroclaw/config.toml`
- `scripts/sync-config.js`, `docs/telegram.md`, `README.md`, `Dockerfile`

**Not** synced: local `data/` runtime memory (SQLite / workspace). The server keeps its own `DEPLOY_PATH/data/` so restarts don’t wipe chat memory when you redeploy from Windows.

To wipe server state intentionally:

```bash
make remote-ssh CMD='rm -rf data/data/* && docker compose restart'
```

---

## Security notes

- `.env` (with API keys) is copied to the server over SSH — keep the box locked down (SSH keys only, no password auth).
- Prefer a dedicated deploy user with Docker group access, not root login.
- `DEPLOY_*` is only used by the workstation Makefile; the container does not need those vars.

---

## Escaping Windows

When you move the workstation to Ubuntu, the same `.env` works — `make remote-*` calls `scripts/remote.sh` instead of `remote.ps1`. No rewrite required.
