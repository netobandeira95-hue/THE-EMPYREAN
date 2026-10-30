#!/usr/bin/env python3
"""
==============================================================================
THE-EMPYREAN — Motor de Orquestração e Autorouting (Ollama-First + Escalonamento Soberano)
Compatível com: GitHub Copilot Chat (GitHub.copilot-chat), Continue, VISU, RB Ollama
Volume Base: /Volumes/THEEMPYREAN
Diretriz Soberana:
  1. O Ollama (com o agente local selecionado) é SEMPRE acionado primeiro.
  2. O Agente Online (Copilot Chat / Cloud via LiteLLM) SÓ é acionado se o
     próprio Ollama (com o agente local selecionado) decidir ou necessitar
     escalar (via marcador [ESCALATE_ONLINE: <motivo>] ou tool escalate_online).
==============================================================================
"""

import json
import math
import os
import re
import subprocess
import urllib.request
from dataclasses import dataclass, asdict
from http.server import BaseHTTPRequestHandler, HTTPServer
from typing import Dict, List, Optional, Tuple

# ==============================================================================
# 1. CONFIGURAÇÕES E CATÁLOGO DE MODELOS LOCAIS (OLLAMA) E ONLINE (SOB DEMANDA)
# ==============================================================================

THE_EMPYREAN_ROOT = "/Volumes/THEEMPYREAN"
VLLM_MANAGER_SCRIPT = os.path.join(os.path.dirname(__file__), "vllm_manager.sh")

VLLM_ENDPOINT = os.environ.get("VLLM_ENDPOINT", "http://localhost:8000/v1")
OLLAMA_ENDPOINT = os.environ.get("OLLAMA_ENDPOINT", "http://localhost:11434")
LITELLM_ONLINE_ENDPOINT = os.environ.get("LITELLM_ONLINE_ENDPOINT", "http://localhost:4000/v1")
LITELLM_API_KEY = os.environ.get("LITELLM_API_KEY", "sk-local-proxy")
ONLINE_FALLBACK_MODEL = os.environ.get("ONLINE_FALLBACK_MODEL", "github-copilot-chat")
VRAM_BUDGET_GB = float(os.environ.get("VRAM_BUDGET_GB", "16.0"))

# Descarrega o modelo da RAM/VRAM logo após responder se AUTO_UNLOAD_AFTER_CALL=1
AUTO_UNLOAD_AFTER_CALL = os.environ.get("AUTO_UNLOAD_AFTER_CALL", "1") == "1"

# Regex para detectar se o agente local no Ollama decidiu/necessitou acionar o agente online
ESCALATE_ONLINE_PATTERN = re.compile(
    r"\[ESCALATE_ONLINE(?::\s*([^\]]+))?\]",
    re.IGNORECASE,
)

# Instrução injetada no sistema do agente Ollama para que ele saiba que pode decidir escalar
OLLAMA_GATEKEEPER_SYSTEM_PROMPT = (
    "Você é o agente local primário no Ollama do ecossistema THE-EMPYREAN. "
    "Resolva a tarefa localmente sempre que tiver contexto e capacidade suficientes. "
    "Se, e somente se, você avaliar que a tarefa exige conhecimento externo ao vivo, "
    "capacidade multimodal em nuvem ou contexto além do limite local, inicie ou finalize "
    "sua resposta com a tag exata [ESCALATE_ONLINE: <motivo objetivo>] para acionar o Agente Online."
)

