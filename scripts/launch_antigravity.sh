#!/usr/bin/env bash
# ==============================================================================
# Script Shell de Inicialização do Antigravity IDE (THE-EMPYREAN)
# ==============================================================================
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
export OLLAMA_MODELS="$ROOT_DIR/data/models/.ollama/models"
export CONTEXT_MODE_DIR="$ROOT_DIR/apps/Antigravity-Data/context-mode"
export CONTEXT_MODE_PLATFORM="antigravity"
export DO_NOT_TRACK="1"

open -n -a "$ROOT_DIR/apps/Antigravity IDE.app" \
  --env OLLAMA_MODELS="$OLLAMA_MODELS" \
  --env CONTEXT_MODE_DIR="$CONTEXT_MODE_DIR" \
  --env CONTEXT_MODE_PLATFORM="antigravity" \
  --env DO_NOT_TRACK="1" \
  --args \
  --user-data-dir="$ROOT_DIR/apps/Antigravity-Data/user-data" \
  --extensions-dir="$ROOT_DIR/apps/Antigravity-Data/extensions" \
  "$ROOT_DIR" \
  "$@"
