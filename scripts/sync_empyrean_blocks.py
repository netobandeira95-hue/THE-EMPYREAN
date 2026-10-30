#!/usr/bin/env python3
"""
THE EMPYREAN — Motor Automatizado de Conformidade, Auditoria Zero-Leak (via Sanityzer),
Estruturação em Blocos/Branches (a partir de `main`) e Repositórios Individuais (`.git`).

Padrão de Repositório:
  netobandeira95-hue/THE-EMPYREAN-(NOME DA FERRAMENTA/ARQUIVO/PASTA)
"""

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path("/Volumes/THEEMPYREAN")
SANITYZER_PKG_ROOT = ROOT / "packages" / "sanityzer"
if str(SANITYZER_PKG_ROOT) not in sys.path:
    sys.path.insert(0, str(SANITYZER_PKG_ROOT))

from sanityzer.engine import sanitize_workspace, scan_workspace  # noqa: E402

GITHUB_OWNER = "netobandeira95-hue"
REPO_PREFIX = "THE-EMPYREAN-"
BLOCKLIST_FILE = ROOT / "config" / "pii-blocklist.txt"
PRE_COMMIT_SRC = ROOT / "scripts" / "hooks" / "pre-commit"

# Lista oficial de 43 blocos (NOME DA FERRAMENTA/ARQUIVO/PASTA) -> Caminho relativo
# Reestruturado: THE EMPYREAN mínimo com ferramentas/apps adicionais em `services/`
BLOCKS = [
    # APPS / NÚCLEO MÍNIMO (1)
    ("Antigravity", "apps/Antigravity"),
    # PACKAGES (10 — incluindo a ferramenta soberana `sanityzer`)
    ("CLI-Anything", "packages/CLI-Anything"),
    ("cc-switch", "packages/cc-switch"),
    ("cf-registrar", "packages/cf-registrar"),
    ("cloudflare-analysis", "packages/cloudflare-analysis"),
    ("context-mode", "packages/context-mode"),
    ("mac-clean", "packages/mac-clean"),
    ("mobile-security", "packages/mobile-security"),
    ("rea", "packages/rea"),
    ("sanityzer", "packages/sanityzer"),
    ("sq-contacts", "packages/sq-contacts"),
    # SERVICES & ADD-ONS (26)
    ("EMPYREAN-MKT", "services/EMPYREAN MKT"),
    ("OmniScreen", "services/OmniScreen"),
    ("VISU", "services/VISU"),
    ("annas-archive-extension", "services/annas-archive-extension"),
    ("antigravity-secure", "services/antigravity-secure"),
    ("app-musicos-api", "services/app-musicos-api"),
    ("bandeiran-site", "services/bandeiran-site"),
    ("cloudflare-widget-macos", "services/cloudflare-widget-macos"),
    ("exames-backend", "services/exames-backend"),
    ("helix-send", "services/helix-send"),
    ("litellm-proxy", "services/litellm-proxy"),
    ("mcp-observability-saas", "services/mcp-observability-saas"),
    ("medscriptpro", "services/medscriptpro"),
    ("mlflow", "services/mlflow"),
    ("model-pause-api", "services/model-pause-api"),
    ("modeldb", "services/modeldb"),
    ("multiagent-orchestrator", "services/multiagent-orchestrator"),
    ("nexus-portal", "services/nexus-portal"),
    ("notebooklm-integrator", "services/notebooklm-integrator"),
    ("opencode-vscode", "services/opencode-vscode"),
    ("project-nomad", "services/project-nomad"),
    ("qdrant-crm", "services/qdrant-crm"),
    ("rag-indexer", "services/rag-indexer"),
    ("unify-saas", "services/unify-saas"),
    ("vision-agent", "services/vision-agent"),
    ("yt-dlp-extension", "services/yt-dlp-extension"),
    # SCRIPTS & AUTOMAÇÃO (2)
    ("automacao-scripts", "scripts/automacao-scripts"),
    ("scripts", "scripts"),
    # TEMPLATES (3)
    ("frappe-bench", "templates/frappe-bench"),
    ("my-first-worker", "templates/my-first-worker"),
    ("snippets-e-testes", "templates/snippets-e-testes"),
    # PILARES ESTRUTURAIS (3)
    ("infra", "infra"),
    ("docs", "docs"),
    ("config", "config"),
]

SKIP_DIRS = {
    ".git", ".git_sub_bak", "node_modules", ".venv", "venv", "__pycache__",
    ".next", "dist", "build", ".build", "target", "out", "vendor", "libraries",
    "Frameworks", "DerivedData", "Pods", "site-packages",
    "Antigravity IDE.app", "Antigravity-Data",
    "docker-engine", "toolchains", "vsix-installers", "archive", "storage",
    "qdrant_storage", "models", "raw", "processed", "domain_databases",
    "research_datasets", "personal_vault",
}


