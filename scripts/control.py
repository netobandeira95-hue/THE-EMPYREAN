#!/usr/bin/env python3
"""
AI Infra — Master Control
Comandos de infraestrutura: cache, rede, modo seguro.

Uso:
  python3 /Volumes/THEEMPYREAN/scripts/control.py --clear-cache
  python3 /Volumes/THEEMPYREAN/scripts/control.py --local-only        # desliga WiFi + bloqueia APIs online
  python3 /Volumes/THEEMPYREAN/scripts/control.py --local-only --off  # restaura WiFi
  python3 /Volumes/THEEMPYREAN/scripts/control.py --safety-mode        # bloqueia APIs sem desligar WiFi
  python3 /Volumes/THEEMPYREAN/scripts/control.py --safety-mode --off  # restaura APIs
  python3 /Volumes/THEEMPYREAN/scripts/control.py --status             # mostra estado atual
"""
import argparse, json, shutil, subprocess
from pathlib import Path

# ── Paths ─────────────────────────────────────────────────────────────────────

INFRA         = Path("/Volumes/THEEMPYREAN").expanduser()
LITELLM_CFG   = Path("~/litellm-proxy/config.yaml").expanduser()
ZSHRC         = Path("~/.zshrc").expanduser()
STATE_FILE    = Path("~/.vision-agent-infra-state.json").expanduser()
WHISPER_CACHE = Path("~/.cache/huggingface/hub").expanduser()
LITELLM_CACHE = Path("~/.cache/litellm").expanduser()

# Diretórios temporários criados pelo stack
TMP_PATTERNS = [
    "/tmp/vision-agent-*",
    "/tmp/multiagent-result.json",
    "/tmp/VisionAgentFolderAction.applescript",
    "/tmp/ollama.log",
]

# ── State ─────────────────────────────────────────────────────────────────────

def _load_state() -> dict:
    if STATE_FILE.exists():
        # pyrefly: ignore [no-any-return-explicit]
        return json.loads(STATE_FILE.read_text())
    return {}

def _save_state(state: dict):
    STATE_FILE.write_text(json.dumps(state, indent=2))

# ── WiFi ──────────────────────────────────────────────────────────────────────

def _get_wifi_interface() -> str:
    """Detecta a interface WiFi ativa (en0, en1, etc.)."""
    result = subprocess.run(
        ["networksetup", "-listallhardwareports"],
        capture_output=True, text=True
    )
    lines = result.stdout.splitlines()
    for i, line in enumerate(lines):
        if "Wi-Fi" in line or "AirPort" in line:
            for j in range(i, min(i+3, len(lines))):
                if "Device:" in lines[j]:
                    return lines[j].split("Device:")[1].strip()
    return "en0"   # fallback

def wifi_off(iface: str) -> bool:
    r = subprocess.run(["networksetup", "-setairportpower", iface, "off"],
                       capture_output=True)
    return r.returncode == 0

def wifi_on(iface: str) -> bool:
    r = subprocess.run(["networksetup", "-setairportpower", iface, "on"],
                       capture_output=True)
    return r.returncode == 0

def wifi_status(iface: str) -> str:
    r = subprocess.run(["networksetup", "-getairportpower", iface],
                       capture_output=True, text=True)
    return "on" if "On" in r.stdout else "off"

# ── LiteLLM config helpers ────────────────────────────────────────────────────

def _litellm_disable_online():
    """Comenta as entradas Claude/Anthropic no config do LiteLLM."""
    if not LITELLM_CFG.exists():
        return
    original = LITELLM_CFG.read_text()
    # salva backup
    LITELLM_CFG.with_suffix(".yaml.bak").write_text(original)
    # comenta linhas que referenciam anthropic
    lines = []
    for line in original.splitlines():
        stripped = line.lstrip()
        if "anthropic/" in stripped or "ANTHROPIC_API_KEY" in stripped:
            lines.append("#SAFETY# " + line)
        else:
            lines.append(line)
    LITELLM_CFG.write_text("\n".join(lines))

