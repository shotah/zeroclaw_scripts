# Web search (Gemini Google Search grounding)

Tim’s built-in ZeroClaw `web_search` scrapes DuckDuckGo. From Docker that
often hits a bot wall and retry loops. Instead we bake
[zchee/mcp-gemini-google-search](https://github.com/zchee/mcp-gemini-google-search)
— a static Go MCP that calls **Gemini Grounding with Google Search** using the
same `GEMINI_API_KEY` already in `.env`.

```mermaid
flowchart LR
  ZC[zeroclaw daemon] -->|MCP stdio| GS["mcp-gemini-google-search"]
  GS -->|generateContent + google_search| G[Gemini API]
  G --> Web[Google Search]
```

Built-in `[web_search] enabled = false` so Tim does not call DuckDuckGo.

---

## Setup

Nothing extra beyond the Gemini key you already use for chat:

1. `.env` has `GEMINI_API_KEY` (paid / billing-enabled AI Studio project so
   grounding is allowed).
2. `GEMINI_MODEL` defaults to `gemini-3.5-flash` — chat **and** the search MCP
   both use it (the MCP reads `GEMINI_MODEL` / `GEMINI_API_KEY` from the
   container env).
3. Rebuild and restart:

```bash
make build && make up
# or: make remote-deploy
```

Optional pin override:

```bash
# GEMINI_SEARCH_MCP_REF=1fe676adcdaa79ed0798fd32be0695ffee15c644
```

---

## Config wiring

```toml
mcp_bundles = ["strava", "garmin", "google-search"]

[[mcp.servers]]
name = "google-search"
transport = "stdio"
command = "mcp-gemini-google-search"

[mcp_bundles.google-search]
servers = ["google-search"]

[web_search]
enabled = false
```

Tool Tim should use: `google_search` (query string). Keep `web_fetch` for
opening a specific URL after search.

---

## Cost (ballpark)

Gemini 3 grounding (paid tier): ~**5,000 free grounded prompts / month**, then
about **$14 / 1,000 search queries**. Chat tokens are separate (already billed
via `GEMINI_API_KEY`). Free (no-billing) Gemini projects often cannot use
grounding.

---

## Smoke tests

```bash
make build
docker compose run --rm --entrypoint mcp-gemini-google-search zeroclaw -h || true
# Binary is stdio-only; real check is Telegram:
```

Ask Tim: “Search the web for today’s Seattle weather summary.”

He should call `google_search`, not DuckDuckGo / built-in `web_search`.

---

## Troubleshooting

| Symptom | Likely fix |
|---|---|
| DuckDuckGo / “blocked automated search” | Confirm `[web_search] enabled = false` and rebuild so the MCP binary is present |
| Tim doesn’t see `google_search` | Grant bundle `google-search`; `[mcp] deferred_loading = false`; rebuild |
| `GEMINI_API_KEY` / grounding errors | Billing enabled on the Google AI project; key has access to search grounding |
| Expensive search model | Keep `GEMINI_MODEL=gemini-3.5-flash` (MCP defaults to a Pro preview if unset) |
