# WhatsApp setup (ZeroClaw)

Telegram stays the default channel in this repo. WhatsApp is **optional** when you
want to chat with people who only use WhatsApp (DM a friend, or a small group).

ZeroClaw supports two backends. For “Tim is his own contact + friends on
WhatsApp,” prefer **WhatsApp Web on a dedicated number**. **Cloud API** is Meta’s
Business Platform (webhook, verification) — usually overkill here.

Upstream: [channels reference](https://github.com/zeroclaw-labs/zeroclaw/blob/master/docs/reference/api/channels-reference.md).

---

## Pick a path (Tim as his own user)

You want Tim to be a **separate WhatsApp contact**, not replies that look like
they came from your personal account. That means Tim needs **his own phone
number** — WhatsApp identity is the number, period.

| Path | Who Tim appears as | Allowlist friends? | Ports / Meta? | Effort |
|---|---|---|---|---|
| **A. WhatsApp Web + spare number** (recommended here) | Tim’s number (SIM / eSIM / old phone) | Yes (`peer_groups` + policies) | No inbound ports | Low — QR link that phone |
| **B. Cloud API (“Meta Business”)** | Official WhatsApp Business number | Yes | **Yes** — HTTPS webhook/tunnel + Meta app | High — Business verification, billing, public URL |
| ~~Link your personal WhatsApp~~ | **You** (Tim types as Chris) | Yes | No | Easy, but wrong for your goal |

### What is “Meta Business”?

It’s Meta’s **official WhatsApp Business Platform** (Cloud API):

1. Create a Meta Developer app and add the WhatsApp product  
2. Usually attach a **Business Portfolio** / WhatsApp Business Account  
3. Get an API token + phone number id (often a rented/cloud number)  
4. Meta sends inbound messages to your **public HTTPS webhook**  

That last part fights this stack’s “no published ports” design (you’d need
Cloudflare Tunnel / ngroup / Tailscale Funnel, etc.). It’s meant for companies
running customer support inboxes, not a home assistant.

### Recommendation for you

Use **path A**: put WhatsApp on a **dedicated number** (cheap prepaid SIM, eSIM,
or an old Android just for Tim). Link that device via WhatsApp Web to ZeroClaw.
Friends add **Tim’s number**; only numbers you put in
`peer_groups.whatsapp_default.external_peers` can talk to him. You still chat
from your own WhatsApp like any other contact.

Skip Cloud API unless you later want a verified business brand and are OK
exposing a webhook.

### No spare phone? Easier alternatives than WhatsApp

WhatsApp **rejects most Twilio / Google Voice / “SMS API” numbers** for signup
(VoIP). Paying ~$5/mo for a programmable SMS number usually does **not** get
you a WhatsApp identity. SMS group chat via Twilio is also a weak fit (10DLC
registration in the US, awkward “groups,” Tim isn’t a normal contact).

| Option | Tim’s identity | Friend friction | Fits this stack? |
|---|---|---|---|
| **Discord bot** | Separate bot user (@Tim) | Low if friends already use Discord; free server + invite | **Best next step** — ZeroClaw has Discord; allowlist user IDs; groups/channels |
| **Slack** (free workspace) | Bot/app in the workspace | OK for a small crew; invite-only | Good — similar to Discord |
| **Stay on Telegram** | Already works | High if nobody uses it | Already done |
| **Signal** | Needs a real mobile number too | Privacy-friendly but same SIM problem | Possible, same number hassle |
| **Twilio SMS** | A phone number that texts | Friends text a number; no rich groups | Possible but clunky + compliance; not WhatsApp |
| **WhatsApp** | Needs **real mobile** SIM/eSIM (not VoIP) | Friends already there | Hardest without a second line |

**Practical pick:** Discord (or Slack) for Tim-as-bot + allowlisted friends.
If WhatsApp is non-negotiable, cheapest reliable path is a **prepaid physical
SIM or carrier eSIM** (~$5–15/mo) on your **current** phone via WhatsApp’s
multi-account / dual-SIM — not a Twilio number.

---

## Friend + group recipe (Web mode)

Goal: you and a friend can DM Tim, and optionally share a WhatsApp group where
Tim only answers when @mentioned.

### 1. Persist a session path

Session must survive restarts. Under this repo’s mounts, use something under
`config/` or `data/` (both already on the server):

```toml
[channels.whatsapp.default]
enabled = true
session_path = "/zeroclaw-data/.zeroclaw/state/whatsapp-web/session.db"
# Optional: E.164 without spaces — seeds link / identity
# pair_phone = "15551234567"

# Personal phone behavior (friend / group friendly)
mode = "personal"
dm_policy = "allowlist"
group_policy = "allowlist"
mention_only = true          # in groups: only reply when @mentioned
self_chat_mode = false

# Optional: lock to one group once you know its JID (see below)
# allowed_groups = ["1203630xxxxxxxxx@g.us"]
```

Create the directory once on the server (owned by your deploy user):

```bash
make remote-ssh CMD='mkdir -p config/state/whatsapp-web'
```

### 2. Allow Tim’s agent on WhatsApp + peer allowlist

Schema v3 auth is **peer groups**, same idea as Telegram.

```toml
[agents.main]
channels = ["telegram.default", "whatsapp.default"]

[peer_groups.whatsapp_default]
channel = "whatsapp.default"
agents = ["main"]
# Your number + friend’s number (E.164). Example placeholders only:
external_peers = ["+15551110001", "+15551110002"]
```

Keep Telegram’s peer group as-is so both channels work.

### 3. Link the device (QR)

Redeploy so config is on the server, then watch logs and scan QR from the
phone that owns Tim’s number:

```bash
make remote-deploy
make remote-logs
```

On the phone: **WhatsApp → Settings → Linked devices → Link a device**, scan
the QR from the logs (or follow any pair-code prompt ZeroClaw prints).

Session is stored at `session_path`. Don’t delete that file or you’ll relink.

> **Image note:** WhatsApp Web needs the `whatsapp-web` / wa-rs build in the
> binary. If logs say Web mode isn’t available after setting `session_path`,
> check your `ZEROCLAW_BASE` image release notes or open an issue upstream —
> Cloud API may still work but needs a tunnel (next section).

### 4. DM your friend

1. Friend messages Tim’s WhatsApp number (or you message from an allowlisted phone).
2. Sender must be in `peer_groups.whatsapp_default.external_peers`.
3. If Tim ignores them, add their E.164 and `make remote-deploy` (or set via
   `zeroclaw config set` on the server), then retry.

### 5. Group with your friend

1. Create a WhatsApp group: you + friend + Tim’s number (the linked phone).
2. Send a message in the group; with `mention_only = true`, Tim stays quiet
   until someone @mentions the linked contact.
3. To restrict Tim to **only that group**, grab the group JID from logs (look
   for `@g.us`) and set:

   ```toml
   allowed_groups = ["1203630xxxxxxxxx@g.us"]
   ```

   Empty `allowed_groups` = all groups allowed (still subject to
   `group_policy` / `mention_only` / peer allowlist).

---

## Cloud API (optional / heavier)

Only if you want Meta’s official Business API:

1. Meta Developer app → WhatsApp product → permanent token + phone number id.
2. Set on the channel (no `session_path`):

   ```toml
   [channels.whatsapp.default]
   enabled = true
   access_token = "EAAB..."
   phone_number_id = "123456789012345"
   verify_token = "pick-a-long-random-string"
   # app_secret = "..."   # recommended for signature checks
   ```

3. Publish the gateway with TLS (this breaks the “no ports” lean default), e.g.
   tunnel to `/whatsapp`, and point Meta’s webhook at it with the same
   `verify_token`.

Prefer Web mode for a home server + friends.

---

## Config checklist

Add to `config/config.toml` (example is Telegram-only by default — WhatsApp is
opt-in so we don’t surprise-link a phone):

1. `[channels.whatsapp.default]` — Web `session_path` + policies above  
2. `[peer_groups.whatsapp_default]` — `agents = ["main"]` + friend numbers  
3. `[agents.main].channels` — include `"whatsapp.default"`  
4. `make remote-deploy` → link device → test DM → then group  

`.env` does **not** sync WhatsApp yet (Telegram peers only). Edit `config.toml`
(or use `zeroclaw config set` over `make remote-ssh`).

---

## Security

- Keep `external_peers` tight — WhatsApp numbers are easy to spam if open.
- Prefer `mention_only = true` in groups so Tim doesn’t reply to every chat line.
- Prefer a **dedicated number** for Tim so your personal chats stay private.
- Session DB is credentials — stays under gitignored `config/` / `data/`.
- Cloud API tokens belong in env / secrets, never committed.

---

## Troubleshooting

| Symptom | Likely fix |
|---|---|
| No QR / “web mode unavailable” | Image may lack WhatsApp Web; confirm `session_path` set and image features |
| Friend ignored | Add their E.164 to `peer_groups.whatsapp_default.external_peers`; ensure `agents = ["main"]` |
| Group ignored | `group_policy`, `mention_only`, or `allowed_groups` mismatch; @mention Tim |
| Relink every restart | `session_path` not on a persistent volume |
| Cloud webhook 403 / no messages | Tunnel URL, `verify_token`, subscribe to `messages` |

Telegram guide: [docs/telegram.md](telegram.md). Deploy: [docs/deploy.md](deploy.md).