def _litellm_restore_online():
    """Restaura o config original do LiteLLM."""
    backup = LITELLM_CFG.with_suffix(".yaml.bak")
    if backup.exists():
        LITELLM_CFG.write_text(backup.read_text())
        print("  ✓ LiteLLM config restaurado")
    else:
        print("  ⚠ Backup não encontrado — restaure manualmente ~/litellm-proxy/config.yaml")

# ── Comandos ──────────────────────────────────────────────────────────────────

def clear_cache(include_whisper: bool = False, include_litellm: bool = True,
                include_configs: bool = False):
    """
    Limpa todos os arquivos temporários do stack de AI.

    include_whisper  → remove modelos Whisper (~150MB–1.5GB por modelo)
    include_litellm  → limpa cache de respostas do LiteLLM
    include_configs  → remove configs criados pelo wizard (whisper model, state)
    """
    import glob
    print("\n═══ Clear Cache ═══════════════════════════════")

    freed = 0

    # /tmp do vision agent e multiagent
    for pattern in TMP_PATTERNS:
        for path in glob.glob(pattern):
            p = Path(path)
            try:
                if p.is_dir():
                    sz = sum(f.stat().st_size for f in p.rglob("*") if f.is_file())
                    shutil.rmtree(p)
                else:
                    sz = p.stat().st_size
                    p.unlink()
                freed += sz
                print(f"  ✓ Removido: {path} ({sz//1024} KB)")
            except FileNotFoundError:
                pass  # already deleted by a concurrent run
            except Exception as e:
                print(f"  ✗ {path}: {e}")

    # LiteLLM cache local
    if include_litellm and LITELLM_CACHE.exists():
        sz = sum(f.stat().st_size for f in LITELLM_CACHE.rglob("*") if f.is_file())
        shutil.rmtree(LITELLM_CACHE, ignore_errors=True)
        freed += sz
        print(f"  ✓ LiteLLM cache: {sz//1024//1024} MB")

    # Modelos Whisper (opcional — pergunta antes)
    if include_whisper and WHISPER_CACHE.exists():
        sz = sum(f.stat().st_size for f in WHISPER_CACHE.rglob("*") if f.is_file())
        ans = input(f"  Remover modelos Whisper ({sz//1024//1024} MB)? [s/N]: ").strip().lower()
        if ans in ("s", "y"):
            shutil.rmtree(WHISPER_CACHE, ignore_errors=True)
            freed += sz
            print(f"  ✓ Whisper cache: {sz//1024//1024} MB removidos")

    # Configs do wizard
    if include_configs:
        for cfg in [Path("~/.vision-agent-config.json").expanduser(), STATE_FILE]:
            if cfg.exists():
                cfg.unlink()
                print(f"  ✓ Config removido: {cfg}")

    print(f"\n  Total liberado: {freed//1024//1024} MB")
    print("═══════════════════════════════════════════════\n")


def local_only(restore: bool = False):
    """
    Desliga o WiFi e bloqueia chamadas Anthropic no LiteLLM.
    Tudo roteia exclusivamente para Ollama local.

    restore=True: reverte (liga WiFi + restaura config).
    """
    state = _load_state()
    iface = _get_wifi_interface()

    if restore:
        print("\n═══ Local-Only OFF (restaurando) ══════════════")
        current = wifi_status(iface)
        if current == "off":
            if wifi_on(iface):
                print(f"  ✓ WiFi ({iface}) ligado")
            else:
                print(f"  ✗ Falha ao ligar WiFi — ligue manualmente")
        else:
            print(f"  → WiFi ({iface}) já estava ligado")
        _litellm_restore_online()
        state.pop("local_only", None)
        _save_state(state)
        print("  ✓ Modo local-only desativado\n")
        return

    print("\n═══ Local-Only ON ══════════════════════════════")
    print(f"  Interface WiFi detectada: {iface}")

    current = wifi_status(iface)
    if current == "on":
        if wifi_off(iface):
            print(f"  ✓ WiFi ({iface}) desligado")
            state["wifi_was_on"] = True
        else:
            print(f"  ✗ Falha ao desligar WiFi — desative manualmente")
    else:
        print(f"  → WiFi ({iface}) já estava desligado")

    _litellm_disable_online()
    print("  ✓ LiteLLM: entradas Anthropic/Claude comentadas")
    print("  ✓ Apenas Ollama local disponível")

    state["local_only"] = True
    state["wifi_interface"] = iface
    _save_state(state)

    print("\n  Modelos disponíveis agora:")
    result = subprocess.run(["ollama", "list"], capture_output=True, text=True)
    for line in result.stdout.strip().splitlines()[1:]:  # pula header
        print(f"    {line.split()[0]}")

    print("\n  Para restaurar: python3 /Volumes/THEEMPYREAN/scripts/control.py --local-only --off")
    print("═══════════════════════════════════════════════\n")


