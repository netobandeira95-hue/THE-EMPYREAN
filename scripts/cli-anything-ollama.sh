#!/usr/bin/env bash
# ==============================================================================
# CLI-Anything Ollama Launcher (THE-EMPYREAN)
# ==============================================================================
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENV_BIN="$ROOT_DIR/packages/CLI-Anything/.venv/bin"

if [ ! -f "$VENV_BIN/cli-anything-ollama" ]; then
    echo "❌ cli-anything-ollama não encontrado em $VENV_BIN."
    echo "   Certifique-se de que o ambiente virtual em $ROOT_DIR/packages/CLI-Anything/.venv está configurado."
    exit 1
fi

exec "$VENV_BIN/cli-anything-ollama" "$@"
