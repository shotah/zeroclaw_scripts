# TODO — ZeroClaw lean stack

This repo is a thin Docker wrapper around [ZeroClaw](https://github.com/zeroclaw-labs/zeroclaw): **Gemini + Telegram**, optional **Google Workspace via gws** on distroless.

---

## Phase 1 — try it now

```bash
make init
# Edit .env: GEMINI_API_KEY, TELEGRAM_BOT_TOKEN, TELEGRAM_ALLOWED_USERS
make sync-config
make build
make up
make logs
# Message the bot on Telegram
```

Guide: [docs/telegram.md](docs/telegram.md)

### Checklist

- [x] Pivot from OpenClaw / Node to ZeroClaw image
- [x] Telegram-only channel (no WhatsApp / SMS)
- [x] Gemini provider via `.env` + config template
- [x] No host port publish; 512M mem limit
- [x] Slim Makefile (`init` / `up` / `logs` / `status`)
- [x] Remote deploy from Windows via SSH (`make remote-deploy`) — [docs/deploy.md](docs/deploy.md)
- [x] Schema v3 peer_groups for Telegram allowlist
- [ ] Container healthy (`make status` or `make remote-status`)
- [ ] Telegram reply from Gemini works

---

## Phase 2 — integrations

- [x] Thin image: distroless + `gws` binary only (not full Debian)
- [x] Workspace services in config (gmail/docs/calendar/drive/sheets/…)
- [ ] Google OAuth export — [docs/google-workspace.md](docs/google-workspace.md)
- [ ] WhatsApp Web for friend/group — [docs/whatsapp.md](docs/whatsapp.md)
- [ ] Flight search tool
- [ ] Optional `127.0.0.1:42617` gateway publish for zerocode TUI
- [ ] Pin `ZEROCLAW_BASE` to a specific `v0.x.y` tag
- [ ] CI: `docker compose config` validate

---

## Cut from the old OpenClaw design

| Removed | Why |
|---|---|
| WhatsApp / QR / Message yourself | Heavy session; Telegram is simpler |
| clawhub / flights-search | OpenClaw-specific; revisit under ZeroClaw |
| Control UI happy path | No published ports; dashboard optional |
| Node gateway always-on | Replaced by Rust daemon |
| Full Debian runtime for tools | Prefer copying one `gws` binary onto distroless |

---

## Notes after first run

- Schema v3 dropped channel `allowed_users`; use `peer_groups.*.external_peers` + `agents = ["main"]`.
- Upstream `:latest` is distroless/cc-debian13 (glibc), not Alpine.