def safety_mode(restore: bool = False):
    """
    Bloqueia chamadas Anthropic no LiteLLM SEM desligar o WiFi.
    WiFi permanece ativo (acesso ao navegador, etc.), mas o stack de AI
    fica 100% local — sem risco de vazar dados para APIs externas.

    restore=True: reativa chamadas Anthropic.
    """
    state = _load_state()

    if restore:
        print("\n═══ Safety-Mode OFF (restaurando) ═════════════")
        _litellm_restore_online()
        state.pop("safety_mode", None)
        _save_state(state)
        print("  ✓ Safety-mode desativado — APIs Anthropic reativadas\n")
        return

    print("\n═══ Safety-Mode ON ═════════════════════════════")
    print("  WiFi: mantido (sem alteração)")
    print("  APIs Anthropic: bloqueadas no LiteLLM")
    print("  Ollama local: ativo")

    _litellm_disable_online()
    state["safety_mode"] = True
    _save_state(state)

    print("\n  O stack de AI opera 100% local.")
    print("  Nenhuma chamada sai para anthropic.com.")
    print("  Coordinator usa llama3.1 como fallback de síntese.")
    print("\n  Para restaurar: python3 /Volumes/THEEMPYREAN/scripts/control.py --safety-mode --off")
    print("═══════════════════════════════════════════════\n")


def stop():
    """
    Congela toda a atividade AI em execução.
    Para: LiteLLM proxy, processos vision-agent, coordinator, Ollama (descarrega modelos).
    NÃO desinstala nada — apenas interrompe processos ativos.
    """
    print("\n═══ STOP — Parando toda atividade AI ══════════")

    stopped = []

    # LiteLLM
    r = subprocess.run(["pkill", "-f", "litellm"], capture_output=True)
    if r.returncode == 0:
        print("  ✓ LiteLLM: parado")
        stopped.append("litellm")
    else:
        print("  → LiteLLM: não estava rodando")

    # Vision agent (watch mode ou qualquer instância)
    r = subprocess.run(["pkill", "-f", "vision-agent/agent.py"], capture_output=True)
    if r.returncode == 0:
        print("  ✓ Vision Agent: parado")
        stopped.append("vision-agent")
    else:
        print("  → Vision Agent: não estava rodando")

    # Coordinator (multiagent)
    r = subprocess.run(["pkill", "-f", "multiagent/coordinator.py"], capture_output=True)
    if r.returncode == 0:
        print("  ✓ Coordinator: parado")
        stopped.append("coordinator")
    else:
        print("  → Coordinator: não estava rodando")

    # RAG indexer
    r = subprocess.run(["pkill", "-f", "rag/indexer.py"], capture_output=True)
    if r.returncode == 0:
        print("  ✓ RAG Indexer: parado")
        stopped.append("rag-indexer")
    else:
        print("  → RAG Indexer: não estava rodando")

    # Descarregar todos os modelos Ollama da memória (mas manter o daemon vivo)
    try:
        import urllib.request as _ur, urllib.error as _ue
        with _ur.urlopen("http://localhost:11434/api/ps", timeout=3) as resp:
            active = json.loads(resp.read()).get("models", [])
            for m in active:
                name = m["name"]
                req = _ur.Request(
                    "http://localhost:11434/api/generate",
                    data=json.dumps({"model": name, "keep_alive": 0, "prompt": ""}).encode(),
                    headers={"Content-Type": "application/json"},
                )
                try:
                    _ur.urlopen(req, timeout=5)
                except Exception:
                    pass
                print(f"  ✓ Ollama: {name} descarregado da memória")
                stopped.append(f"ollama/{name}")
    except Exception:
        print("  → Ollama: nenhum modelo ativo ou serviço indisponível")

    if stopped:
        print(f"\n  Parado: {', '.join(stopped)}")
    else:
        print("\n  Nenhum processo AI estava ativo")

    print("\n  Para retomar:")
    print("    LiteLLM : ~/litellm-proxy/start.sh &")
    print("    Vision  : python3 /Volumes/THEEMPYREAN/services/vision-agent/agent.py --watch &")
    print("    Status  : python3 /Volumes/THEEMPYREAN/scripts/control.py --status")
    print("═══════════════════════════════════════════════\n")


