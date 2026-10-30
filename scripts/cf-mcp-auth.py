#!/usr/bin/env python3
"""
Cloudflare MCP OAuth PKCE auth + auto-refresh

Uso:
  python3 cf-mcp-auth.py           # login inicial (abre browser uma vez)
  python3 cf-mcp-auth.py --refresh # renovar tokens sem browser
  python3 cf-mcp-auth.py --status  # ver estado dos tokens
"""

import json, sys, base64, hashlib, secrets, urllib.request, urllib.parse, urllib.error
import http.server, threading, webbrowser
from pathlib import Path
from datetime import datetime, timezone

TOKENS_FILE  = Path.home() / ".cf-mcp-tokens.json"
MCP_CONFIG   = Path.home() / ".gemini/config/mcp_config.json"
PORT         = 8585
REDIRECT_URI = f"http://localhost:{PORT}/callback"

SERVERS = {
    "cloudflare-api":           "https://mcp.cloudflare.com",
    "cloudflare-bindings":      "https://bindings.mcp.cloudflare.com",
    "cloudflare-builds":        "https://builds.mcp.cloudflare.com",
    "cloudflare-observability": "https://observability.mcp.cloudflare.com",
}

# ── helpers ──────────────────────────────────────────────────────────────────

def _pkce_pair():
    verifier  = base64.urlsafe_b64encode(secrets.token_bytes(32)).rstrip(b"=").decode()
    challenge = base64.urlsafe_b64encode(
        hashlib.sha256(verifier.encode()).digest()
    ).rstrip(b"=").decode()
    return verifier, challenge

def _load_tokens():
    return json.loads(TOKENS_FILE.read_text()) if TOKENS_FILE.exists() else {}

def _save_tokens(data):
    TOKENS_FILE.write_text(json.dumps(data, indent=2))
    TOKENS_FILE.chmod(0o600)

_HEADERS = {"User-Agent": "Mozilla/5.0 (cf-mcp-auth/1.0)"}

def _open(url):
    return urllib.request.urlopen(
        urllib.request.Request(url, headers=_HEADERS), timeout=5)

def _discover(base_url):
    for url in [
        f"{base_url}/.well-known/oauth-authorization-server",
        "https://mcp.cloudflare.com/.well-known/oauth-authorization-server",
    ]:
        try:
            with _open(url) as r:
                return json.loads(r.read())
        except Exception:
            continue
    raise RuntimeError(f"Não foi possível descobrir OAuth metadata para {base_url}")

def _register_client(reg_endpoint):
    data = json.dumps({
        "client_name":                "bandeiran-mcp-auto",
        "redirect_uris":              [REDIRECT_URI],
        "grant_types":                ["authorization_code", "refresh_token"],
        "token_endpoint_auth_method": "none",
    }).encode()
    req = urllib.request.Request(reg_endpoint, data=data,
                                  headers={**_HEADERS, "Content-Type": "application/json"})
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())

def _capture_code():
    result = {}

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            params = dict(urllib.parse.parse_qsl(
                urllib.parse.urlparse(self.path).query))
            result.update(params)
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(
                b"<html><body style='font-family:sans-serif;text-align:center;padding:60px'>"
                b"<h2>&#x2705; Autenticado!</h2><p>Pode fechar esta aba.</p></body></html>"
            )
        def log_message(self, *_): pass

    srv = http.server.HTTPServer(("localhost", PORT), Handler)
    t = threading.Thread(target=srv.handle_request, daemon=True)
    t.start()
    t.join(timeout=120)
    srv.server_close()
    return result.get("code"), result.get("state")

def _exchange_code(token_endpoint, client_id, code, verifier):
    data = urllib.parse.urlencode({
        "grant_type":    "authorization_code",
        "client_id":     client_id,
        "code":          code,
        "redirect_uri":  REDIRECT_URI,
        "code_verifier": verifier,
    }).encode()
    req = urllib.request.Request(token_endpoint, data=data,
                                  headers={**_HEADERS, "Content-Type": "application/x-www-form-urlencoded"})
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())

def _do_refresh(token_endpoint, client_id, refresh_tok):
    data = urllib.parse.urlencode({
        "grant_type":    "refresh_token",
        "client_id":     client_id,
        "refresh_token": refresh_tok,
    }).encode()
    req = urllib.request.Request(token_endpoint, data=data,
                                  headers={**_HEADERS, "Content-Type": "application/x-www-form-urlencoded"})
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())

def _update_config(server_key, access_token):
    cfg = json.loads(MCP_CONFIG.read_text())
    if server_key in cfg["mcpServers"]:
        cfg["mcpServers"][server_key].setdefault("headers", {})
        cfg["mcpServers"][server_key]["headers"]["Authorization"] = f"Bearer {access_token}"
        MCP_CONFIG.write_text(json.dumps(cfg, indent=2))
        print(f"    ✓ {MCP_CONFIG} atualizado")

# ── comandos ─────────────────────────────────────────────────────────────────

