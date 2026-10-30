#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# ==============================================================================
# SCRIPT DE DOWNLOAD E GERENCIAMENTO DE MODELOS OLLAMA NO HD EXTERNO (IA-INFRA)
# ==============================================================================

# 1. Definir o diretório de armazenamento no HD Externo
export OLLAMA_MODELS="/Volumes/THEEMPYREAN/data/models/.ollama/models"
mkdir -p "$OLLAMA_MODELS"

# Cria links simbólicos amigáveis para 'ollamamodels' e 'models'
ln -sfn "$OLLAMA_MODELS" "/Volumes/THEEMPYREAN/data/models/ollama-models"
ln -sfn "$OLLAMA_MODELS" "/Volumes/THEEMPYREAN/data/models/ollama-models"

echo "========================================================================"
echo "📍 DESTINO DOS MODELOS: $OLLAMA_MODELS"
echo "========================================================================"

# 2. Verificar se o servidor Ollama está respondendo; se não, inicializar em background
echo "Verificando se o serviço Ollama está ativo..."
if ! curl -s http://127.0.0.1:11434/api/version >/dev/null 2>&1; then
    echo "⚠️ Ollama não está rodando. Iniciando 'ollama serve' apontando para o HD externo..."
    # Mata processos antigos travados se houver
    pkill -f "ollama serve" 2>/dev/null || true
    
    # Inicia o servidor com o caminho correto do HD Externo em background
    OLLAMA_MODELS="$OLLAMA_MODELS" ollama serve > /tmp/ollama_ia_infra.log 2>&1 &
    OLLAMA_PID=$!
    
    # Aguarda o servidor subir (até 15 segundos)
    for i in {1..15}; do
        if curl -s http://127.0.0.1:11434/api/version >/dev/null 2>&1; then
            echo "✅ Servidor Ollama iniciado com sucesso (PID $OLLAMA_PID)!"
            break
        fi
        sleep 1
    done
fi

if ! curl -s http://127.0.0.1:11434/api/version >/dev/null 2>&1; then
    echo "❌ Falha ao iniciar o Ollama. Verifique o log em /tmp/ollama_ia_infra.log"
    exit 1
fi

# 3. Lista Completa de Modelos (Armazenados no HD Externo IA-INFRA)
MODELS=(
    # 🛠️ Agentes, Chamada de Funções & Tool Calling
    "hermes3:8b"
    "llama3.1:8b"
    "gemma2:9b"

    # 👁️ Visão & Multimodal
    "llama3.2-vision:11b"
    "minicpm-v"
    "llava:7b"

    # 🔍 Embeddings & RAG Vetorial
    "nomic-embed-text"
    "bge-m3"
    "mxbai-embed-large"

    # 🧠 Raciocínio (Reasoning & Deep Think)
    "phi4:14b"
    "phi3.5:3.8b"
    "deepseek-r1:1.5b"
    "deepseek-r1:8b"
    "deepseek-r1:14b"

    # 💻 Especializados em Código (Coding)
    "deepseek-coder-v2:16b"
    "codellama:7b"
    "starcoder2:7b"
    "qwen2.5-coder:1.5b"
    "qwen2.5-coder:7b"

    # ⚡ Modelos Leves & Uso Geral (SLMs)
    "llama3.2:1b"
    "llama3.2:3b"
    "gemma2:2b"
    "qwen2.5:0.5b"
    "mistral:7b"
)

echo ""
echo "Iniciando verificação e download dos modelos..."
echo ""

for model in "${MODELS[@]}"; do
    echo "------------------------------------------------------------------------"
    echo "📥 Baixando / Atualizando: $model"
    echo "------------------------------------------------------------------------"
    ollama pull "$model"
    if [ $? -eq 0 ]; then
        echo "✅ Modelo $model concluído no HD externo!"
    else
        echo "⚠️ Erro ao baixar $model. Verifique a conexão com a internet."
    fi
    echo ""
done

echo "========================================================================"
echo "🔍 VERIFICAÇÃO DE INTEGRIDADE E ESPAÇO UTILIZADO NO HD EXTERNO"
echo "========================================================================"
echo ""
echo "📁 Espaço ocupado na pasta de modelos do HD Externo ($OLLAMA_MODELS):"
du -sh "$OLLAMA_MODELS"
du -sh "$OLLAMA_MODELS"/blobs 2>/dev/null || true

echo ""
echo "📋 Lista de Modelos Registrados no Ollama:"
ollama list

echo ""
echo "========================================================================"
echo "✅ Todos os downloads foram finalizados no HD Externo!"
echo "========================================================================"
