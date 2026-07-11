# Telegram setup (ZeroClaw)

Telegram is the only messaging channel in this lean stack. ZeroClaw **long-polls** the Bot API — no inbound ports, no QR codes, no SMS.

Full upstream notes: [ZeroClaw network deployment](https://github.com/zeroclaw-labs/zeroclaw/blob/master/docs/ops/network-deployment.md).

---

## Why Telegram (not WhatsApp)

| | Telegram bot | WhatsApp Web |
|---|---|---|
| Setup | BotFather token + allowlist | QR linked device |
| Inbound port | None (polls) | Session / optional webhook |
| Identity | Separate bot account | Your number or second SIM |
| Footprint | Token in `.env` | Session files under `data/` |

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

Then:

```bash
make sync-config
make up
make logs
```

### 4. Talk to the bot

Send a message in Telegram. Only IDs in `TELEGRAM_ALLOWED_USERS` are answered.

---

## Pairing note

Upstream ZeroClaw may require channel pairing on some builds (`zeroclaw onboard channels` / `zeroclaw channel bind-telegram`). If the bot ignores you after a healthy start:

```bash
# Debug shell (debian image has a shell; :latest is distroless)
make shell
# or:
docker compose exec zeroclaw zeroclaw status
```

Check logs with `make logs` for pairing / allowlist errors.

---

## Security

- Keep `TELEGRAM_ALLOWED_USERS` non-empty — an empty allowlist may mean “allow all” depending on ZeroClaw version.
- Never commit `.env`.
- Bot token = full control of that bot; rotate via BotFather if leaked.
