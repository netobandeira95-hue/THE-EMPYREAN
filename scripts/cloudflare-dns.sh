#!/usr/bin/env bash
# Cloudflare DNS Zone Manager
# Covers: add zone, set DNS records, configure settings, check zone status
#
# Usage:
#   export CF_API_TOKEN=<token with Zone:Edit + DNS:Edit + Zone Settings:Write>
#   bash cloudflare-dns.sh <command> [args...]
#
# Commands:
#   zone-add    <domain>                         Add domain to Cloudflare DNS
#   zone-status <domain|zone_id>                 Check zone status
#   dns-add     <zone_id> <type> <name> <value>  Add/update DNS record
#   dns-list    <zone_id>                        List all DNS records
#   dns-del     <zone_id> <record_id>            Delete a DNS record
#   settings    <zone_id>                        Show current SSL, cache, security settings
#   ssl         <zone_id> <mode>                 Set SSL mode: off|flexible|full|full_strict
#   cache       <zone_id> <level>                Set cache level: bypass|basic|simplified|aggressive|cache_everything
#   security    <zone_id> <level>                Set security level: off|essentially_off|low|medium|high|under_attack
#
# Required token permissions:
#   Zone > Zone > Edit
#   Zone > DNS > Edit
#   Zone > Zone Settings > Write

set -euo pipefail

ACCOUNT_ID="${CF_ACCOUNT_ID}"
API="https://api.cloudflare.com/client/v4"

# ── helpers ──────────────────────────────────────────────────────────────────

check_token() {
  if [[ -z "${CF_API_TOKEN:-}" ]]; then
    echo "Error: CF_API_TOKEN is not set."
    echo "  export CF_API_TOKEN=<your token>"
    echo "  Create one at: https://dash.cloudflare.com/profile/api-tokens"
    echo "  Required permissions: Zone:Edit, DNS:Edit, Zone Settings:Write"
    exit 1
  fi
}

cf() {
  local method="$1"; shift
  local path="$1"; shift
  curl -s --request "$method" \
    "${API}${path}" \
    --header "Authorization: Bearer $CF_API_TOKEN" \
    --header "Content-Type: application/json" \
    "$@"
}

jq_or_raw() {
  if command -v jq &>/dev/null; then
    jq '.'
  else
    cat
  fi
}

zone_id_from_name() {
  local domain="$1"
  cf GET "/zones?name=${domain}&account.id=${ACCOUNT_ID}" \
    | jq -r '.result[0].id // empty'
}

require_zone_id() {
  local arg="$1"
  # if it looks like a zone_id (hex 32 chars), use as-is; otherwise resolve
  if [[ "$arg" =~ ^[a-f0-9]{32}$ ]]; then
    echo "$arg"
  else
    local zid
    zid=$(zone_id_from_name "$arg")
    if [[ -z "$zid" ]]; then
      echo "Error: zone not found for domain '$arg'" >&2
      exit 1
    fi
    echo "$zid"
  fi
}

# ── commands ──────────────────────────────────────────────────────────────────

cmd_zone_add() {
  local domain="${1:?Usage: zone-add <domain>}"
  check_token
  echo "→ Adding zone: $domain"
  cf POST "/zones" \
    --data "{\"name\":\"${domain}\",\"account\":{\"id\":\"${ACCOUNT_ID}\"}}" \
    | jq_or_raw
  echo ""
  echo "Next: update your domain's nameservers at your registrar to the"
  echo "Cloudflare nameservers shown in 'name_servers' above."
}

cmd_zone_status() {
  local arg="${1:?Usage: zone-status <domain|zone_id>}"
  check_token
  local zid; zid=$(require_zone_id "$arg")
  echo "→ Zone status for: $arg (id: $zid)"
  cf GET "/zones/${zid}" | jq '{
    name: .result.name,
    status: .result.status,
    plan: .result.plan.name,
    nameservers: .result.name_servers,
    paused: .result.paused,
    created: .result.created_on
  }'
}

cmd_dns_list() {
  local arg="${1:?Usage: dns-list <domain|zone_id>}"
  check_token
  local zid; zid=$(require_zone_id "$arg")
  echo "→ DNS records for zone: $zid"
  cf GET "/zones/${zid}/dns_records?per_page=100" \
    | jq '[.result[] | {id, type, name, content, proxied, ttl}]'
}

