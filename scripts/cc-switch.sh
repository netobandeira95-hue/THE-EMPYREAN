#!/usr/bin/env bash
# ==============================================================================
# CC-Switch CLI Wrapper para Antigravity IDE (THE-EMPYREAN)
# ==============================================================================
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NODE_BIN="$(command -v node || echo "/opt/homebrew/bin/node")"

if [ ! -x "$NODE_BIN" ]; then
  if [ -x "/usr/local/bin/node" ]; then
    NODE_BIN="/usr/local/bin/node"
  fi
fi

exec "$NODE_BIN" "$ROOT_DIR/packages/cc-switch/ia-infra-mcp-gateway.mjs" "$@"
