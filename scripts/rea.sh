#!/usr/bin/env bash
# ==============================================================================
# REA (Reverse Engineer Anything) Launcher (THE-EMPYREAN)
# ==============================================================================
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REA_MJS="$ROOT_DIR/packages/rea/scripts/rea.mjs"

if [ ! -f "$REA_MJS" ]; then
    echo "❌ rea.mjs não encontrado em $REA_MJS."
    exit 1
fi

exec node "$REA_MJS" "$@"
