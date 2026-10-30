#!/bin/bash
# ==============================================================================
# Script de Gerenciamento e Inicialização vLLM (Local - /Volumes/THEEMPYREAN)
# Diretriz: Pesos Oficiais Puros (Stock Weights) + Offload Parcial Estruturado
# ==============================================================================

MODEL_DIR="/Volumes/THEEMPYREAN/data/models/vllm_models"
LOG_FILE="/Volumes/THEEMPYREAN/data/models/vllm_server.log"
PORT=8000

export HF_HOME="$MODEL_DIR"

validate_official_model() {
    local MODEL="$1"
    case "$MODEL" in
        "gpt-oss-20b"|"openai/gpt-oss-20b"|"Qwen/Qwen3.6"|"qwen-3.6"|"google/gemma-4"|"gemma-4"|"THUDM/glm-5"|"glm-5"|"openai/gpt-oss-safeguard-20b"|"gpt-oss-safeguard-20b")
            return 0
            ;;
        *)
            echo "❌ BLOQUEADO: O modelo '$MODEL' não faz parte dos pesos oficiais (Stock Weights) permitidos."
            echo "   Permitidos: openai/gpt-oss-20b, Qwen/Qwen3.6, google/gemma-4, THUDM/glm-5, openai/gpt-oss-safeguard-20b"
            exit 1
            ;;
    esac
}

stop_vllm() {
    echo "🔍 Verificando instâncias ativas do vLLM na porta $PORT..."
    PID=$(lsof -t -i:$PORT)
    if [ -n "$PID" ]; then
        echo "🛑 Parando processo vLLM (PID: $PID)... Descarregando da VRAM/RAM..."
        kill -15 $PID 2>/dev/null
        sleep 3
        if kill -0 $PID 2>/dev/null; then
            echo "⚠️ Forçando liberação imediata de memória (SIGKILL)..."
            kill -9 $PID 2>/dev/null
        fi
        sleep 1
        echo "✅ Modelo anterior descarregado da memória."
    else
        echo "✨ Nenhuma instância ativa encontrada."
    fi
}

start_vllm() {
    local MODEL_NAME=$1
    local MAX_MODEL_LEN=${2:-4096}
    local GPU_MEMORY_UTILIZATION=${3:-0.85}
    local CPU_OFFLOAD_GB=${4:-4}

    if [ -z "$MODEL_NAME" ]; then
        echo "❌ Erro: Informe o modelo oficial a ser carregado."
        exit 1
    fi

    validate_official_model "$MODEL_NAME"

    if command -v ollama >/dev/null 2>&1; then
        for active_ollama in $(ollama ps 2>/dev/null | awk 'NR>1 {print $1}'); do
            echo "🔄 Descarregando '$active_ollama' do Ollama para liberar memória..."
            ollama stop "$active_ollama" 2>/dev/null || true
        done
    fi

    stop_vllm
    mkdir -p "$MODEL_DIR"

    local MODEL_TARGET="$MODEL_NAME"
    if [ -d "$MODEL_DIR/$MODEL_NAME" ]; then
        MODEL_TARGET="$MODEL_DIR/$MODEL_NAME"
    fi

    echo "🚀 Carregando modelo oficial (Stock Weights): $MODEL_TARGET"
    echo "⚙️ Configuração: Max Len=$MAX_MODEL_LEN | GPU Util=$GPU_MEMORY_UTILIZATION | CPU Offload=$CPU_OFFLOAD_GB GB"

    nohup vllm serve "$MODEL_TARGET" \
        --download-dir "$MODEL_DIR" \
        --port "$PORT" \
        --max-model-len "$MAX_MODEL_LEN" \
        --gpu-memory-utilization "$GPU_MEMORY_UTILIZATION" \
        --cpu-offload-gb "$CPU_OFFLOAD_GB" \
        --trust-remote-code \
        > "$LOG_FILE" 2>&1 &

    echo "✅ vLLM iniciado em background (PID: $!). Endpoint: http://localhost:$PORT/v1"
}

case "$1" in
    start)
        start_vllm "$2" "$3" "$4" "$5"
        ;;
    stop)
        stop_vllm
        ;;
    logs)
        tail -f "$LOG_FILE"
        ;;
    *)
        echo "Uso: $0 {start [modelo_oficial] [max_len] [gpu_util] [cpu_offload] | stop | logs}"
        exit 1
        ;;
esac