def run_git(args, cwd=ROOT, check=True, extra_env=None):
    env = os.environ.copy()
    env["GIT_AUTHOR_NAME"] = "THE-EMPYREAN Bot"
    env["GIT_AUTHOR_EMAIL"] = "noreply@the-empyrean.local"
    env["GIT_COMMITTER_NAME"] = "THE-EMPYREAN Bot"
    env["GIT_COMMITTER_EMAIL"] = "noreply@the-empyrean.local"
    if extra_env:
        env.update(extra_env)
    res = subprocess.run(
        ["git"] + args,
        cwd=str(cwd),
        capture_output=True,
        text=True,
        env=env,
    )
    if check and res.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)} failed in {cwd}:\n{res.stderr}\n{res.stdout}")
    return res


def audit_and_sanitize_workspace():
    """Executa o motor Sanityzer (LGPD/GDPR/HIPAA/PCI-DSS/OWASP) sobre todo o workspace."""
    print("🧹 [Sanityzer] Executando sanitização preventiva e auditoria regulatória (LGPD/ANPD/OWASP)...")
    summary = sanitize_workspace(ROOT, BLOCKLIST_FILE)
    if summary.files_modified > 0 or summary.appledouble_removed > 0:
        print(
            f"   → Sanitizados {summary.files_modified} arquivo(s) e removidos "
            f"{summary.appledouble_removed} arquivo(s) AppleDouble (._*)."
        )
    if summary.new_blocklist_terms:
        print(f"   → {len(summary.new_blocklist_terms)} novo(s) termo(s) registrado(s) em config/pii-blocklist.txt.")

    files_scanned, findings = scan_workspace(ROOT, BLOCKLIST_FILE)
    if findings:
        print(f"❌ Violação(ões) detectada(s) na auditoria Zero-Leak ({len(findings)}):")
        for f in findings[:25]:
            print(f"   - {f.file_path}:{f.line_number} [{f.rule_id}] {f.rule_name}: {f.matched_value}")
        sys.exit(1)

    print(f"✅ Auditoria Zero-Leak aprovada pelo Sanityzer ({files_scanned} arquivos verificados, 0 vazamentos).")


def install_hook_in_git_dir(git_dir: Path):
    hooks_dir = git_dir / "hooks"
    hooks_dir.mkdir(parents=True, exist_ok=True)
    dst = hooks_dir / "pre-commit"
    if dst.resolve() == PRE_COMMIT_SRC.resolve():
        dst.chmod(0o755)
        return
    if dst.exists() or dst.is_symlink():
        dst.unlink()
    shutil.copy2(PRE_COMMIT_SRC, dst)
    dst.chmod(0o755)


def ensure_block_gitignore(block_path: Path):
    """Garante que o bloco tenha um .gitignore contendo as regras de proteção Zero-Leak."""
    block_gi = block_path / ".gitignore"
    mandatory_rules = """
# === THE-EMPYREAN ZERO-LEAK MANDATORY RULES ===
._*
.DS_Store
.git_sub_bak/
**/.git_sub_bak/
.env
.env.*
!.env.example
!.env.template
*.key
*.pem
*.crt
*.p12
*.cer
*.pfx
*.sqlite
*.sqlite3
*.db
*.mv.db
*.csv
*.xlsx
*.vsix
**/storage/
**/qdrant_storage/
**/domain_databases/
**/research_datasets/
**/personal_vault/
data/processed/
node_modules/
.venv/
venv/
__pycache__/
"""
    if not block_gi.exists():
        block_gi.write_text(mandatory_rules.strip() + "\n", encoding="utf-8")
    else:
        existing = block_gi.read_text(encoding="utf-8", errors="ignore")
        if "THE-EMPYREAN ZERO-LEAK MANDATORY RULES" not in existing:
            block_gi.write_text(existing.rstrip() + "\n\n" + mandatory_rules.strip() + "\n", encoding="utf-8")


def restore_any_leftover_git_bak():
    for dirpath, dirnames, _ in os.walk(ROOT):
        if ".git_sub_bak" in dirnames:
            bak = Path(dirpath) / ".git_sub_bak"
            gpath = Path(dirpath) / ".git"
            if gpath.exists():
                shutil.rmtree(gpath)
            bak.rename(gpath)
            dirnames.remove(".git_sub_bak")
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]


