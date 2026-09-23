#!/usr/bin/env bash
# ==============================================================================
# DEPLOY-HERMES-PERSO-DATA.SH
# Synchronisation Ultra-Légère : GitHub (Configs/Memories) + USB (DB + Skills)
# ==============================================================================
set -euo pipefail

HERMES_DIR="${HOME}/.hermes"
REPO_URL="https://github.com/ThomasK2020/TK-Hermes-data.git"

usage() {
    echo "Usage: $0 [export | restore]"
    echo ""
    echo "Commands:"
    echo "  export   Copy state.db & skills/ to USB (/Hermes-data/) and push configs/memories to GitHub"
    echo "  restore  Clone configs/memories from GitHub and restore state.db & skills/ from USB"
    exit 1
}

find_usb_data_dir() {
    echo "🔍 Looking for USB drive containing '/Hermes-data/' folder..."
    
    local usb_path=""
    for mount_point in /media/*/* /run/media/*/* /mnt/* /mnt; do
        if [ -d "${mount_point}/Hermes-data" ]; then
            usb_path="${mount_point}/Hermes-data"
            break
        elif [ -d "${mount_point}/LLM-backups" ] || [ -d "${mount_point}/writable" ]; then
            usb_path="${mount_point}/Hermes-data"
            mkdir -p "${usb_path}" 2>/dev/null || true
            if [ -d "${usb_path}" ]; then
                break
            fi
        fi
    done

    if [ -z "${usb_path}" ] || [ ! -d "${usb_path}" ]; then
        echo ""
        echo "⚠️ USB drive with 'Hermes-data' folder not automatically detected."
        read -rp "👉 Please insert your USB drive and enter its mount path (e.g. /run/media/thomas/writable): " USER_INPUT_PATH
        if [ -d "${USER_INPUT_PATH}" ]; then
            usb_path="${USER_INPUT_PATH}/Hermes-data"
            mkdir -p "${usb_path}"
        else
            echo "❌ Error: Directory '${USER_INPUT_PATH}' does not exist!"
            exit 1
        fi
    fi

    echo "✅ USB Hermes Data Directory found: ${usb_path}"
    USB_HERMES_DIR="${usb_path}"
}

export_data() {
    echo "======================================================================"
    echo "🚀 Exporting Hermes Personal Environment (Ultra-Light GitHub + USB Mode)"
    echo "======================================================================"

    # 1. USB Export for state.db AND skills/
    find_usb_data_dir
    mkdir -p "${USB_HERMES_DIR}"

    if [ -f "${HERMES_DIR}/state.db" ]; then
        echo "💾 Compressing and copying state.db to USB (${USB_HERMES_DIR}/state.db.gz)..."
        gzip -c "${HERMES_DIR}/state.db" > "${USB_HERMES_DIR}/state.db.gz"
        echo "✅ Conversation database backed up to USB!"
    fi

    if [ -d "${HERMES_DIR}/skills" ]; then
        echo "💾 Syncing skills/ (~643MB) to USB (${USB_HERMES_DIR}/skills/)..."
        rsync -av --delete --exclude='node_modules' --exclude='.git' "${HERMES_DIR}/skills/" "${USB_HERMES_DIR}/skills/"
        echo "✅ Skills backed up to USB!"
    fi

    # 2. Sync Lightweight Configs & Memories to GitHub
    echo "🌐 Syncing lightweight configs, memories, and metadata (< 1MB) to GitHub..."
    TMP_REPO=$(mktemp -d)
    git clone "${REPO_URL}" "${TMP_REPO}"

    cd "${TMP_REPO}"
    git config user.name "Thomas Krotkine"
    git config user.email "thomas.krotkine@gmail.com"
    git checkout -b main 2>/dev/null || true

    cp "${HERMES_DIR}/config.yaml" ./ 2>/dev/null || true
    cp "${HERMES_DIR}/.env" ./ 2>/dev/null || true
    cp "${HERMES_DIR}/SOUL.md" ./ 2>/dev/null || true
    
    rsync -av --delete --exclude='node_modules' --exclude='.git' "${HERMES_DIR}/memories" ./ 2>/dev/null || true
    rsync -av --delete --exclude='node_modules' --exclude='.git' "${HERMES_DIR}/cron" ./ 2>/dev/null || true
    rsync -av --delete --exclude='node_modules' --exclude='.git' "${HERMES_DIR}/plugins" ./ 2>/dev/null || true
    rsync -av --delete --exclude='node_modules' --exclude='.git' "${HERMES_DIR}/hooks" ./ 2>/dev/null || true
    rsync -av --delete --exclude='node_modules' --exclude='.git' "${HERMES_DIR}/scripts" ./ 2>/dev/null || true

    cp "${HERMES_DIR}/projects.db" ./ 2>/dev/null || true
    cp "${HERMES_DIR}/shared-state.db" ./ 2>/dev/null || true
    cp "${HERMES_DIR}/kanban.db" ./ 2>/dev/null || true

    # Include this deployment script in the repo
    cp "${HERMES_DIR}/Deploy-Hermes-Perso-data.sh" ./Deploy-Hermes-Perso-data.sh 2>/dev/null || true

    git add .
    git commit -m "Automated update of lightweight Hermes configs and memories [$(date '+%Y-%m-%d %H:%M:%S')]"
    git push origin main
    rm -rf "${TMP_REPO}"
    echo "🎉 Lightweight configs & memories pushed to GitHub successfully!"
}

restore_data() {
    echo "======================================================================"
    echo "📥 Restoring Hermes Personal Environment (Ultra-Light GitHub + USB Mode)"
    echo "======================================================================"

    mkdir -p "${HERMES_DIR}"

    # 1. Pull Lightweight Configs & Memories from GitHub
    echo "🌐 Cloning/Pulling configs and memories from GitHub..."
    TMP_REPO=$(mktemp -d)
    gh repo clone ThomasK2020/TK-Hermes-data "${TMP_REPO}"

    cp -r "${TMP_REPO}/"* "${HERMES_DIR}/" 2>/dev/null || true
    cp -r "${TMP_REPO}/."* "${HERMES_DIR}/" 2>/dev/null || true
    rm -rf "${TMP_REPO}"

    if [ -f "${HERMES_DIR}/.env" ]; then
        chmod 600 "${HERMES_DIR}/.env"
    fi
    echo "✅ GitHub configs & memories restored!"

    # 2. Restore state.db AND skills/ from USB
    find_usb_data_dir

    if [ -f "${USB_HERMES_DIR}/state.db.gz" ]; then
        echo "💾 Restoring state.db from USB..."
        gunzip -c "${USB_HERMES_DIR}/state.db.gz" > "${HERMES_DIR}/state.db"
        echo "✅ Conversation database state.db restored!"
    fi

    if [ -d "${USB_HERMES_DIR}/skills" ]; then
        echo "💾 Restoring skills/ from USB..."
        mkdir -p "${HERMES_DIR}/skills"
        rsync -av "${USB_HERMES_DIR}/skills/" "${HERMES_DIR}/skills/"
        echo "✅ Skills restored!"
    fi

    echo "🎉 Restoration complete! Hermes Agent environment is ready."
}

if [[ $# -lt 1 ]]; then
    usage
fi

case "$1" in
    export)
        export_data
        ;;
    restore)
        restore_data
        ;;
    *)
        usage
        ;;
esac
