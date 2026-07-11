# Telegram setup (ZeroClaw)

Telegram is the **default** messaging channel in this lean stack. ZeroClaw
**long-polls** the Bot API — no inbound ports, no QR codes, no SMS.

WhatsApp (friend / group) is optional: [docs/whatsapp.md](whatsapp.md).

Full upstream notes: [ZeroClaw network deployment](https://github.com/zeroclaw-labs/zeroclaw/blob/master/docs/ops/network-deployment.md).

---

## Why Telegram first (WhatsApp optional)

| | Telegram bot | WhatsApp Web |
|---|---|---|
| Setup | BotFather token + peer allowlist | QR linked device |
| Inbound port | None (polls) | None (WebSocket); Cloud API needs webhook |
| Identity | Separate bot account | Linked phone number |
| Footprint | Token in `.env` | Session DB under `config/` / `data/` |

---

## Steps

### 1. Create a bot

1. Open Telegram → talk to [@BotFather](https://t.me/BotFather).
2. Send `/newbot` and follow the prompts.
3. Copy the **bot token** (`123456:ABC...`).

### 2. Get your numeric user ID

1. Message [@userinfobot](https://t.me/userinfobot) (or similar).
2. Copy your **numeric ID** (e.g. `123456789`).
3. Open a chat with **your new bot** and send `/start` so it can reply later.

### 3. Configure this repo

In `.env`:

```env
GEMINI_API_KEY=AIza...
TELEGRAM_BOT_TOKEN=123456:ABC...
TELEGRAM_ALLOWED_USERS=123456789
```

Multiple users: comma-separated IDs — `111,222,333`.

`make sync-config` writes those IDs into ZeroClaw schema v3
`[peer_groups.telegram_default].external_peers` (with `agents = ["main"]`).

Then:

```bash
make sync-config
make up
# or remote: make remote-deploy
make logs
```

### 4. Talk to the bot

Send a message in Telegram. Only IDs in `TELEGRAM_ALLOWED_USERS` are answered.

If the bot still asks for operator approval after a fresh deploy:

```bash
make remote-bind
# or: make remote-bind TG_USER=123456789
```

That runs `zeroclaw channel bind-telegram` and should also ensure the peer group
lists agent `main`. Then message again.

---

## Security

- Keep `TELEGRAM_ALLOWED_USERS` non-empty — an empty allowlist may mean “allow all” depending on ZeroClaw version.
- Never commit `.env`.
- Bot token = full control of that bot; rotate via BotFather if leaked.