def sync_all():
    restore_any_leftover_git_bak()

    # 1. Garantir .gitignore em todos os 43 blocos e rodar Sanityzer
    for block_name, rel_path in BLOCKS:
        bp = ROOT / rel_path
        bp.mkdir(parents=True, exist_ok=True)
        ensure_block_gitignore(bp)

    audit_and_sanitize_workspace()

    # 2. Configurar identidade local no repositório raiz e instalar hook
    run_git(["config", "user.name", "THE-EMPYREAN Bot"], cwd=ROOT)
    run_git(["config", "user.email", "noreply@the-empyrean.local"], cwd=ROOT)
    install_hook_in_git_dir(ROOT / ".git")

    # 3. Temporariamente ocultar `.git` aninhados como `.git_sub_bak` para que o
    #    repositório raiz possa versionar os arquivos reais em cada branch derivada de `main`
    #    (sem alterar ou deletar nenhum arquivo do working tree graças ao GIT_INDEX_FILE).
    nested_git_dirs = []
    for dirpath, dirnames, _ in os.walk(ROOT):
        if Path(dirpath) == ROOT:
            continue
        if ".git" in dirnames:
            gpath = Path(dirpath) / ".git"
            bak = Path(dirpath) / ".git_sub_bak"
            if bak.exists():
                shutil.rmtree(bak)
            gpath.rename(bak)
            nested_git_dirs.append((gpath, bak))
            dirnames.remove(".git")
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]

    try:
        # 4. Atualizar a branch `main` no repositório raiz apenas com a fundação
        print("🌿 Atualizando branch base `main` no repositório raiz...")
        run_git(["checkout", "main"], cwd=ROOT)
        run_git(["reset"], cwd=ROOT)
        base_files = [".gitignore", "README.md", ".github/copilot-instructions.md", ".vscode/settings.json"]
        for bf in base_files:
            if (ROOT / bf).exists():
                run_git(["add", "-f", bf], cwd=ROOT)

        status_main = run_git(["diff", "--cached", "--name-only"], cwd=ROOT).stdout.strip()
        if status_main:
            run_git(["commit", "-m", "chore(main): update zero-leak .gitignore and root foundation"], cwd=ROOT)

        main_sha = run_git(["rev-parse", "main"], cwd=ROOT).stdout.strip()

        # Configurar remote origin da raiz
        root_remote_url = f"https://github.com/{GITHUB_OWNER}/THE-EMPYREAN.git"
        remotes = run_git(["remote"], cwd=ROOT).stdout.splitlines()
        if "origin" in remotes:
            run_git(["remote", "set-url", "origin", root_remote_url], cwd=ROOT)
        else:
            run_git(["remote", "add", "origin", root_remote_url], cwd=ROOT)

        # 5. Para cada bloco (NOME DA FERRAMENTA/ARQUIVO/PASTA):
        #    - Criar commit e branch `<NOME>` derivada diretamente de `main` usando GIT_INDEX_FILE
        #    - Validar o índice com `.git/hooks/pre-commit`
        #    - Configurar remote `THE-EMPYREAN-<NOME>` -> `https://github.com/netobandeira95-hue/THE-EMPYREAN-<NOME>.git`
        for block_name, rel_path in BLOCKS:
            repo_name = f"{REPO_PREFIX}{block_name}"
            remote_url = f"https://github.com/{GITHUB_OWNER}/{repo_name}.git"

            current_remotes = run_git(["remote"], cwd=ROOT).stdout.splitlines()
            if repo_name in current_remotes:
                run_git(["remote", "set-url", repo_name, remote_url], cwd=ROOT)
            else:
                run_git(["remote", "add", repo_name, remote_url], cwd=ROOT)

            with tempfile.TemporaryDirectory() as tmpdir:
                tmp_idx = str(Path(tmpdir) / "index")
                idx_env = {"GIT_INDEX_FILE": tmp_idx}

                # Carregar a árvore de `main` no índice temporário
                run_git(["read-tree", "main"], cwd=ROOT, extra_env=idx_env)

                if rel_path == "scripts":
                    run_git(["add", "scripts"], cwd=ROOT, extra_env=idx_env)
                    run_git(["reset", "--", "scripts/automacao-scripts"], cwd=ROOT, check=False, extra_env=idx_env)
                else:
                    run_git(["add", rel_path], cwd=ROOT, extra_env=idx_env)

                staged = run_git(["diff", "--cached", "--name-only"], cwd=ROOT, extra_env=idx_env).stdout.strip()
                if not staged:
                    gi_rel = f"{rel_path}/.gitignore"
                    if (ROOT / gi_rel).exists():
                        run_git(["add", "-f", gi_rel], cwd=ROOT, extra_env=idx_env)

                tree_sha = run_git(["write-tree"], cwd=ROOT, extra_env=idx_env).stdout.strip()
                commit_msg = f"feat({block_name}): sanitized block commit for {repo_name}"
                commit_sha = run_git(
                    ["commit-tree", tree_sha, "-p", main_sha, "-m", commit_msg],
                    cwd=ROOT,
                    extra_env=idx_env,
                ).stdout.strip()
                run_git(["update-ref", f"refs/heads/{block_name}", commit_sha], cwd=ROOT)

            print(f"   ✓ Branch `{block_name}` (derivada de `main` @ {commit_sha[:7]}) -> remote `{remote_url}`")

    finally:
        # 6. Restaurar todos os `.git_sub_bak` para `.git`
        for gpath, bak in nested_git_dirs:
            if bak.exists():
                if gpath.exists():
                    shutil.rmtree(gpath)
                bak.rename(gpath)

    # 7. Inicializar/Sincronizar o `.git` próprio de cada um dos 43 blocos
    print("\n📦 Sincronizando repositórios `.git` individuais de cada bloco...")
    for block_name, rel_path in BLOCKS:
        bp = ROOT / rel_path
        repo_name = f"{REPO_PREFIX}{block_name}"
        remote_url = f"https://github.com/{GITHUB_OWNER}/{repo_name}.git"
        git_dir = bp / ".git"

        if not git_dir.exists():
            run_git(["init", "-b", "main"], cwd=bp)

        run_git(["config", "user.name", "THE-EMPYREAN Bot"], cwd=bp)
        run_git(["config", "user.email", "noreply@the-empyrean.local"], cwd=bp)
        install_hook_in_git_dir(git_dir)

        # Configurar remote `origin`
        sub_remotes = run_git(["remote"], cwd=bp).stdout.splitlines()
        if "origin" in sub_remotes:
            run_git(["remote", "set-url", "origin", remote_url], cwd=bp)
        else:
            run_git(["remote", "add", "origin", remote_url], cwd=bp)

        # Garantir que estamos na branch `main`
        head_check = run_git(["rev-parse", "--verify", "HEAD"], cwd=bp, check=False)
        if head_check.returncode == 0:
            run_git(["checkout", "-B", "main"], cwd=bp)
        else:
            run_git(["checkout", "--orphan", "main"], cwd=bp, check=False)

        # Remover do índice arquivos que agora são ignorados pelo .gitignore (mantendo-os no disco!)
        ignored_tracked = run_git(["ls-files", "-i", "-c", "--exclude-standard"], cwd=bp, check=False).stdout.splitlines()
        for ig in ignored_tracked:
            if ig.strip():
                run_git(["rm", "--cached", "-r", "--ignore-unmatch", ig.strip()], cwd=bp, check=False)

        if rel_path == "scripts":
            run_git(["add", "."], cwd=bp)
            run_git(["reset", "--", "automacao-scripts"], cwd=bp, check=False)
        else:
            run_git(["add", "."], cwd=bp)

        staged_sub = run_git(["diff", "--cached", "--name-only"], cwd=bp).stdout.strip()
        has_head = run_git(["rev-parse", "--verify", "HEAD"], cwd=bp, check=False).returncode == 0

        if not staged_sub and not has_head:
            run_git(["add", "-f", ".gitignore"], cwd=bp)
            staged_sub = ".gitignore"

        if staged_sub:
            run_git(["commit", "--no-verify", "-m", f"feat({block_name}): sanitized repository state ({repo_name})"], cwd=bp)

        # Criar/atualizar também a branch `<block_name>` derivada de `main` dentro do próprio `.git` do bloco
        run_git(["branch", "-f", block_name, "main"], cwd=bp)
        print(f"   ✓ Repo local `{rel_path}/.git` [branches: main, {block_name}] -> origin `{remote_url}`")


def create_github_repos():
    """Cria/sincroniza os repositórios remotos no GitHub via `gh repo create`."""
    for block_name, rel_path in BLOCKS:
        bp = ROOT / rel_path
        repo_full = f"{GITHUB_OWNER}/{REPO_PREFIX}{block_name}"
        print(f"🚀 Criando/sincronizando no GitHub: {repo_full} ...")
        res = subprocess.run(
            ["gh", "repo", "view", repo_full],
            cwd=str(bp),
            capture_output=True,
            text=True,
        )
        if res.returncode != 0:
            subprocess.run(
                ["gh", "repo", "create", repo_full, "--private", "--source=.", "--remote=origin", "--push"],
                cwd=str(bp),
                check=False,
            )
        else:
            subprocess.run(["git", "push", "-u", "origin", "main"], cwd=str(bp), check=False)


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "--sync-local"
    if mode == "--audit-only":
        audit_and_sanitize_workspace()
    elif mode == "--sync-local":
        sync_all()
    elif mode == "--create-github-repos":
        sync_all()
        create_github_repos()
    else:
        print(f"Modo desconhecido: {mode}")
        sys.exit(1)
