#!/usr/bin/env bash
# ==============================================================================
# THE-EMPYREAN — Script de Manutenção e Limpeza (flush-server.sh)
# Limpa metadados AppleDouble (._*), caches temporários e recursos órfãos Docker
# ==============================================================================
set -euo pipefail

EMPYREAN_ROOT="/Volumes/THEEMPYREAN"

echo "🧹 [1/3] Removendo arquivos AppleDouble (._*) e .DS_Store em ${EMPYREAN_ROOT}..."
dot_clean -m "${EMPYREAN_ROOT}" 2>/dev/null || true
find "${EMPYREAN_ROOT}" -name "._*" -type f -delete 2>/dev/null || true
find "${EMPYREAN_ROOT}" -name ".DS_Store" -type f -delete 2>/dev/null || true

echo "🐳 [2/3] Limpando containers parados, redes não utilizadas e imagens dangling..."
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    docker system prune -f
else
    echo "   ⚠️ Docker daemon não está ativo no momento (pulando prune)."
fi

echo "✅ [3/3] Manutenção concluída com sucesso!"
df -h "/Volumes/THEEMPYREAN"
