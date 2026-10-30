#!/usr/bin/env bash
# ==============================================================================
# Iniciar Antigravity IDE (THE-EMPYREAN)
# ==============================================================================
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "--------------------------------------------------------"
echo "  🚀 Antigravity IDE - Ecossistema THE-EMPYREAN"
echo "  Diretório Base: $ROOT_DIR"
echo "--------------------------------------------------------"

export OLLAMA_MODELS="$ROOT_DIR/data/models/.ollama/models"
export CONTEXT_MODE_DIR="$ROOT_DIR/apps/Antigravity-Data/context-mode"
export CONTEXT_MODE_PLATFORM="antigravity"
export DO_NOT_TRACK="1"

if ! curl -s http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    echo "⚠️  Ollama não está ativo. Iniciando serviço local..."
    if command -v ollama >/dev/null 2>&1; then
        nohup ollama serve >/dev/null 2>&1 &
        sleep 2
        echo "✅ Ollama iniciado com sucesso (Modelos em: $OLLAMA_MODELS)!"
    else
        echo "⚠️  Binário 'ollama' não encontrado no PATH do sistema. Pule se não for usar localmente."
    fi
else
    echo "✅ Ollama já está em execução (Modelos em: $OLLAMA_MODELS)."
fi

echo "🖥️  Inicializando o Antigravity IDE com dados e extensões de THE-EMPYREAN..."
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

echo "✨ Antigravity IDE aberto com sucesso!"
exit 0
