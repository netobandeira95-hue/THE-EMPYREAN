#!/usr/bin/env bash
# ==============================================================================
# THE-EMPYREAN — Instalador Global de Git Hooks (Raiz + Todos os Subprojetos)
# ==============================================================================
# Instala o hook pre-commit e sincroniza o .gitignore em:
#   1. /Volumes/THEEMPYREAN/.git/hooks/pre-commit
#   2. Todos os repositórios .git individuais de ferramentas/pastas
# ==============================================================================

set -euo pipefail

EMPYREAN_ROOT="/Volumes/THEEMPYREAN"
HOOK_SRC="$EMPYREAN_ROOT/scripts/hooks/pre-commit"
chmod +x "$HOOK_SRC"

installed=0

while IFS= read -r git_dir; do
  [[ -z "$git_dir" ]] && continue
  hooks_dst="$git_dir/hooks"
  mkdir -p "$hooks_dst"
  ln -sf "$HOOK_SRC" "$hooks_dst/pre-commit"
  installed=$(( installed + 1 ))
done < <(find "$EMPYREAN_ROOT" -maxdepth 4 -name ".git" -type d \
  -not -path "$EMPYREAN_ROOT/apps/Antigravity IDE.app*" \
  -not -path "$EMPYREAN_ROOT/apps/Antigravity-Data*" \
  -not -path "$EMPYREAN_ROOT/packages/archive*" \
  -not -path "$EMPYREAN_ROOT/packages/toolchains*" 2>/dev/null)

echo "✅ Hook pre-commit Zero-Leak instalado em $installed repositórios (.git/hooks/pre-commit)."
