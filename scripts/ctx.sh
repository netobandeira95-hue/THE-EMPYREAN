#!/usr/bin/env bash
# ==============================================================================
# ctx - Atalho rápido para o Context Mode (IA-INFRA Portátil)
# ==============================================================================
DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$DIR/context-mode.sh" "$@"
