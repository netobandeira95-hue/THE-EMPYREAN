#!/usr/bin/env bash
# ==============================================================================
# Context Mode Launcher (THE-EMPYREAN)
# ==============================================================================
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLI_MJS="$ROOT_DIR/packages/context-mode/cli.bundle.mjs"

if [ ! -f "$CLI_MJS" ]; then
    echo "❌ Context Mode não encontrado em $CLI_MJS."
    exit 1
fi

export CONTEXT_MODE_PLATFORM="${CONTEXT_MODE_PLATFORM:-antigravity}"
export CONTEXT_MODE_DIR="${CONTEXT_MODE_DIR:-$ROOT_DIR/apps/Antigravity-Data/context-mode}"
export DO_NOT_TRACK=1
export CONTEXT_MODE_TELEMETRY=0

exec node "$CLI_MJS" "$@"