cmd_dns_add() {
  local arg="${1:?Usage: dns-add <domain|zone_id> <type> <name> <value> [proxied=false]}"
  local type="${2:?Missing record type (A, AAAA, CNAME, MX, TXT, ...)}"
  local name="${3:?Missing record name}"
  local value="${4:?Missing record value}"
  local proxied="${5:-false}"
  check_token
  local zid; zid=$(require_zone_id "$arg")
  echo "→ Adding $type record: $name → $value (proxied=$proxied)"
  cf POST "/zones/${zid}/dns_records" \
    --data "{\"type\":\"${type}\",\"name\":\"${name}\",\"content\":\"${value}\",\"proxied\":${proxied},\"ttl\":1}" \
    | jq '{id: .result.id, type: .result.type, name: .result.name, content: .result.content, proxied: .result.proxied}'
}

cmd_dns_del() {
  local arg="${1:?Usage: dns-del <domain|zone_id> <record_id>}"
  local record_id="${2:?Missing record_id (get it from dns-list)}"
  check_token
  local zid; zid=$(require_zone_id "$arg")
  echo "→ Deleting record $record_id from zone $zid"
  cf DELETE "/zones/${zid}/dns_records/${record_id}" | jq '.'
}

cmd_settings() {
  local arg="${1:?Usage: settings <domain|zone_id>}"
  check_token
  local zid; zid=$(require_zone_id "$arg")
  echo "→ Settings for zone: $zid"
  cf GET "/zones/${zid}/settings" \
    | jq '[.result[] | select(.id | test("ssl|cache_level|security_level|always_use_https|min_tls_version|http3|brotli")) | {id, value}]'
}

cmd_ssl() {
  local arg="${1:?Usage: ssl <domain|zone_id> <mode>}"
  local mode="${2:?Modes: off | flexible | full | full_strict}"
  check_token
  local zid; zid=$(require_zone_id "$arg")
  echo "→ Setting SSL mode to '$mode' on zone $zid"
  cf PATCH "/zones/${zid}/settings/ssl" \
    --data "{\"value\":\"${mode}\"}" \
    | jq '{id: .result.id, value: .result.value}'
}

cmd_cache() {
  local arg="${1:?Usage: cache <domain|zone_id> <level>}"
  local level="${2:?Levels: bypass | basic | simplified | aggressive | cache_everything}"
  check_token
  local zid; zid=$(require_zone_id "$arg")
  echo "→ Setting cache level to '$level' on zone $zid"
  cf PATCH "/zones/${zid}/settings/cache_level" \
    --data "{\"value\":\"${level}\"}" \
    | jq '{id: .result.id, value: .result.value}'
}

cmd_security() {
  local arg="${1:?Usage: security <domain|zone_id> <level>}"
  local level="${2:?Levels: off | essentially_off | low | medium | high | under_attack}"
  check_token
  local zid; zid=$(require_zone_id "$arg")
  echo "→ Setting security level to '$level' on zone $zid"
  cf PATCH "/zones/${zid}/settings/security_level" \
    --data "{\"value\":\"${level}\"}" \
    | jq '{id: .result.id, value: .result.value}'
}

usage() {
  grep '^#   ' "$0" | sed 's/^#   /  /'
  exit 0
}

# ── dispatch ──────────────────────────────────────────────────────────────────

CMD="${1:-help}"
shift || true

case "$CMD" in
  zone-add)    cmd_zone_add    "$@" ;;
  zone-status) cmd_zone_status "$@" ;;
  dns-add)     cmd_dns_add     "$@" ;;
  dns-list)    cmd_dns_list    "$@" ;;
  dns-del)     cmd_dns_del     "$@" ;;
  settings)    cmd_settings    "$@" ;;
  ssl)         cmd_ssl         "$@" ;;
  cache)       cmd_cache       "$@" ;;
  security)    cmd_security    "$@" ;;
  help|--help|-h) usage ;;
  *) echo "Unknown command: $CMD"; usage ;;
esac
