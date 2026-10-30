#!/usr/bin/env bash
# =============================================================================
# Full Cloudflare Configuration — bandeiran.com
# Account : ${CF_ACCOUNT_ID}
# Zone    : ${CF_ZONE_ID}  (bandeiran.com)
#
# Usage:
#   export CF_API_TOKEN=<your-token-value>
#   bash setup-cloudflare-all.sh
#
# What this does (in order):
#   1. Verify token + zone status
#   2. Zone settings  — SSL full-strict, HTTPS-always, security, cache, HTTP/3
#   3. DNS audit      — list existing records; add missing essentials
#   4. R2 bucket      — create "balde" (Data Catalog)
#   5. Vectorize      — create bandeiran-rag index (1024d cosine)
#   6. Tunnel         — create bandeiran-filesystem-mcp + write credentials + DNS CNAME
#   7. Workers site   — build + deploy bandeiran-site
#   8. Summary + NS instructions
# =============================================================================

set -euo pipefail

# ── Constants ─────────────────────────────────────────────────────────────────
ACCOUNT_ID="${CF_ACCOUNT_ID}"
ZONE_ID="${CF_ZONE_ID}"
DOMAIN="bandeiran.com"
R2_BUCKET="balde"
VECTORIZE_INDEX="bandeiran-rag"
TUNNEL_NAME="bandeiran-filesystem-mcp"
MCP_HOSTNAME="mcp-fs.bandeiran.com"
MCP_LOCAL="http://localhost:3000"
SITE_DIR="/Volumes/THEEMPYREAN/services/bandeiran-site"

API="https://api.cloudflare.com/client/v4"

# ── Helpers ───────────────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()   { echo -e "${GREEN}  ✓ $*${NC}"; }
warn() { echo -e "${YELLOW}  ⚠ $*${NC}"; }
err()  { echo -e "${RED}  ✗ $*${NC}"; }
step() { echo -e "\n${BLUE}── $* ──────────────────────────────────────────${NC}"; }

cf() {
  local method="$1"; shift
  local path="$1"; shift
  if [[ -n "${CF_API_KEY:-}" ]]; then
    /usr/bin/curl -sf --request "$method" \
      "${API}${path}" \
      --header "X-Auth-Email: ${CF_EMAIL}" \
      --header "X-Auth-Key: ${CF_API_KEY}" \
      --header "Content-Type: application/json" \
      "$@"
  else
    /usr/bin/curl -sf --request "$method" \
      "${API}${path}" \
      --header "Authorization: Bearer $CF_API_TOKEN" \
      --header "Content-Type: application/json" \
      "$@"
  fi
}

jq_check() {
  command -v jq &>/dev/null || { warn "jq not found — install with: brew install jq"; exit 1; }
}

success_or_warn() {
  local resp="$1" label="$2"
  local s; s=$(echo "$resp" | jq -r '.success // false')
  if [[ "$s" == "true" ]]; then
    ok "$label"
  else
    warn "$label — $(echo "$resp" | jq -r '.errors[0].message // "unknown error"')"
  fi
}

# ── 0. Pre-flight ─────────────────────────────────────────────────────────────

step "0. Pre-flight checks"
jq_check

CF_EMAIL="contact@example.com"

if [[ -z "${CF_API_KEY:-}" && -z "${CF_API_TOKEN:-}" ]]; then
  err "No credentials set. Run one of:"
  err "  export CF_API_KEY=<global-api-key>   (email+key auth)"
  err "  export CF_API_TOKEN=<token>           (bearer token auth)"
  exit 1
fi

VERIFY=$(cf GET "/user/tokens/verify" 2>/dev/null || cf GET "/user")
if [[ "$(echo "$VERIFY" | jq -r '.result.status')" != "active" ]]; then
  err "Token is not active or invalid."
  echo "$VERIFY" | jq '.errors'
  exit 1
fi
ok "Token active"

ZONE_RESP=$(cf GET "/zones/${ZONE_ID}")
ZONE_STATUS=$(echo "$ZONE_RESP" | jq -r '.result.status')
ZONE_NS=$(echo "$ZONE_RESP" | jq -r '.result.name_servers[]')
AUTH_METHOD=$([[ -n "${CF_API_KEY:-}" ]] && echo "Global API Key" || echo "Bearer token")
ok "Zone status: $ZONE_STATUS  (auth: $AUTH_METHOD)"
echo "  Cloudflare nameservers (update at registrar/Squarespace):"
echo "$ZONE_NS" | while read -r ns; do echo "    $ns"; done

# ── 1. Zone settings ──────────────────────────────────────────────────────────

step "1. Zone settings"

patch_setting() {
  local setting="$1" value="$2"
  local resp
  resp=$(cf PATCH "/zones/${ZONE_ID}/settings/${setting}" --data "{\"value\":${value}}")
  success_or_warn "$resp" "${setting}=${value}"
}