def do_login():
    tokens = _load_tokens()

    # Agrupa servidores pelo auth server (evita fluxos duplicados)
    groups: dict[str, dict] = {}
    for srv_key, base_url in SERVERS.items():
        meta     = _discover(base_url)
        issuer   = meta["issuer"]
        groups.setdefault(issuer, {"meta": meta, "servers": []})
        groups[issuer]["servers"].append(srv_key)

    for issuer, group in groups.items():
        meta     = group["meta"]
        reg_ep   = meta["registration_endpoint"]
        auth_ep  = meta["authorization_endpoint"]
        token_ep = meta["token_endpoint"]

        client_key = f"client_{issuer}"
        if client_key not in tokens:
            print(f"\n→ Registrando cliente OAuth em {issuer}...")
            client = _register_client(reg_ep)
            tokens[client_key] = client
            _save_tokens(tokens)
            print(f"  client_id: {client['client_id']}")

        client_id = tokens[client_key]["client_id"]
        verifier, challenge = _pkce_pair()

        csrf_state = secrets.token_hex(16)
        auth_url = auth_ep + "?" + urllib.parse.urlencode({
            "response_type":         "code",
            "client_id":             client_id,
            "redirect_uri":          REDIRECT_URI,
            "code_challenge":        challenge,
            "code_challenge_method": "S256",
            "state":                 csrf_state,
        })

        print(f"\n→ Abrindo browser para autenticar em: {issuer}")
        webbrowser.open(auth_url)
        print("  Aguardando callback na porta 8585 (timeout: 2 min)...")
        code, received_state = _capture_code()

        if not code:
            print("  ✗ Timeout — nenhum código recebido. Tente novamente.")
            continue

        if received_state != csrf_state:
            print("  ✗ State mismatch — possível ataque CSRF. Abortando.")
            continue

        print("  → Trocando código por tokens...")
        tok = _exchange_code(token_ep, client_id, code, verifier)

        now        = datetime.now(timezone.utc).timestamp()
        expires_in = tok.get("expires_in", 3600)

        for srv_key in group["servers"]:
            tokens[srv_key] = {
                "access_token":  tok["access_token"],
                "refresh_token": tok.get("refresh_token"),
                "expires_at":    now + expires_in,
                "token_endpoint": token_ep,
                "client_id":     client_id,
            }
            _update_config(srv_key, tok["access_token"])

        _save_tokens(tokens)
        print(f"  ✓ Tokens válidos por {expires_in // 60} min")

    print(f"\n✅ Login completo! Tokens em: {TOKENS_FILE}")
    print("Agende a renovação automática:")
    print("  launchctl load ~/Library/LaunchAgents/com.bandeiran.cf-mcp-refresh.plist")


def do_refresh():
    tokens = _load_tokens()
    if not tokens:
        print("✗ Nenhum token salvo. Execute sem --refresh primeiro.")
        sys.exit(1)

    now     = datetime.now(timezone.utc).timestamp()
    updated = False

    for srv_key in SERVERS:
        srv = tokens.get(srv_key)
        if not srv:
            print(f"  ⚠  {srv_key}: sem token — execute login primeiro")
            continue

        mins_left = (srv.get("expires_at", 0) - now) / 60
        if mins_left > 10:
            print(f"  · {srv_key}: ok ({mins_left:.0f} min restantes)")
            continue

        refresh_tok = srv.get("refresh_token")
        if not refresh_tok:
            print(f"  ✗ {srv_key}: sem refresh_token — execute login novamente")
            continue

        try:
            print(f"  → Renovando {srv_key}...")
            tok        = _do_refresh(srv["token_endpoint"], srv["client_id"], refresh_tok)
            expires_in = tok.get("expires_in", 3600)
            srv.update({
                "access_token":  tok["access_token"],
                "refresh_token": tok.get("refresh_token", refresh_tok),
                "expires_at":    now + expires_in,
            })
            _update_config(srv_key, tok["access_token"])
            updated = True
            print(f"    ✓ válido por mais {expires_in // 60} min")
        except Exception as e:
            print(f"  ✗ {srv_key}: erro — {e}")

    if updated:
        _save_tokens(tokens)
    print("\n✓ Refresh concluído")


def do_status():
    tokens = _load_tokens()
    now    = datetime.now(timezone.utc).timestamp()
    print(f"{'Servidor':<30} {'Status':<12} {'Expira em'}")
    print("-" * 60)
    for srv_key in SERVERS:
        srv = tokens.get(srv_key)
        if not srv:
            print(f"{srv_key:<30} {'sem token':<12}")
            continue
        mins = (srv.get("expires_at", 0) - now) / 60
        status = "✓ ok" if mins > 10 else ("⚠ expirando" if mins > 0 else "✗ expirado")
        print(f"{srv_key:<30} {status:<12} {max(mins, 0):.0f} min")


# ── main ─────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    if "--refresh" in sys.argv:
        do_refresh()
    elif "--status" in sys.argv:
        do_status()
    else:
        do_login()
