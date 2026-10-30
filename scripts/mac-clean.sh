#!/usr/bin/env bash
# ==============================================================================
# MacClean — Atalho de Linha de Comando para THE-EMPYREAN
# ==============================================================================

set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_EXEC="/usr/bin/python3"

if [ -f "/opt/homebrew/bin/python3" ]; then
    PYTHON_EXEC="/opt/homebrew/bin/python3"
fi

ENTRYPOINT="${ROOT_DIR}/packages/mac-clean/main.py"

if [ ! -f "$ENTRYPOINT" ]; then
    echo "Erro: MacClean não encontrado em $ENTRYPOINT" >&2
    exit 1
fi

exec "$PYTHON_EXEC" "$ENTRYPOINT" "$@"
