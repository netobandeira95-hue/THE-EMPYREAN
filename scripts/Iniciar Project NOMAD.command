#!/bin/bash
# Script de Inicialização Rápida do Project NOMAD no macOS (THE-EMPYREAN)

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$ROOT_DIR/services/project-nomad"

clear
echo "=========================================================="
echo "      PROJECT NOMAD - Offline Knowledge Server            "
echo "      Infraestrutura Portátil em $ROOT_DIR                "
echo "=========================================================="
echo ""

if ! docker info >/dev/null 2>&1; then
    echo "⚠️  Docker/Colima não está em execução."
    if command -v colima >/dev/null 2>&1; then
        echo "🚀 Iniciando Colima..."
        colima start
    else
        echo "❌ Docker/Colima não encontrado. Por favor, inicialize seu ambiente Docker."
        read -p "Pressione [Enter] para sair..."
        exit 1
    fi
fi

echo "🚀 Iniciando containers do Project NOMAD..."
cd "$DIR" || exit 1
docker compose -p project-nomad -f "$DIR/compose.yml" --env-file "$DIR/.env" up -d

echo ""
echo "✅ Project NOMAD ativo e pronto!"
echo "🌐 Acessando Command Center em: http://localhost:8085"
echo "📋 Painel de Logs (Dozzle) em: http://localhost:9999"
echo ""

sleep 2
open "http://localhost:8085"

echo "Pressione [Enter] para fechar esta janela do Terminal..."
read -r
