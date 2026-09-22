#!/usr/bin/env bash
# ==============================================================================
# LLM BACKUP & OFFLINE USB EXPORT/IMPORT SCRIPT
# ==============================================================================
set -euo pipefail

CACHE_DIR="/var/snap/lemonade-server/common/.cache/huggingface/hub"
LOCAL_BACKUP_DIR="${HOME}/LLM-backups"

usage() {
    echo "Usage: $0 [export <destination_dir> | import <source_dir> | sync-local]"
    echo ""
    echo "Commands:"
    echo "  export <dest>   Copy LLM models to USB or external path (checks available space)"
    echo "  import <src>    Import LLM models from USB into local Lemonade cache"
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
    
    mkdir -p "${target_dir}" 2>/dev/null || sudo mkdir -p "${target_dir}"
    local avail_gb
    avail_gb=$(df -BG "${target_dir}" | tail -n1 | awk '{print $4}' | sed 's/G//')
    
    echo "📊 Target directory: ${target_dir}"
    echo "💾 Available space: ${avail_gb} GB"
    echo "📦 Required space: ${required_gb} GB"
    
    if (( avail_gb < required_gb )); then
        echo "⚠️ WARNING: Available space (${avail_gb} GB) is less than required (${required_gb} GB)!"
        return 1
    fi
    return 0
}

case "${COMMAND}" in
    sync-local)
        echo "🚀 Syncing local Lemonade cache to ${LOCAL_BACKUP_DIR}..."
        mkdir -p "${LOCAL_BACKUP_DIR}"
        sudo rsync -avLP --human-readable "${CACHE_DIR}/" "${LOCAL_BACKUP_DIR}/"
        sudo chown -R "${USER}:${USER}" "${LOCAL_BACKUP_DIR}"
        echo "✅ Local backup updated in ${LOCAL_BACKUP_DIR}"
        ;;
        
    export)
        if [[ $# -lt 2 ]]; then
            echo "❌ Error: Destination path required for export."
            usage
        fi
        DEST_DIR="$2"
        echo "🔍 Evaluating models for export to ${DEST_DIR}..."
        
        # Calculate total size
        TOTAL_SIZE_GB=58
        if check_space "${DEST_DIR}" "${TOTAL_SIZE_GB}"; then
            echo "✅ Sufficient space available. Exporting ALL models (~58 GB)..."
            sudo rsync -avLP --human-readable "${LOCAL_BACKUP_DIR}/" "${DEST_DIR}/"
        else
            echo "⚡ Space is constrained. Offering 'Pack 32GB' (Gemma 4 12B + Qwen3.6 = ~18.8 GB)..."
            if check_space "${DEST_DIR}" "19"; then
                echo "🚀 Copying Pack 32GB (Gemma-4-12B + Qwen3.6)..."
                sudo rsync -avLP --human-readable \
                    "${LOCAL_BACKUP_DIR}/models--unsloth--gemma-4-12b-it-GGUF" \
                    "${LOCAL_BACKUP_DIR}/models--unsloth--Qwen3.6-35B-A3B-GGUF" \
                    "${DEST_DIR}/"
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
        echo "📥 Importing models from ${SRC_DIR} into Lemonade cache (${CACHE_DIR})..."
        sudo mkdir -p "${CACHE_DIR}"
        sudo rsync -avLP --human-readable "${SRC_DIR}/" "${CACHE_DIR}/"
        sudo systemctl restart lemonade.service 2>/dev/null || true
        echo "✅ Import completed & Lemonade service reloaded!"
        ;;

    *)
        usage
        ;;
esac
