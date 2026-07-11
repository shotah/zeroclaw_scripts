.DEFAULT_GOAL := help

COMPOSE := docker compose
SERVICE := zeroclaw
ENV_FILE := .env
ENV_EXAMPLE := .env.example
CONFIG_EXAMPLE := config/config.toml.example

ifeq ($(OS),Windows_NT)
  ENV_COPY := powershell -NoProfile -Command "if (-not (Test-Path '$(ENV_FILE)')) { Copy-Item '$(ENV_EXAMPLE)' '$(ENV_FILE)'; Write-Host 'Created $(ENV_FILE) — edit GEMINI_API_KEY and Telegram vars' } else { Write-Host '$(ENV_FILE) already exists (use make env-force to overwrite)' }"
  ENV_FORCE := powershell -NoProfile -Command "Copy-Item '$(ENV_EXAMPLE)' '$(ENV_FILE)' -Force; Write-Host 'Overwrote $(ENV_FILE)'"
  MKDIR_DATA := powershell -NoProfile -Command "New-Item -ItemType Directory -Force -Path data/.zeroclaw, data/data | Out-Null"
  REMOTE := powershell -NoProfile -ExecutionPolicy Bypass -File scripts/remote.ps1
else
  ENV_COPY := @if [ -f $(ENV_FILE) ]; then \
                echo "$(ENV_FILE) already exists (use 'make env-force' to overwrite)"; \
              else \
                cp $(ENV_EXAMPLE) $(ENV_FILE) && echo "Created $(ENV_FILE) — edit GEMINI_API_KEY and Telegram vars"; \
              fi
  ENV_FORCE := cp $(ENV_EXAMPLE) $(ENV_FILE) && echo "Overwrote $(ENV_FILE)"
  MKDIR_DATA := mkdir -p data/.zeroclaw data/data
  REMOTE := bash scripts/remote.sh
endif

.PHONY: help env env-force dirs init sync-config config pull up down restart logs ps status shell clean \
        remote-check remote-sync remote-up remote-down remote-restart remote-logs remote-ps remote-status \
        remote-pull remote-ssh remote-deploy

help: ## Show available commands
	@echo.
	@echo   docker_open_claw  /  ZeroClaw lean
	@echo   ==================================
	@echo   Gemini + Telegram agent in Docker. No WhatsApp. No published ports.
	@echo.
	@echo   Quick start (local)
	@echo   -------------------
	@echo     make init              Create .env, data dirs, config
	@echo     # edit .env            GEMINI_API_KEY, TELEGRAM_BOT_TOKEN,
	@echo     #                      TELEGRAM_ALLOWED_USERS
	@echo     make sync-config       Apply .env into data/.zeroclaw/config.toml
	@echo     make up                Start daemon
	@echo     make logs              Watch logs / message your Telegram bot
	@echo.
	@echo   Quick start (Ubuntu server from this PC)
	@echo   ----------------------------------------
	@echo     # set DEPLOY_HOST, DEPLOY_USER, DEPLOY_PATH in .env
	@echo     make remote-check      Verify SSH + Docker on the server
	@echo     make remote-deploy     Sync files + docker compose up -d
	@echo     make remote-logs       Follow server logs
	@echo.
	@echo   Setup
	@echo   -----
	@echo     help                   Show this help (default)
	@echo     env                    Create .env from .env.example (skip if exists)
	@echo     env-force              Overwrite .env from .env.example
	@echo     dirs                   Create ./data directories
	@echo     config                 Install config.toml template if missing
	@echo     sync-config            Sync model + Telegram allowlist from .env
	@echo     init                   env + dirs + config + sync-config
	@echo.
	@echo   Local Docker
	@echo   ------------
	@echo     pull                   Pull ZeroClaw image locally
	@echo     up                     Start stack (runs sync-config first)
	@echo     down                   Stop and remove containers
	@echo     restart                Restart containers
	@echo     logs                   Follow container logs
	@echo     ps                     Show compose status
	@echo     status                 zeroclaw health check inside container
	@echo     shell                  Debug shell (debian image; :latest is distroless)
	@echo     clean                  Same as down (keeps ./data)
	@echo.
	@echo   Remote deploy  (needs OpenSSH; see docs/deploy.md)
	@echo   --------------------------------------------------
	@echo     remote-check           SSH + docker available on DEPLOY_HOST?
	@echo     remote-sync            scp compose, .env, config to server
	@echo     remote-up              docker compose pull and up -d on server
	@echo     remote-down            Stop stack on server
	@echo     remote-restart         Restart stack on server
	@echo     remote-logs            Follow logs on server
	@echo     remote-ps              compose ps on server
	@echo     remote-status          Health check on server
	@echo     remote-pull            Pull image on server only
	@echo     remote-ssh             Interactive SSH in DEPLOY_PATH
	@echo     remote-ssh CMD='...'   Run one remote command in DEPLOY_PATH
	@echo     remote-deploy          remote-sync + remote-up
	@echo.
	@echo   Docs
	@echo   ----
	@echo     docs/telegram.md       BotFather + allowlist setup
	@echo     docs/deploy.md         Windows -^> Ubuntu remote deploy
	@echo     README.md              Overview and architecture
	@echo     TODO.md                Phase 1 / phase 2 checklist
	@echo.
	@echo   Required .env keys: GEMINI_API_KEY  TELEGRAM_BOT_TOKEN  TELEGRAM_ALLOWED_USERS
	@echo   Remote .env keys:   DEPLOY_HOST  DEPLOY_USER  DEPLOY_PATH  [DEPLOY_SSH_KEY]
	@echo.

