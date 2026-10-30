#!/usr/bin/env bash
# ==============================================================================
# Qwen Local Runner & Delegation CLI (IA-INFRA)
# Preserva a cota do Gemini executando código e raciocínio localmente no Ollama.
# ==============================================================================

set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
export OLLAMA_HOST="${OLLAMA_HOST:-http://127.0.0.1:11434}"
DEFAULT_MODEL="qwen2.5-coder:7b"
MODEL="$DEFAULT_MODEL"

usage() {
    echo "Uso: $0 [opções] \"seu prompt ou código\""
    echo ""
    echo "Opções:"
    echo "  -m, --model <nome>    Especifica o modelo (Padrão: $DEFAULT_MODEL)"
    echo "                        Ex: qwen2.5-coder:1.5b, qwen2.5:0.5b"
    echo "  -s, --status          Exibe o status do Ollama e modelos na memória"
    echo "  -l, --list            Lista modelos Qwen disponíveis no volume"
    echo "  -h, --help            Exibe esta ajuda"
    echo ""
    echo "Exemplos:"
    echo "  $0 \"Escreva uma função Python para calcular fibonacci com memoização\""
    echo "  $0 -m qwen2.5-coder:1.5b \"Explique este erro: ...\""
    echo "  cat script.py | $0 \"Refatore este código para boas práticas\""
    exit 0
}

PROMPT=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--model)
            MODEL="$2"
            shift 2
            ;;
        -s|--status)
            echo "=== Status do Ollama (127.0.0.1:11434) ==="
            ollama ps
            echo ""
            echo "=== Uso de Memória do Sistema ==="
            sysctl vm.swapusage
            exit 0
            ;;
        -l|--list)
            ollama list | grep -E "qwen|deepseek"
            exit 0
            ;;
        -h|--help)
            usage
            ;;
        *)
            if [ -z "$PROMPT" ]; then
                PROMPT="$1"
            else
                PROMPT="$PROMPT $1"
            fi
            shift
            ;;
    esac
done

if [ -z "$PROMPT" ] && [ ! -t 0 ]; then
    PROMPT="$(cat)"
fi

if [ -z "$PROMPT" ]; then
    echo "Erro: Nenhum prompt informado." >&2
    usage
fi

exec "$DIR/cli-anything-ollama.sh" generate text -m "$MODEL" -p "$PROMPT"