# Catálogo Local no Ollama (mapeado aos modelos em /Volumes/THEEMPYREAN/data/models)
LOCAL_MODEL_TIERS = {
    # TIER 1: Autocomplete e Respostas Instantâneas (Leves)
    "qwen2.5-coder:1.5b": {
        "tier": "instant_autocomplete",
        "engine": "ollama",
        "ollama_tag": "qwen2.5-coder:1.5b",
        "vram_required_gb": 1.2,
        "role": ["autocomplete", "instant"],
    },
    "llama3.2:3b": {
        "tier": "instant_autocomplete",
        "engine": "ollama",
        "ollama_tag": "llama3.2:3b",
        "vram_required_gb": 2.2,
        "role": ["instant", "fast_chat"],
    },
    # TIER 2: Código, Chat e Refatoração Diária (Média Escala)
    "qwen2.5:7b": {
        "tier": "daily_coding_chat",
        "engine": "ollama",
        "ollama_tag": "qwen2.5:7b",
        "vram_required_gb": 5.0,
        "role": ["chat", "coding", "refactor"],
    },
    "qwen2.5-coder:7b": {
        "tier": "daily_coding_chat",
        "engine": "ollama",
        "ollama_tag": "qwen2.5-coder:7b",
        "vram_required_gb": 5.0,
        "role": ["chat", "coding", "refactor"],
    },
    "gemma2:9b": {
        "tier": "daily_coding_chat",
        "engine": "ollama",
        "ollama_tag": "gemma2:9b",
        "vram_required_gb": 5.8,
        "role": ["chat", "coding"],
    },
    "phi4:14b": {
        "tier": "daily_coding_chat",
        "engine": "ollama",
        "ollama_tag": "phi4:14b",
        "vram_required_gb": 9.5,
        "role": ["chat", "coding", "refactor"],
    },
    "gpt-oss-20b": {
        "tier": "documents_rag_context",
        "engine": "ollama",
        "hf_id": "openai/gpt-oss-20b",
        "ollama_tag": "gpt-oss:20b",
        "vram_required_gb": 13.0,
        "role": ["documents", "rag", "json", "chat", "coding"],
    },
    "minicpm-v:latest": {
        "tier": "vision_ocr",
        "engine": "ollama",
        "ollama_tag": "minicpm-v:latest",
        "vram_required_gb": 5.5,
        "role": ["vision", "ocr", "images"],
    },
    "qwen-3.6": {
        "tier": "general_qa",
        "engine": "ollama",
        "ollama_tag": "qwen2.5:7b",
        "vram_required_gb": 4.7,
        "role": ["qa", "chat", "multilingual"],
    },
    "gemma-4": {
        "tier": "general_qa",
        "engine": "ollama",
        "ollama_tag": "gemma2:9b",
        "vram_required_gb": 5.4,
        "role": ["qa", "chat"],
    },
    # TIER 3: Raciocínio Profundo / Lógica (Chain-of-Thought)
    "deepseek-r1:8b": {
        "tier": "deep_reasoning_cot",
        "engine": "ollama",
        "ollama_tag": "deepseek-r1:8b",
        "vram_required_gb": 5.5,
        "role": ["reasoning", "architecture", "debug"],
    },
    "deepseek-r1:14b": {
        "tier": "deep_reasoning_cot",
        "engine": "ollama",
        "ollama_tag": "deepseek-r1:14b",
        "vram_required_gb": 9.5,
        "role": ["reasoning", "architecture", "complex_cot"],
    },
}

# Bloqueio de fine-tunes não autorizados
FORBIDDEN_FINETUNE = re.compile(
    r"(abliterated|uncensored|dolphin|hermes)",
    re.IGNORECASE,
)


def validate_selected_model(model_name: str) -> Tuple[bool, str]:
    """Garante que a seleção inicial passe pelo agente local no Ollama."""
    if not model_name:
        return True, "auto"

    if FORBIDDEN_FINETUNE.search(model_name):
        return (
            False,
            f"BLOQUEADO: '{model_name}' utiliza fine-tune não oficial proibido.",
        )

    normalized = model_name.lower().strip()
    if normalized in ("auto", "local", "instant", "coding", "reasoning"):
        return True, normalized

    if normalized in LOCAL_MODEL_TIERS:
        return True, normalized

    # Se alguém tentar chamar um modelo online diretamente sem passar pelo Ollama,
    # roteamos primeiro para o agente local no Ollama para que ELE decida se precisa escalar.
    return True, "auto"


@dataclass
class LocalRoutingDecision:
    task_tier: str
    input_tokens: int
    selected_model: str
    engine: str
    vram_estimated_gb: float
    cpu_offload_gb: float
    auto_unload_after: bool
    cost_usd: float
    reason: str
    escalated_to_online: bool = False
    escalation_reason: Optional[str] = None
    online_model_used: Optional[str] = None


def estimate_tokens(messages: List[Dict], prompt: str = "") -> int:
    raw_text = prompt or ""
    for msg in messages or []:
        content = msg.get("content", "")
        if isinstance(content, list):
            content = " ".join(p.get("text", "") for p in content if isinstance(p, dict))
        raw_text += f"\n{content}"
    if not raw_text.strip():
        return 1
    return max(1, math.ceil(len(raw_text) / 3.7))


