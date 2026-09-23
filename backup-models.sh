#!/usr/bin/env bash
# ==============================================================================
# LLM BACKUP & OFFLINE USB EXPORT/IMPORT SCRIPT
# ==============================================================================
set -euo pipefail

LEMONADE_CACHE="/var/snap/lemonade-server/common/.cache/huggingface/hub"
VLLM_CACHE="/var/lib/ai-models/huggingface/hub"
LOCAL_BACKUP_DIR="${HOME}/LLM-backups"

usage() {
    echo "Usage: $0 [export <destination_dir> | import <source_dir> | sync-local]"
    echo ""
    echo "Commands:"
    echo "  export <dest>   Copy LLM models to USB or external path (checks available space)"
    echo "  import <src>    Import LLM models from USB into local engine cache (Lemonade or vLLM)"
    echo "  sync-local      Backup local Lemonade cache to ${LOCAL_BACKUP_DIR}"
    exit 1
}

if [[ $# -lt 1 ]]; then
    usage
fi

COMMAND="$1"

check_space() {
    local target_dir="$1"
    local required_gb="$2"
    
    mkdir -p "${target_dir}" 2>/dev/null || sudo mkdir -p "${target_dir}" 2>/dev/null || true
    
    local avail_gb
    avail_gb=$(df -BG "${target_dir}" | tail -n1 | awk '{print $4}' | sed 's/G//')
    
    # Calculate space already occupied by existing backups in target_dir
    local existing_bytes=0
    if [ -d "${target_dir}" ]; then
        existing_bytes=$(du -sb "${target_dir}" 2>/dev/null | awk '{print $1}' || echo 0)
    fi
    local existing_gb=$(( existing_bytes / 1073741824 ))
    local effective_gb=$(( avail_gb + existing_gb ))

    echo "📊 Target directory: ${target_dir}"
    echo "💾 Available free space: ${avail_gb} GB (Effective space with existing files: ${effective_gb} GB)"
    echo "📦 Required space: ${required_gb} GB"
    
    if (( effective_gb < required_gb )); then
        echo "⚠️ WARNING: Effective space (${effective_gb} GB) is less than required (${required_gb} GB)!"
        return 1
    fi
    return 0
}

case "${COMMAND}" in
    sync-local)
        echo "🚀 Syncing local Lemonade cache to ${LOCAL_BACKUP_DIR}..."
        mkdir -p "${LOCAL_BACKUP_DIR}"
        
        SRC_CACHE="${LEMONADE_CACHE}"
        if [ ! -d "${SRC_CACHE}" ] && [ -d "${VLLM_CACHE}" ]; then
            SRC_CACHE="${VLLM_CACHE}"
        fi
        
        rsync -avLP --human-readable "${SRC_CACHE}/" "${LOCAL_BACKUP_DIR}/" 2>/dev/null || sudo rsync -avLP --human-readable "${SRC_CACHE}/" "${LOCAL_BACKUP_DIR}/"
        echo "✅ Local backup updated in ${LOCAL_BACKUP_DIR}"
        ;;
        
    export)
        if [[ $# -lt 2 ]]; then
            echo "❌ Error: Destination path required for export."
            usage
        fi
        DEST_DIR="$2"
        echo "🔍 Evaluating models for export to ${DEST_DIR}..."
        
        TOTAL_SIZE_GB=58
        if check_space "${DEST_DIR}" "${TOTAL_SIZE_GB}"; then
            echo "✅ Sufficient space available. Exporting ALL models (~58 GB)..."
            rsync -avLP --human-readable "${LOCAL_BACKUP_DIR}/" "${DEST_DIR}/" 2>/dev/null || sudo rsync -avLP --human-readable "${LOCAL_BACKUP_DIR}/" "${DEST_DIR}/"
        else
            echo "⚡ Space is constrained. Offering 'Pack 32GB' (Gemma 4 12B + Qwen3.6 = ~18.8 GB)..."
            if check_space "${DEST_DIR}" "19"; then
                echo "🚀 Copying Pack 32GB (Gemma-4-12B + Qwen3.6)..."
                rsync -avLP --human-readable \
                    "${LOCAL_BACKUP_DIR}/models--unsloth--gemma-4-12b-it-GGUF" \
                    "${LOCAL_BACKUP_DIR}/models--unsloth--Qwen3.6-35B-A3B-GGUF" \
                    "${DEST_DIR}/"
                sync
                echo "✅ Pack 32GB exported successfully!"
            else
                echo "❌ Error: Not enough space on target device even for Pack 32GB."
                exit 1
            fi
        fi
        ;;

    import)
        if [[ $# -lt 2 ]]; then
            echo "❌ Error: Source path required for import."
            usage
        fi
        SRC_DIR="$2"
        
        # Auto-detect whether target machine runs vLLM or Lemonade
        if systemctl is-active --quiet vllm.service 2>/dev/null; then
            TARGET_CACHE="${VLLM_CACHE}"
            echo "📥 Machine target mode: vLLM Server (HP Z6)."
            echo "📥 Importing models into vLLM cache (${TARGET_CACHE})..."
            sudo mkdir -p "${TARGET_CACHE}"
            sudo rsync -avLP --human-readable "${SRC_DIR}/" "${TARGET_CACHE}/"
            sudo systemctl restart vllm.service 2>/dev/null || true
            echo "✅ Import completed & vLLM service reloaded!"
        else
            TARGET_CACHE="${LEMONADE_CACHE}"
            echo "📥 Machine target mode: Lemonade Workstation (HP Z2 Mini)."
            echo "📥 Importing models into Lemonade cache (${TARGET_CACHE})..."
            sudo mkdir -p "${TARGET_CACHE}"
            sudo rsync -avLP --human-readable "${SRC_DIR}/" "${TARGET_CACHE}/"
            sudo systemctl restart snap.lemonade-server.daemon.service 2>/dev/null || sudo systemctl restart lemonade.service 2>/dev/null || sudo snap restart lemonade-server 2>/dev/null || true
            echo "✅ Import completed & Lemonade service reloaded!"
        fi
        ;;

    *)
        usage
        ;;
esac