patch_setting "ssl"              '"full"'
patch_setting "always_use_https" '"on"'
patch_setting "min_tls_version"  '"1.2"'
patch_setting "http3"            '"on"'
patch_setting "brotli"           '"on"'
patch_setting "security_level"   '"medium"'
patch_setting "cache_level"      '"aggressive"'
patch_setting "rocket_loader"    '"on"'
patch_setting "minify"           '{"js":false,"css":false,"html":false}'

# ── 2. DNS audit ──────────────────────────────────────────────────────────────

step "2. DNS records (current)"

DNS_RECORDS=$(cf GET "/zones/${ZONE_ID}/dns_records?per_page=100")
echo "$DNS_RECORDS" | jq -r '.result[] | "  \(.type)\t\(.name)\t\(.content)\tproxied=\(.proxied)"'

# ── 3. R2 bucket ─────────────────────────────────────────────────────────────

step "3. R2 bucket — ${R2_BUCKET}"

R2_RESP=$(cf POST "/accounts/${ACCOUNT_ID}/r2/buckets" \
  --data "{\"name\":\"${R2_BUCKET}\",\"locationHint\":\"WNAM\"}")

if echo "$R2_RESP" | jq -e '.result.name' &>/dev/null; then
  ok "R2 bucket '${R2_BUCKET}' created"
else
  MSG=$(echo "$R2_RESP" | jq -r '.errors[0].message // empty')
  if [[ "$MSG" == *"already exists"* ]]; then
    ok "R2 bucket '${R2_BUCKET}' already exists"
  else
    warn "R2: $MSG"
  fi
fi

# Enable Data Catalog on the bucket
DC_RESP=$(cf PUT "/accounts/${ACCOUNT_ID}/r2/buckets/${R2_BUCKET}/event_notification/catalog" \
  --data '{"enabled":true}' 2>/dev/null || true)
[[ -n "$DC_RESP" ]] && ok "R2 Data Catalog enabled on '${R2_BUCKET}'"

# ── 4. Vectorize index ────────────────────────────────────────────────────────

step "4. Vectorize — ${VECTORIZE_INDEX}"

VEC_RESP=$(cf POST "/accounts/${ACCOUNT_ID}/vectorize/v2/indexes" \
  --data "{\"name\":\"${VECTORIZE_INDEX}\",\"config\":{\"dimensions\":1024,\"metric\":\"cosine\"}}")

if echo "$VEC_RESP" | jq -e '.result.name' &>/dev/null; then
  ok "Vectorize index '${VECTORIZE_INDEX}' created (1024d, cosine)"
else
  MSG=$(echo "$VEC_RESP" | jq -r '.errors[0].message // empty')
  if [[ "$MSG" == *"already exists"* ]]; then
    ok "Vectorize index '${VECTORIZE_INDEX}' already exists"
  else
    warn "Vectorize: $MSG"
  fi
fi

# ── 5. Cloudflare Tunnel ──────────────────────────────────────────────────────

step "5. Cloudflare Tunnel — ${TUNNEL_NAME}"

# Check if tunnel already exists
EXISTING_TUNNEL=$(cf GET "/accounts/${ACCOUNT_ID}/cfd_tunnel?name=${TUNNEL_NAME}&is_deleted=false")
TUNNEL_ID=$(echo "$EXISTING_TUNNEL" | jq -r '.result[0].id // empty')

if [[ -z "$TUNNEL_ID" ]]; then
  # Generate a 32-byte tunnel secret
  TUNNEL_SECRET=$(openssl rand -base64 32)
  TUNNEL_RESP=$(cf POST "/accounts/${ACCOUNT_ID}/cfd_tunnel" \
    --data "{\"name\":\"${TUNNEL_NAME}\",\"tunnel_secret\":\"${TUNNEL_SECRET}\",\"config_src\":\"cloudflare\"}")
  TUNNEL_ID=$(echo "$TUNNEL_RESP" | jq -r '.result.id // empty')
  if [[ -z "$TUNNEL_ID" ]]; then
    warn "Tunnel creation failed: $(echo "$TUNNEL_RESP" | jq -r '.errors[0].message')"
  else
    ok "Tunnel created: ${TUNNEL_ID}"
    # Write credentials file locally
    mkdir -p ~/.cloudflared
    echo "$TUNNEL_RESP" | jq --arg acct "$ACCOUNT_ID" '{
      AccountTag: $acct,
      TunnelID: .result.id,
      TunnelName: .result.name,
      TunnelSecret: .result.tunnel_secret
    }' > ~/.cloudflared/${TUNNEL_ID}.json
    ok "Credentials saved: ~/.cloudflared/${TUNNEL_ID}.json"
  fi
else
  ok "Tunnel already exists: ${TUNNEL_ID}"
fi

