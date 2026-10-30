#!/usr/bin/env bash
# ==============================================================================
# THE EMPYREAN — Automação de Conformidade, Auditoria Zero-Leak, Branches e Repos
# ==============================================================================
# Regra Oficial:
# 1. Organizar os commits em blocos por (NOME DA FERRAMENTA/ARQUIVO/PASTA)
#    derivados de `main` como branches no repositório raiz.
# 2. Cada bloco possui seu próprio `.git` independente, `.gitignore` sincronizado,
#    hook `pre-commit` instalado e remote apontando para:
#    https://github.com/netobandeira95-hue/THE-EMPYREAN-(NOME).git
# 3. Sempre executar auditoria Zero-Leak antes de qualquer commit (excluindo tudo
#    do `.gitignore` e revisando/adicionando novos termos sensíveis ao
#    `config/pii-blocklist.txt`).
#
# Uso:
#   bash scripts/sync-empyrean-repos.sh [--audit-only | --sync-local | --create-github-repos]
# ==============================================================================

set -euo pipefail

EMPYREAN_ROOT="/Volumes/THEEMPYREAN"
GITHUB_OWNER="netobandeira95-hue"
REPO_PREFIX="THE-EMPYREAN-"
MODE="${1:---sync-local}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🛡️  [THE-EMPYREAN] Iniciando Automação de Conformidade & Repositórios (${MODE})...${NC}"

# 1. Instalar/Atualizar Hooks em todo o ecossistema
bash "$EMPYREAN_ROOT/scripts/hooks/install.sh"

# 2. Executar motor Python de auditoria, sincronização de branches (a partir de main)
#    e inicialização de repositórios `.git` por bloco
python3 "$EMPYREAN_ROOT/scripts/sync_empyrean_blocks.py" "$MODE"

echo -e "${GREEN}✅ [THE-EMPYREAN] Operação concluída com sucesso!${NC}"

