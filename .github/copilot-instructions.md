# Instruções Personalizadas do Repositório — THE-EMPYREAN

> **Extensão de Referência:** `GitHub.copilot-chat` (https://marketplace.visualstudio.com/items?itemName=GitHub.copilot-chat)  
> **Guia Oficial:** https://docs.github.com/pt/copilot/get-started/best-practices  
> **Documentação Interna:** `docs/architecture/tools/copilot-best-practices.md`

## 1. Regra Soberana de Orquestração (Ollama Gatekeeper ➔ Agente Online)

1. **Prioridade Primária no Ollama (Agente Local Selecionado):**
   - Toda solicitação de código, refatoração, análise, debugging ou arquitetura deve ser avaliada e processada primeiramente pelo **Ollama** utilizando o **agente local selecionado** (`qwen2.5-coder:7b`, `qwen2.5-coder:1.5b`, `deepseek-r1:14b`, `gemma2:9b`, `llama3.2:3b`, `gpt-oss:20b` ou `minicpm-v:latest`).
2. **Acionamento Condicional do Agente Online:**
   - O **Agente Online** (GitHub Copilot Chat Cloud, Gemini Cloud ou Claude Cloud) **só deve ser acionado se o próprio Ollama (com o agente local selecionado) decidir ou necessitar escalar** (`[ESCALATE_ONLINE: <motivo>]` ou `needs_online_agent = True`).
   - O escalonamento ocorre apenas quando o agente local no Ollama determinar que:
     - O problema exige contexto ou conhecimento externo além da janela/base RAG local;
     - A pontuação de confiança/reflexão local (`reflection_score`) ficou abaixo de `7.0/10`;
     - A tarefa requer capacidades multimodais ou síntese em nuvem explicitamente sinalizada pelo agente local.
3. **Sanitização antes do Escalonamento (Zero-Leak):**
   - Quando o Ollama decidir acionar o Agente Online, jamais envie conteúdos de `.env`, chaves de API, certificados (`config/certs/`) ou dados pessoais/sensíveis (`data/raw/personal_vault/`).

## 2. Estrutura Oficial do Repositório (`/Volumes/THEEMPYREAN`)

Respeite estritamente a matriz organizacional na branch `main`:
- `apps/` — Aplicações desktop/mobile/web, frontends, IDEs e extensões VS Code/Antigravity.
- `packages/` — Bibliotecas, CLIs, gateways MCP (`cc-switch`, `context-mode`, `CLI-Anything`, `rea`, `mac-clean`).
- `services/` — APIs, microsserviços, backends, orquestrador multiagente e stacks de IA/RAG (`EMPYREAN MKT`, `project-nomad`, `litellm-proxy`, `multiagent-orchestrator`).
- `infra/` — Provisionamento e containers (`infra/docker/`, `infra/terraform/`, `infra/k8s/`).
- `data/` — Dados brutos (`data/raw/`), bases processadas/RAG (`data/processed/`) e pesos de modelos (`data/models/.ollama/`).
- `docs/` — Arquitetura (`docs/architecture/`) e roadmap (`docs/roadmap/`).
- `scripts/` — Scripts operacionais, autorouter (`scripts/autorouter.py`), controle (`scripts/control.py`), hooks e launchers `.command`.
- `templates/` — Protótipos, incubadora e templates reutilizáveis.
- `config/` — Certificados locais, configurações de editor e políticas.

## 3. Boas Práticas de Engenharia (GitHub Copilot Best Practices)

- **Escopo Limpo e Modular:** Divida alterações complexas em funções pequenas, testáveis e bem tipadas.
- **Gerenciadores de Pacotes:** Prefira `pnpm` para projetos Node.js/TypeScript e `uv` / `python3` com `.venv` para Python.
- **Segurança:** Nunca utilize `shell=True` com entradas não sanitizadas nem `eval()` arbitrário. Preserve comentários e docstrings relevantes existentes.
- **Validação:** Sempre revise e valide o código gerado com testes automatizados e análise estática antes de realizar commits.