def route_local_task(
    messages: List[Dict],
    prompt: str = "",
    max_tokens: Optional[int] = None,
    requested_model: str = "auto",
) -> LocalRoutingDecision:
    valid, canonical = validate_selected_model(requested_model)
    if not valid:
        raise ValueError(canonical)

    input_tokens = estimate_tokens(messages, prompt)
    combined_text = (prompt + " " + " ".join(str(m.get("content", "")) for m in (messages or []))).lower()

    if canonical in LOCAL_MODEL_TIERS:
        meta = LOCAL_MODEL_TIERS[canonical]
        offload = max(0.0, round(meta["vram_required_gb"] - (VRAM_BUDGET_GB * 0.85), 1))
        return LocalRoutingDecision(
            task_tier=meta["tier"],
            input_tokens=input_tokens,
            selected_model=canonical,
            engine=meta["engine"],
            vram_estimated_gb=meta["vram_required_gb"],
            cpu_offload_gb=offload,
            auto_unload_after=AUTO_UNLOAD_AFTER_CALL and meta["tier"] != "instant_autocomplete",
            cost_usd=0.0,
            reason=f"Agente local Ollama selecionado ({canonical}) — avalia necessidade de escalonamento.",
        )

    if (max_tokens is not None and max_tokens <= 256) or canonical == "instant":
        chosen = "qwen2.5-coder:1.5b" if prompt or "def " in combined_text or "function" in combined_text else "llama3.2:3b"
        meta = LOCAL_MODEL_TIERS[chosen]
        return LocalRoutingDecision(
            task_tier="instant_autocomplete",
            input_tokens=input_tokens,
            selected_model=chosen,
            engine=meta["engine"],
            vram_estimated_gb=meta["vram_required_gb"],
            cpu_offload_gb=0.0,
            auto_unload_after=False,
            cost_usd=0.0,
            reason=f"Autocomplete / Resposta Instantânea -> agente local ({chosen}).",
        )

    cot_keywords = (
        "raciocínio", "passo a passo", "step by step", "arquitetura", "complexo",
        "algoritmo", "prova", "otimize", "root cause", "debug profundo", "cot",
        "por que está falhando", "analise profundamente",
    )
    if canonical == "reasoning" or input_tokens > 3000 or any(kw in combined_text for kw in cot_keywords):
        chosen = "deepseek-r1:14b" if VRAM_BUDGET_GB >= 16.0 else "deepseek-r1:8b"
        meta = LOCAL_MODEL_TIERS[chosen]
        return LocalRoutingDecision(
            task_tier="deep_reasoning_cot",
            input_tokens=input_tokens,
            selected_model=chosen,
            engine=meta["engine"],
            vram_estimated_gb=meta["vram_required_gb"],
            cpu_offload_gb=0.0,
            auto_unload_after=True,
            cost_usd=0.0,
            reason=f"Raciocínio Profundo / Lógica (CoT) -> agente local ({chosen}).",
        )

    chosen = "qwen2.5-coder:7b"
    meta = LOCAL_MODEL_TIERS[chosen]
    return LocalRoutingDecision(
        task_tier="daily_coding_chat",
        input_tokens=input_tokens,
        selected_model=chosen,
        engine=meta["engine"],
        vram_estimated_gb=meta["vram_required_gb"],
        cpu_offload_gb=0.0,
        auto_unload_after=AUTO_UNLOAD_AFTER_CALL,
        cost_usd=0.0,
        reason=f"Código, Chat e Refatoração Diária -> agente local ({chosen}).",
    )


class LocalMemoryManager:
    @staticmethod
    def list_loaded_ollama_models() -> List[str]:
        try:
            req = urllib.request.Request(f"{OLLAMA_ENDPOINT}/api/ps", method="GET")
            with urllib.request.urlopen(req, timeout=3) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                return [m.get("name") for m in data.get("models", []) if m.get("name")]
        except Exception:
            return []

    @classmethod
    def unload_ollama_model(cls, model_tag: str) -> None:
        try:
            payload = json.dumps({"model": model_tag, "keep_alive": 0}).encode("utf-8")
            req = urllib.request.Request(
                f"{OLLAMA_ENDPOINT}/api/generate",
                data=payload,
                headers={"Content-Type": "application/json"},
                method="POST",
            )
            urllib.request.urlopen(req, timeout=5).read()
        except Exception:
            pass

    @classmethod
    def unload_other_models_before_call(cls, target_tag: str) -> None:
        for loaded in cls.list_loaded_ollama_models():
            if loaded != target_tag:
                cls.unload_ollama_model(loaded)

    @staticmethod
    def stop_vllm() -> None:
        if os.path.exists(VLLM_MANAGER_SCRIPT):
            subprocess.run(["bash", VLLM_MANAGER_SCRIPT, "stop"], check=False)