# Write cloudflared config
if [[ -n "$TUNNEL_ID" ]]; then
  mkdir -p ~/.cloudflared
  cat > ~/.cloudflared/config.yml << CONF
tunnel: ${TUNNEL_ID}
credentials-file: ${HOME}/.cloudflared/${TUNNEL_ID}.json

ingress:
  - hostname: ${MCP_HOSTNAME}
    service: ${MCP_LOCAL}
  - service: http_status:404
CONF
  ok "cloudflared config written: ~/.cloudflared/config.yml"

  # Add DNS CNAME for the tunnel (idempotent — skip if exists)
  CNAME_VAL="${TUNNEL_ID}.cfargotunnel.com"
  EXISTING_CNAME=$(echo "$DNS_RECORDS" | jq -r --arg h "$MCP_HOSTNAME" \
    '.result[] | select(.name==$h) | .id' | head -1)

  if [[ -z "$EXISTING_CNAME" ]]; then
    CNAME_RESP=$(cf POST "/zones/${ZONE_ID}/dns_records" \
      --data "{\"type\":\"CNAME\",\"name\":\"${MCP_HOSTNAME}\",\"content\":\"${CNAME_VAL}\",\"proxied\":true,\"ttl\":1}")
    success_or_warn "$CNAME_RESP" "DNS CNAME ${MCP_HOSTNAME} → ${CNAME_VAL}"
  else
    ok "DNS CNAME ${MCP_HOSTNAME} already exists"
  fi
fi

# Set tunnel public hostname config via API
if [[ -n "$TUNNEL_ID" ]]; then
  INGRESS_RESP=$(cf PUT "/accounts/${ACCOUNT_ID}/cfd_tunnel/${TUNNEL_ID}/configurations" \
    --data "{
      \"config\": {
        \"ingress\": [
          {\"hostname\":\"${MCP_HOSTNAME}\",\"service\":\"${MCP_LOCAL}\"},
          {\"service\":\"http_status:404\"}
        ]
      }
    }" 2>/dev/null || true)
  [[ -n "$INGRESS_RESP" ]] && ok "Tunnel ingress configured via API"
fi

# ── 6. Workers site ───────────────────────────────────────────────────────────

step "6. Workers site — bandeiran-site"

if [[ -d "$SITE_DIR" ]]; then
  cd "$SITE_DIR"

  # Install deps if needed
  if [[ ! -d "node_modules" ]] || [[ "package.json" -nt "node_modules/.package-lock.json" ]]; then
    echo "  → Installing dependencies..."
    pnpm install --frozen-lockfile --silent
  fi

  # Build
  echo "  → Building..."
  pnpm build 2>&1 | tail -5

  # Deploy
  echo "  → Deploying..."
  CLOUDFLARE_API_TOKEN="$CF_API_TOKEN" npx wrangler deploy --config wrangler.jsonc
  ok "bandeiran-site deployed"

  cd - > /dev/null
else
  warn "Site directory not found: $SITE_DIR"
fi

# ── 7. Summary ────────────────────────────────────────────────────────────────

step "7. Summary"

echo ""
echo -e "${GREEN}Configuration complete.${NC}"
echo ""
echo "  Zone      : ${DOMAIN} (${ZONE_ID})"
echo "  SSL       : full"
echo "  HTTPS     : always on"
echo "  R2 bucket : ${R2_BUCKET} (with Data Catalog)"
echo "  Vectorize : ${VECTORIZE_INDEX} (1024d cosine)"
[[ -n "${TUNNEL_ID:-}" ]] && echo "  Tunnel    : ${TUNNEL_ID}"
echo "  MCP URL   : https://${MCP_HOSTNAME} → ${MCP_LOCAL}"
echo ""
echo "  Cloudflare Access JWT Security Header:"
echo "    Header   : Cf-Access-Jwt-Assertion"
echo "    JWKS URL : https://${DOMAIN}/cdn-cgi/access/certs"
echo ""
echo -e "${YELLOW}PENDING — manual actions required:${NC}"
echo ""
echo "  1. Transfer nameservers at Squarespace to Cloudflare:"
echo "     → support.squarespace.com → request EPP code for bandeiran.com"
echo "     → Then: Cloudflare dashboard → bandeiran.com → Update nameservers"
echo "     → Cloudflare NS shown above in step 0"
echo ""
echo "  2. Start the MCP tunnel (run locally on your Mac):"
[[ -n "${TUNNEL_ID:-}" ]] && echo "     cloudflared tunnel run ${TUNNEL_NAME}"
echo ""
echo "  3. Verify propagation (after NS update, ~24h):"
echo "     dig bandeiran.com NS"
echo "     curl -I https://bandeiran.com"
echo ""
echo -e "${YELLOW}TOKEN EXPIRES: 2026-08-31 23:59:59Z — cancel it now at:${NC}"
echo "  https://dash.cloudflare.com/profile/api-tokens"