env: ## Create .env from .env.example (skips if exists)
	$(ENV_COPY)

env-force: ## Overwrite .env from .env.example
	$(ENV_FORCE)

dirs: ## Create data directories
	$(MKDIR_DATA)
	@echo Data dirs ready under ./data/

config: dirs ## Install config template into data/.zeroclaw/ if missing
ifeq ($(OS),Windows_NT)
	@powershell -NoProfile -Command "if (-not (Test-Path 'data/.zeroclaw/config.toml')) { Copy-Item '$(CONFIG_EXAMPLE)' 'data/.zeroclaw/config.toml'; Write-Host 'Installed data/.zeroclaw/config.toml' } else { Write-Host 'config.toml already present' }"
else
	@if [ ! -f data/.zeroclaw/config.toml ]; then \
	  cp $(CONFIG_EXAMPLE) data/.zeroclaw/config.toml && echo "Installed data/.zeroclaw/config.toml"; \
	else echo "config.toml already present"; fi
endif

sync-config: dirs ## Sync .env model + Telegram allowlist into config.toml
	@node scripts/sync-config.js

init: env dirs config sync-config ## First-time setup: .env, dirs, config
	@echo.
	@echo Next steps:
	@echo   1. Edit .env — GEMINI_API_KEY, TELEGRAM_*, and DEPLOY_* for remote
	@echo   2. Local:  make up
	@echo   3. Remote: make remote-deploy
	@echo.
	@echo Guides: docs/telegram.md   docs/deploy.md
	@echo.

pull: ## Pull ZeroClaw image (local Docker)
	docker pull ghcr.io/zeroclaw-labs/zeroclaw:latest

up: sync-config ## Start ZeroClaw daemon locally (no published ports)
	$(COMPOSE) up -d $(SERVICE)

down: ## Stop and remove local containers
	$(COMPOSE) down

restart: ## Restart local daemon
	$(COMPOSE) restart $(SERVICE)

logs: ## Follow local logs
	$(COMPOSE) logs -f $(SERVICE)

ps: ## Local container status
	$(COMPOSE) ps

status: ## Local ZeroClaw health
	$(COMPOSE) exec $(SERVICE) zeroclaw status --format=exit-code && echo OK || echo FAILED

shell: ## Shell via debian image (distroless has no shell)
	docker run --rm -it --entrypoint sh \
	  -v "$(CURDIR)/data:/zeroclaw-data" \
	  --env-file .env \
	  ghcr.io/zeroclaw-labs/zeroclaw:debian

clean: ## Stop local containers (keeps ./data)
	$(COMPOSE) down

# --- Remote Ubuntu server (from Windows via OpenSSH) -------------------------

remote-check: ## Test SSH + Docker on DEPLOY_HOST
	$(REMOTE) check

remote-sync: sync-config ## Copy compose/.env/config to server (does not sync data volume)
	$(REMOTE) sync

remote-up: ## docker compose up -d on server
	$(REMOTE) up

remote-down: ## docker compose down on server
	$(REMOTE) down

remote-restart: ## Restart stack on server
	$(REMOTE) restart

remote-logs: ## Follow logs on server
	$(REMOTE) logs

remote-ps: ## docker compose ps on server
	$(REMOTE) ps

remote-status: ## Health check on server
	$(REMOTE) status

remote-pull: ## Pull image on server
	$(REMOTE) pull

remote-ssh: ## SSH into server (cd DEPLOY_PATH). Extra args: make remote-ssh CMD='ls'
	$(REMOTE) ssh $(CMD)

remote-deploy: remote-sync remote-up ## Sync files then start on server
	@echo.
	@echo Deployed. Check: make remote-logs
	@echo.
