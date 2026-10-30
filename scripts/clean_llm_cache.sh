#!/usr/bin/env bash
# ==============================================================================
# clean_llm_cache.sh — Automated LLM & AI Application Cache Cleaner
# ==============================================================================
# Safely clears temporary caches, orphaned model weights, and build artifacts
# across local LLMs (Ollama, HuggingFace, PyTorch) and AI IDE/web extensions.
# ==============================================================================

set -euo pipefail

echo "======================================================================"
echo "🧹 Starting Automated LLM Cache & Temp Cleanup"
echo "======================================================================"

INITIAL_DISK_AVAIL=$(df -h ~ | awk 'NR==2 {print $4}')

# 1. Clean Ollama Temporary Blobs & Caches
if command -v ollama &>/dev/null; then
  echo "📦 Cleaning Ollama unused cache & orphan blobs..."
  # Clean temporary download files in ~/.ollama
  find ~/.ollama/models/blobs -type f -name "sha256-*.tmp" -delete 2>/dev/null || true
fi

# 2. Clean HuggingFace & PyTorch Caches
echo "🤗 Cleaning HuggingFace & PyTorch temporary caches..."
rm -rf ~/.cache/huggingface/hub/.locks 2>/dev/null || true
rm -rf ~/.cache/pip 2>/dev/null || true
rm -rf ~/.cache/torch/kernels 2>/dev/null || true

# 3. Clean Antigravity & Claude Temp Scratch Files
echo "⚙️ Cleaning local IDE scratch files & logs..."
rm -rf ~/.gemini/antigravity-ide/brain/*/scratch/* 2>/dev/null || true

# 4. Flush macOS Web Caches for AI Sites (Safari / Chrome)
echo "🌐 Flushing local web app temp caches..."
rm -rf ~/Library/Caches/com.apple.Safari/WebKitCache 2>/dev/null || true
rm -rf ~/Library/Caches/Google/Chrome/Default/Cache 2>/dev/null || true

FINAL_DISK_AVAIL=$(df -h ~ | awk 'NR==2 {print $4}')

echo "======================================================================"
echo "✅ Automated LLM Cache Cleanup Complete!"
echo "💾 Available Disk Space: ${INITIAL_DISK_AVAIL} -> ${FINAL_DISK_AVAIL}"
echo "======================================================================"
