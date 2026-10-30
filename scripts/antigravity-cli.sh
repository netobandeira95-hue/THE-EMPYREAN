#!/usr/bin/env bash
# ==============================================================================
# CLI do Antigravity IDE (THE-EMPYREAN)
# ==============================================================================
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
export OLLAMA_MODELS="$ROOT_DIR/data/models/.ollama/models"
unset NODE_OPTIONS
unset NODE_REPL_EXTERNAL_MODULE

"$ROOT_DIR/apps/Antigravity IDE.app/Contents/Resources/app/bin/antigravity-ide" \
  --user-data-dir="$ROOT_DIR/apps/Antigravity-Data/user-data" \
  --extensions-dir="$ROOT_DIR/apps/Antigravity-Data/extensions" \
  "$@"
