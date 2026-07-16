# Security Policy

## Reporting a Vulnerability

For **this wrapper repo**, open a private security advisory or contact the maintainer.

For **ZeroClaw itself**, follow upstream policy: email `security@zeroclaw.dev` — see [zeroclaw SECURITY.md](https://github.com/zeroclaw-labs/zeroclaw/blob/master/SECURITY.md). Do not file public issues for ZeroClaw vulns here.

## Hardening defaults in this stack

- Telegram allowlist (`TELEGRAM_ALLOWED_USERS` → peer_groups) — keep non-empty
- WhatsApp (if enabled): peer allowlist + prefer `mention_only` in groups — [docs/whatsapp.md](docs/whatsapp.md)
- Telegram / WhatsApp Web need egress only; gateway/dashboard is published on `:42617` for LAN — do not WAN-forward it
- Secrets in `.env` / `secrets/google/` only — never commit
- Treat `./config` and `./data` as sensitive (config, memory, WhatsApp session)