def evaluate_ollama_escalation_decision(local_content: str) -> Tuple[bool, Optional[str]]:
    """
    Verifica se o agente local no Ollama decidiu ou necessitou acionar o Agente Online.
    Retorna (precisa_escalar, motivo).
    """
    if not local_content:
        return True, "Resposta local vazia do agente Ollama."

    match = ESCALATE_ONLINE_PATTERN.search(local_content)
    if match:
        reason = (match.group(1) or "Solicitado pelo agente local no Ollama").strip()
        return True, reason

    return False, None


def execute_online_escalation(
    decision: LocalRoutingDecision,
    messages: List[Dict],
    local_draft: str,
    escalation_reason: str,
    online_model: str = ONLINE_FALLBACK_MODEL,
) -> Dict:
    """
    Aciona o Agente Online SOMENTE após decisão explícita do agente local no Ollama.
    """
    decision.escalated_to_online = True
    decision.escalation_reason = escalation_reason
    decision.online_model_used = online_model

    enriched_messages = list(messages)
    enriched_messages.append(
        {
            "role": "system",
            "content": (
                f"[Escalonamento autorizado pelo Agente Ollama ({decision.selected_model})]\n"
                f"Motivo da decisão local: {escalation_reason}\n"
                f"Análise preliminar local:\n{local_draft}"
            ),
        }
    )

    payload = {
        "model": online_model,
        "messages": enriched_messages,
        "stream": False,
    }
    req = urllib.request.Request(
        f"{LITELLM_ONLINE_ENDPOINT}/chat/completions",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {LITELLM_API_KEY}",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=180) as resp:
        online_result = json.loads(resp.read().decode("utf-8"))
        online_result["ia_infra_routing"] = asdict(decision)
        return online_result


def execute_local_inference(decision: LocalRoutingDecision, body: Dict) -> Dict:
    meta = LOCAL_MODEL_TIERS[decision.selected_model]

    if decision.engine == "ollama":
        target_tag = meta["ollama_tag"]
        LocalMemoryManager.unload_other_models_before_call(target_tag)
        keep_alive_val = "0s" if decision.auto_unload_after else "5m"

        raw_messages = body.get("messages") or [{"role": "user", "content": body.get("prompt", "")}]
        messages = [{"role": "system", "content": OLLAMA_GATEKEEPER_SYSTEM_PROMPT}] + list(raw_messages)

        ollama_chat_payload = {
            "model": target_tag,
            "messages": messages,
            "stream": False,
            "keep_alive": keep_alive_val,
        }
        req = urllib.request.Request(
            f"{OLLAMA_ENDPOINT}/api/chat",
            data=json.dumps(ollama_chat_payload).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=180) as resp:
            raw = json.loads(resp.read().decode("utf-8"))

        assistant_msg = raw.get("message", {"role": "assistant", "content": ""})
        local_content = assistant_msg.get("content", "")

        # Verifica se o agente selecionado no Ollama decidiu/necessitou acionar o agente online
        should_escalate, esc_reason = evaluate_ollama_escalation_decision(local_content)
        if should_escalate and esc_reason:
            try:
                online_model = body.get("online_model", ONLINE_FALLBACK_MODEL)
                return execute_online_escalation(
                    decision=decision,
                    messages=raw_messages,
                    local_draft=local_content,
                    escalation_reason=esc_reason,
                    online_model=online_model,
                )
            except Exception as online_err:
                # Se o endpoint online não estiver acessível no momento, preserva a resposta local + aviso
                assistant_msg["content"] = (
                    f"{local_content}\n\n"
                    f"> [Nota do Autorouter]: O agente local ({decision.selected_model}) solicitou "
                    f"escalonamento para o Agente Online ({esc_reason}), porém o gateway online "
                    f"não pôde ser contatado ({online_err}). Exibindo resposta local."
                )

        return {
            "id": f"local-{int(os.times().elapsed * 1000)}",
            "object": "chat.completion",
            "model": decision.selected_model,
            "choices": [
                {
                    "index": 0,
                    "message": assistant_msg,
                    "finish_reason": "stop",
                }
            ],
            "usage": {
                "prompt_tokens": raw.get("prompt_eval_count", decision.input_tokens),
                "completion_tokens": raw.get("eval_count", 0),
                "total_tokens": raw.get("prompt_eval_count", decision.input_tokens) + raw.get("eval_count", 0),
            },
            "ia_infra_routing": asdict(decision),
        }

    if decision.engine == "vllm":
        for loaded in LocalMemoryManager.list_loaded_ollama_models():
            LocalMemoryManager.unload_ollama_model(loaded)

        offload_int = max(4, int(math.ceil(decision.cpu_offload_gb)))
        if os.path.exists(VLLM_MANAGER_SCRIPT):
            subprocess.run(
                ["bash", VLLM_MANAGER_SCRIPT, "start", meta["hf_id"], "4096", "0.85", str(offload_int)],
                check=False,
            )

        vllm_body = dict(body)
        vllm_body["model"] = meta["hf_id"]
        vllm_body["stream"] = False
        req = urllib.request.Request(
            f"{VLLM_ENDPOINT}/chat/completions",
            data=json.dumps(vllm_body).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=180) as resp:
                result = json.loads(resp.read().decode("utf-8"))
                result["ia_infra_routing"] = asdict(decision)
                return result
        finally:
            if decision.auto_unload_after:
                LocalMemoryManager.stop_vllm()

    raise RuntimeError(f"Engine local inválido: {decision.engine}")


class LocalAutorouterHandler(BaseHTTPRequestHandler):
    def _send_json(self, status: int, payload: Dict) -> None:
        body = json.dumps(payload, ensure_ascii=False, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        if self.path.startswith("/v1/models"):
            models = [
                {"id": k, "object": "model", "owned_by": "the-empyrean-ollama", "metadata": v}
                for k, v in LOCAL_MODEL_TIERS.items()
            ]
            self._send_json(200, {"object": "list", "data": models})
            return

        if self.path.startswith("/health"):
            self._send_json(200, {
                "status": "ok",
                "policy": "OLLAMA_FIRST_ONLINE_IF_OLLAMA_DECIDES",
                "loaded_ollama_models": LocalMemoryManager.list_loaded_ollama_models(),
                "volume": THE_EMPYREAN_ROOT,
            })
            return

        self._send_json(404, {"error": "Endpoint não encontrado."})

    def do_POST(self) -> None:
        length = int(self.headers.get("Content-Length", "0"))
        raw_body = self.rfile.read(length).decode("utf-8") if length > 0 else "{}"
        try:
            body = json.loads(raw_body)
        except json.JSONDecodeError:
            self._send_json(400, {"error": "JSON inválido."})
            return

        requested_model = body.get("model", "auto")
        messages = body.get("messages", [])
        prompt = body.get("prompt", "")
        max_tokens = body.get("max_tokens")

        try:
            decision = route_local_task(messages, prompt, max_tokens, requested_model)
        except ValueError as err:
            self._send_json(403, {"error": {"message": str(err), "type": "policy_violation"}})
            return

        if self.path.startswith("/v1/route/evaluate") or body.get("dry_run"):
            self._send_json(200, {"routing_decision": asdict(decision)})
            return

        try:
            result = execute_local_inference(decision, body)
            self._send_json(200, result)
        except Exception as exc:
            self._send_json(502, {
                "error": {
                    "message": f"Erro na execução ({decision.selected_model}): {exc}",
                    "routing_decision": asdict(decision),
                }
            })


if __name__ == "__main__":
    port = int(os.environ.get("AUTOROUTER_PORT", "8080"))
    print(
        f"🚀 THE-EMPYREAN Autorouter (Ollama-First -> Online se Ollama decidir) "
        f"ativo em http://localhost:{port}/v1"
    )
    server = HTTPServer(("127.0.0.1", port), LocalAutorouterHandler)
    server.serve_forever()
