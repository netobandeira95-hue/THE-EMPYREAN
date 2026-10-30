#!/usr/bin/env bash
# ==============================================================================
# Iniciar Ecossistema THE-EMPYREAN Completo (IDE + Ollama + Project NOMAD)
# ==============================================================================
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

clear
echo "===================================================================="
echo "    🚀 ECOSSISTEMA COMPLETO THE-EMPYREAN"
echo "    Diretório Base: $ROOT_DIR"
echo "===================================================================="
echo ""

export OLLAMA_MODELS="$ROOT_DIR/data/models/.ollama/models"

if ! curl -s http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    echo "🤖 [1/4] Iniciando Ollama local com modelos do HD..."
    if command -v ollama >/dev/null 2>&1; then
        nohup ollama serve >/dev/null 2>&1 &
        sleep 2
        echo "   ✅ Ollama pronto (Modelos em: $OLLAMA_MODELS)"
    else
        echo "   ⚠️ Binário ollama não encontrado no PATH."
    fi
else
    echo "🤖 [1/4] Ollama já está em execução (Modelos em: $OLLAMA_MODELS)."
fi

if ! curl -s http://127.0.0.1:11435/api/status >/dev/null 2>&1; then
    echo "⚡ [2/4] Iniciando Model Pause REST API..."
    if [ -f "$ROOT_DIR/services/model-pause-api/server.mjs" ]; then
        nohup node "$ROOT_DIR/services/model-pause-api/server.mjs" </dev/null >>/tmp/model-pause-api.log 2>&1 & disown
        sleep 1
        echo "   ✅ Model Pause REST API ativa em http://127.0.0.1:11435"
    fi
else
    echo "⚡ [2/4] Model Pause REST API já está em execução (http://127.0.0.1:11435)."
fi

echo ""
echo "📦 [3/4] Verificando Docker e iniciando Project NOMAD..."
if ! docker info >/dev/null 2>&1; then
    if command -v colima >/dev/null 2>&1; then
        echo "   🚀 Subindo Colima..."
        colima start
    fi
fi

if docker info >/dev/null 2>&1; then
    cd "$ROOT_DIR/services/project-nomad" || exit 1
    docker compose -p project-nomad -f "$ROOT_DIR/services/project-nomad/compose.yml" --env-file "$ROOT_DIR/services/project-nomad/.env" up -d
    echo "   ✅ Project NOMAD ativo em http://localhost:8085"
else
    echo "   ⚠️ Docker não disponível no momento. NOMAD não foi iniciado."
fi

echo ""
echo "🖥️  [4/4] Abrindo Antigravity IDE com dados, extensões e workspace de THE-EMPYREAN..."
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
  "$ROOT_DIR"

echo ""
echo "===================================================================="
echo "✨ Ecossistema THE-EMPYREAN inicializado com sucesso!"
echo "===================================================================="
exit 0
