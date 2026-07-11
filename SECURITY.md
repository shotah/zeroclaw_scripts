# Security Policy

## Reporting a Vulnerability

For **this wrapper repo**, open a private security advisory or contact the maintainer.

For **ZeroClaw itself**, follow upstream policy: email `security@zeroclaw.dev` — see [zeroclaw SECURITY.md](https://github.com/zeroclaw-labs/zeroclaw/blob/master/SECURITY.md). Do not file public issues for ZeroClaw vulns here.

## Hardening defaults in this stack

- Telegram allowlist (`TELEGRAM_ALLOWED_USERS`) — keep non-empty
- No published host ports (Telegram polls outbound only)
- Secrets in `.env` only — never commit
- Treat `./data` as sensitive (config, memory, sessions)
