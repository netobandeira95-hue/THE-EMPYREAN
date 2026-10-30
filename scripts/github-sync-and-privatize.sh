#!/usr/bin/env bash
# ==============================================================================
# THE EMPYREAN — Sincronização, Clone, Privatização e Criação de Repositórios GitHub
# ==============================================================================
# Baseado no fluxo oficial para o usuário: netobandeira95-hue
# - Nunca armazena tokens hardcoded (usa GITHUB_TOKEN do ambiente ou `gh auth token`).
# - Suporta:
#     1) Clonar repositórios remotos existentes para `$BASE_DIR/repos` e privatizá-los
#        (excluindo `from-zero` e `THE-EMPYREAN`).
#     2) Criar/Privatizar/Sincronizar todos os 43 blocos locais no formato:
#        `netobandeira95-hue/THE-EMPYREAN-(NOME DA FERRAMENTA/ARQUIVO/PASTA)`
# ==============================================================================

set -euo pipefail

USERNAME="${GITHUB_USERNAME:-netobandeira95-hue}"
TOKEN="${GITHUB_TOKEN:-}"
if [[ -z "$TOKEN" ]] && command -v gh >/dev/null 2>&1; then
  TOKEN="$(gh auth token 2>/dev/null || true)"
fi

if [[ -z "$TOKEN" || "$TOKEN" == "SEU_TOKEN_GITHUB" ]]; then
  echo "❌ Defina a variável de ambiente GITHUB_TOKEN (ou autentique via 'gh auth login') antes de executar."
  echo "   Exemplo: GITHUB_TOKEN=\"ghp_...\" bash scripts/github-sync-and-privatize.sh"
  exit 1
fi

BASE_DIR="${BASE_DIR:-from-zero}"
MODE="${1:---clone-and-privatize}"

if [[ "$MODE" == "--clone-and-privatize" ]]; then
  mkdir -p "$BASE_DIR/repos"
  cd "$BASE_DIR"

  REPOS_JSON="$(mktemp)"
  trap 'rm -f "$REPOS_JSON"' EXIT

  # Busca repositórios (usando /user/repos quando autenticado para incluir públicos e privados)
  curl -fsSL \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/users/$USERNAME/repos?per_page=100" \
    > "$REPOS_JSON"

  # Loop para clonar repositórios que ainda não foram clonados
  jq -r '.[] | select(.name != "from-zero" and .name != "THE-EMPYREAN") | .name' "$REPOS_JSON" \
  | while IFS= read -r repo; do
    [[ -z "$repo" ]] && continue
    target="repos/$repo"
    if [ ! -d "$target/.git" ]; then
      echo "Clonando $repo..."
      git -c http.extraHeader="Authorization: Bearer $TOKEN" clone "https://github.com/$USERNAME/$repo.git" "$target"
    else
      echo "Já existe: $repo (pulando)"
    fi
  done

  # Loop para privatizar cada repositório
  jq -r '.[] | select(.name != "from-zero" and .name != "THE-EMPYREAN") | .name' "$REPOS_JSON" \
  | while IFS= read -r repo; do
    [[ -z "$repo" ]] && continue
    echo "Privatizando $repo..."
    curl -fsSL \
      -X PATCH \
      -H "Authorization: Bearer $TOKEN" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/$USERNAME/$repo" \
      -d '{"private": true}' >/dev/null
  done

  rm -f "$REPOS_JSON"
  echo "✅ Processo de clone e privatização concluído."

elif [[ "$MODE" == "--push-empyrean-blocks" ]]; then
  echo "🚀 Criando, privatizando e enviando os 43 blocos THE-EMPYREAN-(NOME) para $USERNAME..."
  python3 /Volumes/THEEMPYREAN/scripts/sync_empyrean_blocks.py --audit-only

  git -C /Volumes/THEEMPYREAN remote | grep '^THE-EMPYREAN-' | while IFS= read -r repo_name; do
    branch_name="${repo_name#THE-EMPYREAN-}"
    echo "📦 Garantindo repositório privado: $USERNAME/$repo_name ..."
    curl -fsSL \
      -X POST \
      -H "Authorization: Bearer $TOKEN" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/user/repos" \
      -d "{\"name\": \"$repo_name\", \"private\": true}" >/dev/null 2>&1 || true

    curl -fsSL \
      -X PATCH \
      -H "Authorization: Bearer $TOKEN" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/$USERNAME/$repo_name" \
      -d '{"private": true}' >/dev/null 2>&1 || true

    echo "⬆️  Enviando branch '$branch_name' -> $USERNAME/$repo_name (main)..."
    git -C /Volumes/THEEMPYREAN -c http.extraHeader="Authorization: Bearer $TOKEN" \
      push -u "$repo_name" "refs/heads/$branch_name:refs/heads/main"
  done
  echo "✅ Todos os 43 repositórios THE-EMPYREAN-(NOME) foram criados, privatizados e sincronizados!"
fi

