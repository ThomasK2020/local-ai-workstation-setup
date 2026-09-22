#!/usr/bin/env bash
# ==============================================================================
# LLM MODEL DOWNLOAD & PRE-LOADING SCRIPT (Lemonade API)
# ==============================================================================
set -euo pipefail

LEMONADE_API="http://localhost:13305"

echo "⏳ Checking Lemonade server availability..."
until curl -s "${LEMONADE_API}/v1/models" > /dev/null 2>&1; do
    echo "Waiting for Lemonade server to start..."
    sleep 3
done

echo "✅ Lemonade server is online!"
echo "🚀 Triggering download of all 5 LLM models (~64.5 GB total)..."

MODELS=(
    "Gemma-4-12B-it-GGUF"
    "Gemma-4-31B-it-GGUF"
    "Qwen3-Coder-30B-A3B-Instruct-GGUF"
    "Qwen3.6-27B-GGUF"
    "DeepSeek-Qwen3-8B-GGUF"
)

for MODEL in "${MODELS[@]}"; do
    echo "----------------------------------------------------------------------"
    echo "📥 Downloading model: ${MODEL}..."
    echo "----------------------------------------------------------------------"
    
    if command -v lemonade &>/dev/null; then
        lemonade pull "${MODEL}" || true
    else
        curl -s -X POST "${LEMONADE_API}/api/pull" \
            -H "Content-Type: application/json" \
            -d "{\"name\": \"${MODEL}\"}" || true
    fi
done

echo "🎉 LLM download tasks submitted successfully!"
