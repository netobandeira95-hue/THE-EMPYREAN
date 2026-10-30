#!/usr/bin/env bash
# ==============================================================================
# Limpar Macbook (MacClean) — Launcher Gráfico do Finder
# ==============================================================================

DIR="$(cd "$(dirname "$0")" && pwd)"
MAC_CLEAN="${DIR}/mac-clean.sh"

clear
"$MAC_CLEAN" scan

echo ""
echo "Escolha uma ação:"
echo "  [1] Mover arquivos seguros (SAFE) para a Lixeira"
echo "  [2] Mover arquivos seguros + caches de desenvolvedor (SAFE + DEV) para a Lixeira"
echo "  [3] Executar manutenção do sistema (Liberar DNS, APFS e Homebrew)"
echo "  [4] Listar os primeiros 50 arquivos catalogados"
echo "  [5] Sair sem modificar nada"
echo ""
read -p "Opção [1-5]: " opcao

case "$opcao" in
    1)
        "$MAC_CLEAN" clean --tier SAFE
        ;;
    2)
        "$MAC_CLEAN" clean
        ;;
    3)
        "$MAC_CLEAN" maintenance
        ;;
    4)
        "$MAC_CLEAN" list --limit 50
        ;;
    *)
        echo "Nenhuma alteração realizada."
        ;;
esac

echo ""
read -n 1 -s -r -p "Pressione qualquer tecla para fechar esta janela..."
echo ""
