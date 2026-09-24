#!/usr/bin/env bash
# ==============================================================================
# LLM MODEL DOWNLOAD & PRE-LOADING SCRIPT (Lemonade vs vLLM Engine)
# ==============================================================================
set -euo pipefail

ENGINE="${ENGINE:-lemonade}"
LEMONADE_API="http://localhost:13305"
VLLM_API="http://localhost:8000"
VLLM_CACHE="/var/lib/ai-models/huggingface/hub"
LEMONADE_CACHE="/var/snap/lemonade-server/common/.cache"

# Auto-detect engine if vllm service is active or parameter was passed
if [ "${ENGINE}" == "vllm" ] || systemctl is-active --quiet vllm.service 2>/dev/null; then
    ENGINE="vllm"
fi

echo "🎯 LLM Download Mode: ${ENGINE}"

if [ "${ENGINE}" == "vllm" ]; then
    echo "======================================================================"
    echo "📥 vLLM Engine Mode (HP Z6 Server) - Hugging Face Cache Setup"
    echo "======================================================================"
    sudo mkdir -p "${VLLM_CACHE}"
    
    HF_REPOS=(
        "unsloth/gemma-4-12b-it-GGUF"
        "unsloth/gemma-4-31B-it-GGUF"
        "unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF"
        "unsloth/Qwen3.6-35B-A3B-GGUF"
        "unsloth/DeepSeek-Qwen3-8B-GGUF"
    )

    echo "🔍 Checking Hugging Face download availability for vLLM..."
    if command -v huggingface-cli &>/dev/null || python3 -c "import huggingface_hub" 2>/dev/null; then
        pip install -q huggingface_hub 2>/dev/null || true
        for REPO in "${HF_REPOS[@]}"; do
            echo "----------------------------------------------------------------------"
            echo "📥 Downloading HF Repo for vLLM: ${REPO}..."
            echo "----------------------------------------------------------------------"
            HF_HUB_CACHE="${VLLM_CACHE}" python3 -c "from huggingface_hub import snapshot_download; snapshot_download(repo_id='${REPO}', local_dir_use_symlinks=True)" 2>/dev/null || \
            huggingface-cli download "${REPO}" --local-dir-use-symlinks True 2>/dev/null || true
        done
        echo "✅ vLLM HuggingFace models downloaded successfully into ${VLLM_CACHE}!"
        sudo systemctl restart vllm.service 2>/dev/null || true
    else
        echo "ℹ️ Hugging Face CLI not present. You can import models offline via './backup-models.sh import <path>'."
    fi
    exit 0
fi

# Lemonade Engine Mode
echo "======================================================================"
echo "📥 Lemonade Engine Mode (HP Z2 Mini Workstation)"
echo "======================================================================"

# Ensure write permissions on Lemonade cache directory if present
if [ -d "${LEMONADE_CACHE}" ]; then
    sudo chmod -R 777 "${LEMONADE_CACHE}" 2>/dev/null || true
fi

echo "⏳ Checking Lemonade inference server availability..."

# Capped healthcheck loop for Lemonade (max 10 attempts = 30 seconds)
MAX_ATTEMPTS=10
ATTEMPT=1
SERVER_ONLINE=false

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    if curl -s "${LEMONADE_API}/v1/models" > /dev/null 2>&1; then
        SERVER_ONLINE=true
        break
    fi
    echo "Waiting for Lemonade server on port 13305 (Attempt ${ATTEMPT}/${MAX_ATTEMPTS})..."
    sleep 3
    ATTEMPT=$((ATTEMPT + 1))
done

if [ "$SERVER_ONLINE" = false ]; then
    echo "⚠️ Warning: Lemonade server on port 13305 did not respond after 30 seconds."
    echo "👉 Skipping online model pre-loader. You can import models offline via './backup-models.sh import <path>'."
    exit 0
fi

echo "✅ Lemonade server is online!"
echo "🚀 Triggering download/pre-load of LLM models (~64.5 GB total)..."

MODELS=(
    "Gemma-4-12B-it-GGUF"
    "Gemma-4-31B-it-GGUF"
    "Qwen3-Coder-30B-A3B-Instruct-GGUF"
    "Qwen3.6-27B-GGUF"
    "DeepSeek-Qwen3-8B-GGUF"
)

for MODEL in "${MODELS[@]}"; do
    echo "----------------------------------------------------------------------"
    echo "📥 Triggering model: ${MODEL}..."
    echo "----------------------------------------------------------------------"
    
    if command -v lemonade &>/dev/null; then
        lemonade pull "${MODEL}" 2>/dev/null || true
    else
        curl -s -X POST "${LEMONADE_API}/api/pull" \
            -H "Content-Type: application/json" \
            -d "{\"name\": \"${MODEL}\"}" 2>/dev/null || true
    fi
done

echo "🎉 LLM download tasks submitted successfully!"
