#!/usr/bin/env bash
# Remote deploy helper (Unix / WSL / Ubuntu workstation → Ubuntu server)
# Usage: ./scripts/remote.sh <check|sync|up|down|restart|logs|ps|status|pull|ssh> [remote cmd...]

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

load_env() {
  [[ -f .env ]] || { echo "Missing .env"; exit 1; }
  set -a
  # shellcheck disable=SC1091
  source <(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' .env | sed 's/\r$//')
  set +a
}

load_env
: "${DEPLOY_HOST:?Set DEPLOY_HOST in .env}"
DEPLOY_USER="${DEPLOY_USER:-ubuntu}"
DEPLOY_PATH="${DEPLOY_PATH:-/opt/zeroclaw}"
DEPLOY_SSH_PORT="${DEPLOY_SSH_PORT:-22}"

SSH_OPTS=(-p "$DEPLOY_SSH_PORT" -o StrictHostKeyChecking=accept-new)
[[ -n "${DEPLOY_SSH_KEY:-}" ]] && SSH_OPTS+=(-i "$DEPLOY_SSH_KEY")
TARGET="${DEPLOY_USER}@${DEPLOY_HOST}"

remote() {
  ssh "${SSH_OPTS[@]}" "$TARGET" "$@"
}

ACTION="${1:-}"
shift || true

case "$ACTION" in
  check)
    echo "Checking SSH: $TARGET:$DEPLOY_SSH_PORT → $DEPLOY_PATH"
    remote "echo ok && uname -a && docker --version && docker compose version"
    ;;
  sync)
    command -v node >/dev/null && node scripts/sync-config.js || true
    remote "mkdir -p '$DEPLOY_PATH/data/.zeroclaw' '$DEPLOY_PATH/data/data' '$DEPLOY_PATH/config' '$DEPLOY_PATH/scripts' '$DEPLOY_PATH/docs'"
    for f in docker-compose.yml Makefile .env .env.example Dockerfile \
             config/config.toml.example scripts/sync-config.js docs/telegram.md README.md; do
      [[ -f "$f" ]] || continue
      echo "scp $f"
      scp "${SSH_OPTS[@]}" "$f" "$TARGET:$DEPLOY_PATH/$f"
    done
    if [[ -f data/.zeroclaw/config.toml ]]; then
      scp "${SSH_OPTS[@]}" data/.zeroclaw/config.toml "$TARGET:$DEPLOY_PATH/data/.zeroclaw/config.toml"
    fi
    echo "Synced to $TARGET:$DEPLOY_PATH"
    ;;
  up) remote "cd '$DEPLOY_PATH' && docker compose pull && docker compose up -d" ;;
  down) remote "cd '$DEPLOY_PATH' && docker compose down" ;;
  restart) remote "cd '$DEPLOY_PATH' && docker compose restart" ;;
  logs) ssh "${SSH_OPTS[@]}" -t "$TARGET" "cd '$DEPLOY_PATH' && docker compose logs -f --tail=100" ;;
  ps) remote "cd '$DEPLOY_PATH' && docker compose ps" ;;
  status) remote "cd '$DEPLOY_PATH' && docker compose exec -T zeroclaw zeroclaw status --format=exit-code && echo OK" ;;
  pull) remote "cd '$DEPLOY_PATH' && docker compose pull" ;;
  ssh)
    if [[ $# -gt 0 ]]; then
      ssh "${SSH_OPTS[@]}" -t "$TARGET" "cd '$DEPLOY_PATH' && $*"
    else
      ssh "${SSH_OPTS[@]}" -t "$TARGET" "cd '$DEPLOY_PATH' && exec \$SHELL -l"
    fi
    ;;
  *)
    echo "Usage: $0 <check|sync|up|down|restart|logs|ps|status|pull|ssh>"
    exit 1
    ;;
esac
