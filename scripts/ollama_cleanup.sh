#!/bin/bash
# ==============================================================================
# Higienização, Unificação e Garbage Collection de Blobs do Ollama
# Diretriz: Manter apenas Pesos Oficiais (Stock Weights) em /Volumes/THEEMPYREAN
# ==============================================================================
set -e

echo "=== INICIANDO HIGIENIZAÇÃO E UNIFICAÇÃO DE MODELOS OLLAMA ==="

INTERNAL_DIR="$HOME/.ollama/models"
EXTERNAL_DIR="/Volumes/THEEMPYREAN/data/models/.ollama/models"

if [ ! -d "$EXTERNAL_DIR" ]; then
    echo "❌ Erro: Volume externo não encontrado em $EXTERNAL_DIR"
    exit 1
fi

echo "🛑 Parando o serviço Ollama..."
osascript -e 'quit app "Ollama"' 2>/dev/null || true
killall Ollama 2>/dev/null || true
killall ollama 2>/dev/null || true
sleep 2

if [ -d "$INTERNAL_DIR" ] && [ ! -L "$INTERNAL_DIR" ]; then
    echo "🔄 Sincronizando blobs novos antes de remover diretório interno..."
    rsync -a --ignore-existing "$INTERNAL_DIR/" "$EXTERNAL_DIR/"
    echo "🧹 Removendo diretório interno duplicado (~30.8 GB)..."
    rm -rf "$INTERNAL_DIR"
fi

if [ ! -L "$INTERNAL_DIR" ]; then
    mkdir -p "$(dirname "$INTERNAL_DIR")"
    echo "🔗 Criando link simbólico de ~/.ollama/models para o volume externo..."
    ln -s "$EXTERNAL_DIR" "$INTERNAL_DIR"
fi

echo "🗑️ Removendo modelos obsoletos, redundantes e fine-tunes de terceiros..."
OBSOLETE_MODELS=(
    "codellama"
    "starcoder2"
    "deepseek-coder-v2"
    "llava"
    "phi3.5"
    "mistral"
    "deepscaler"
    "smollm2"
    "mxbai-embed-large"
    "all-minilm"
)

for model in "${OBSOLETE_MODELS[@]}"; do
    rm -rf "$EXTERNAL_DIR/manifests/registry.ollama.ai/library/$model"
done

echo "🧽 Executando Garbage Collection de blobs órfãos em $EXTERNAL_DIR/blobs..."
if [ -d "$EXTERNAL_DIR/blobs" ] && [ -d "$EXTERNAL_DIR/manifests" ]; then
    USED_BLOBS=$(grep -rhoE 'sha256:[a-f0-9]{64}' "$EXTERNAL_DIR/manifests" 2>/dev/null | tr ':' '-' | sort -u || true)
    ORPHAN_COUNT=0
    for blob_path in "$EXTERNAL_DIR/blobs"/sha256-*; do
        [ -e "$blob_path" ] || continue
        blob_name=$(basename "$blob_path")
        if ! echo "$USED_BLOBS" | grep -qx "$blob_name"; then
            rm -f "$blob_path"
            ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
        fi
    done
    echo "✨ Blobs órfãos eliminados: $ORPHAN_COUNT"
fi

launchctl setenv OLLAMA_MODELS "$EXTERNAL_DIR" 2>/dev/null || true
echo "🚀 Reiniciando o serviço Ollama (Homebrew)..."
brew services restart ollama 2>/dev/null || nohup /opt/homebrew/bin/ollama serve >/dev/null 2>&1 &
echo "✅ Limpeza e unificação concluídas com sucesso!"

