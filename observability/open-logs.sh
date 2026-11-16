#!/usr/bin/env bash
# ==============================================================================
# Opens an SSH tunnel to VictoriaLogs (127.0.0.1:9428) and launches the
# default web browser to http://localhost:9428/select/vmui/.
#
# Automatically reads SSH_HOST/HOSTNAME/HOST, SSH_USER/USER, and SSH_PORT/PORT
# from ENV_FILE, ./.env, or <TECHSTACK_ROOT>/.env.
#
# Usage:
#   bash open-logs.sh
#   bash open-logs.sh user@server-ip
#   ENV_FILE=/path/to/.env bash open-logs.sh
#   PORT=2222 bash open-logs.sh user@server-ip
# ==============================================================================
set -euo pipefail

TARGET="${1:-}"
PORT="${PORT:-0}"
LOCAL_PORT="${LOCAL_PORT:-9428}"
REMOTE_PORT="${REMOTE_PORT:-9428}"
ENV_FILE="${ENV_FILE:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TECHSTACK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

read_env_key() {
    local file="$1"
    shift
    local val=""
    for key in "$@"; do
        val="$(grep -E "^(export[[:space:]]+)?${key}=" "$file" 2>/dev/null | head -n1 | cut -d '=' -f2- | tr -d '\r' | sed -E 's/[[:space:]]+#.*$//' | sed -E "s/^[[:space:]]*['\"]?(.*?)['\"]?[[:space:]]*$/\1/")"
        if [ -n "$val" ]; then
            printf '%s' "$val"
            return 0
        fi
    done
    return 1
}

if [ -z "$TARGET" ]; then
    RESOLVED_ENV=""
    if [ -n "$ENV_FILE" ]; then
        if [ ! -f "$ENV_FILE" ]; then
            echo "ERROR: ENV_FILE not found: $ENV_FILE" >&2
            exit 1
        fi
        RESOLVED_ENV="$ENV_FILE"
    elif [ -f ".env" ]; then
        RESOLVED_ENV=".env"
    elif [ -f "${TECHSTACK_ROOT}/.env" ]; then
        RESOLVED_ENV="${TECHSTACK_ROOT}/.env"
    fi

    ENV_HOST="${SSH_HOST:-}"
    ENV_USER="${SSH_USER:-}"
    ENV_PORT=""

    if [ -n "$RESOLVED_ENV" ]; then
        echo "Loaded target config from: $RESOLVED_ENV"
        [ -z "$ENV_HOST" ] && ENV_HOST="$(read_env_key "$RESOLVED_ENV" SSH_HOST HOSTNAME HOST || true)"
        [ -z "$ENV_USER" ] && ENV_USER="$(read_env_key "$RESOLVED_ENV" SSH_USER USER || true)"
        ENV_PORT="$(read_env_key "$RESOLVED_ENV" SSH_PORT PORT || true)"
    fi

    if [ -n "$ENV_HOST" ]; then
        TARGET="${ENV_USER:+${ENV_USER}@}${ENV_HOST}"
    fi
    if [ "$PORT" -eq 0 ] && [[ "$ENV_PORT" =~ ^[0-9]+$ ]]; then
        PORT="$ENV_PORT"
    fi
fi

if [ -z "$TARGET" ]; then
    echo "ERROR: No target specified and no SSH_HOST/HOSTNAME found in .env." >&2
    echo "Usage: bash $0 <user@server-ip>" >&2
    exit 1
fi

UI_URL="http://localhost:${LOCAL_PORT}/select/vmui/"

open_browser() {
    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$1" >/dev/null 2>&1 &
    elif command -v open >/dev/null 2>&1; then
        open "$1" >/dev/null 2>&1 &
    else
        echo "Open manually in your browser: $1"
    fi
}

SSH_ARGS=(-N -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -L "${LOCAL_PORT}:127.0.0.1:${REMOTE_PORT}")
if [ "$PORT" -gt 0 ] 2>/dev/null; then
    SSH_ARGS+=(-p "$PORT")
fi
SSH_ARGS+=("$TARGET")

echo "Opening SSH tunnel to $TARGET (127.0.0.1:$LOCAL_PORT -> remote 127.0.0.1:$REMOTE_PORT)..."
ssh "${SSH_ARGS[@]}" &
SSH_PID=$!
trap 'kill "$SSH_PID" 2>/dev/null || true' EXIT INT TERM

for _ in $(seq 1 120); do
    if ! kill -0 "$SSH_PID" 2>/dev/null; then
        echo "ERROR: SSH tunnel exited prematurely." >&2
        exit 1
    fi
    if (echo >/dev/tcp/127.0.0.1/"$LOCAL_PORT") >/dev/null 2>&1; then
        echo "OK: Tunnel active! Opening $UI_URL"
        echo "Press Ctrl+C when done to close the tunnel."
        open_browser "$UI_URL"
        wait "$SSH_PID"
        exit 0
    fi
    sleep 0.5
done

echo "ERROR: Timed out waiting for tunnel on port $LOCAL_PORT." >&2
exit 1