def status():
    """Mostra o estado atual de toda a infraestrutura."""
    state = _load_state()
    iface = _get_wifi_interface()

    print("\n═══ AI Infra Status ════════════════════════════")

    # Rede
    wifi = wifi_status(iface)
    print(f"\n  WiFi ({iface}):     {wifi}")
    print(f"  local-only:       {'ATIVO' if state.get('local_only') else 'off'}")
    print(f"  safety-mode:      {'ATIVO' if state.get('safety_mode') else 'off'}")

    # Serviços
    print("\n  Serviços:")
    def svc(name, check):
        ok = check()
        print(f"    {'✓' if ok else '✗'} {name}")
        return ok

    import urllib.request, urllib.error
    def litellm_up():
        try:
            urllib.request.urlopen("http://localhost:4000/v1/models", timeout=2)
            return True
        except Exception:
            return False

    def ollama_up():
        try:
            urllib.request.urlopen("http://localhost:11434/api/tags", timeout=2)
            return True
        except Exception:
            return False

    svc("LiteLLM :4000",  litellm_up)
    svc("Ollama  :11434", ollama_up)

    # Modelos Ollama
    result = subprocess.run(["ollama", "list"], capture_output=True, text=True)
    models = [l.split()[0] for l in result.stdout.strip().splitlines()[1:] if l.strip()]
    print(f"\n  Ollama ({len(models)} modelos): {', '.join(models)}")

    # Disco
    result = subprocess.run(["df", "-h", str(Path.home())],
                            capture_output=True, text=True)
    for line in result.stdout.strip().splitlines()[1:]:
        parts = line.split()
        if len(parts) >= 5:
            print(f"\n  Disco: {parts[3]} livres de {parts[1]} ({parts[4]} usado)")

    print("═══════════════════════════════════════════════\n")


# ── CLI ───────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    ap = argparse.ArgumentParser(
        description="AI Infra Master Control — cache, rede, modo seguro"
    )
    ap.add_argument("--stop",          action="store_true", help="Para todo processo AI ativo")
    ap.add_argument("--clear-cache",   action="store_true", help="Limpa todos os arquivos temporários")
    ap.add_argument("--whisper",       action="store_true", help="Inclui modelos Whisper no clear-cache")
    ap.add_argument("--configs",       action="store_true", help="Inclui configs do wizard no clear-cache")
    ap.add_argument("--local-only",    action="store_true", help="Desliga WiFi + bloqueia APIs online")
    ap.add_argument("--safety-mode",   action="store_true", help="Bloqueia APIs online (WiFi mantido)")
    ap.add_argument("--off",           action="store_true", help="Restaura (usar com --local-only ou --safety-mode)")
    ap.add_argument("--status",        action="store_true", help="Mostra estado atual da infraestrutura")
    args = ap.parse_args()

    if args.stop:
        stop()
    elif args.clear_cache:
        clear_cache(include_whisper=args.whisper, include_configs=args.configs)
    elif args.local_only:
        local_only(restore=args.off)
    elif args.safety_mode:
        safety_mode(restore=args.off)
    elif args.status:
        status()
    else:
        ap.print_help()
