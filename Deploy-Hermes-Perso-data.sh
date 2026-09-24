#!/usr/bin/env bash
# ==============================================================================
# DEPLOY-HERMES-PERSO-DATA.SH
# Hybrid Synchronizer: GitHub Repository + USB Storage Support
# ==============================================================================
set -euo pipefail

HERMES_DIR="${HOME}/.hermes"
REPO_URL="https://github.com/ThomasK2020/TK-Hermes-data.git"

usage() {
    echo "Usage: $0 [export | restore]"
    echo ""
    echo "Commands:"
    echo "  export   Copy state.db & skills/ to USB (/Hermes-data/) and push configs/memories to GitHub"
    echo "  restore  Restore configs, memories, DB, and skills from GitHub repo and/or USB key"
    exit 1
}

find_usb_data_dir_optional() {
    local usb_path=""
    for candidate in \
        /run/media/*/*/LLM-backups/Hermes-data \
        /media/*/*/LLM-backups/Hermes-data \
        /run/media/*/*/Hermes-data \
        /media/*/*/Hermes-data \
        /mnt/LLM-backups/Hermes-data \
        /mnt/Hermes-data \
        "${HOME}/LLM-backups/Hermes-data"; do
        if [ -d "${candidate}" ] && [ "$(basename "${candidate}")" == "Hermes-data" ]; then
            usb_path="${candidate}"
            break
        elif [ -d "${candidate}/LLM-backups/Hermes-data" ]; then
            usb_path="${candidate}/LLM-backups/Hermes-data"
            break
        elif [ -d "${candidate}/Hermes-data" ]; then
            usb_path="${candidate}/Hermes-data"
            break
        fi
    done
    USB_HERMES_DIR="${usb_path}"
}

find_usb_data_dir() {
    echo "🔍 Looking for USB drive containing '/Hermes-data/' folder..."
    find_usb_data_dir_optional

    if [ -z "${USB_HERMES_DIR:-}" ] || [ ! -d "${USB_HERMES_DIR}" ]; then
        echo ""
        echo "⚠️ USB drive with 'Hermes-data' folder not automatically detected."
        read -rp "👉 Please insert your USB drive and enter its mount path (e.g. /run/media/${USER:-$LOGNAME}/writable): " USER_INPUT_PATH
        if [ -d "${USER_INPUT_PATH}/LLM-backups/Hermes-data" ]; then
            USB_HERMES_DIR="${USER_INPUT_PATH}/LLM-backups/Hermes-data"
        elif [ -d "${USER_INPUT_PATH}/Hermes-data" ]; then
            USB_HERMES_DIR="${USER_INPUT_PATH}/Hermes-data"
        elif [ -d "${USER_INPUT_PATH}" ]; then
            USB_HERMES_DIR="${USER_INPUT_PATH}/Hermes-data"
            mkdir -p "${USB_HERMES_DIR}" 2>/dev/null || sudo mkdir -p "${USB_HERMES_DIR}" 2>/dev/null || true
        else
            echo "❌ Error: Directory '${USER_INPUT_PATH}' does not exist!"
            exit 1
        fi
    fi

    echo "✅ USB Hermes Data Directory found: ${USB_HERMES_DIR}"
}

export_data() {
    echo "======================================================================"
    echo "🚀 Exporting Hermes Personal Environment (GitHub + USB Mode)"
    echo "======================================================================"

    # 1. USB Export for state.db AND skills/
    find_usb_data_dir
    mkdir -p "${USB_HERMES_DIR}"

    if [ -f "${HERMES_DIR}/state.db" ]; then
        echo "💾 Compressing state.db locally..."
        TMP_GZ=$(mktemp)
        gzip -c -9 "${HERMES_DIR}/state.db" > "${TMP_GZ}"
        
        echo "💾 Copying state.db.gz to USB (${USB_HERMES_DIR}/state.db.gz)..."
        cp "${TMP_GZ}" "${USB_HERMES_DIR}/state.db.gz"
        rm -f "${TMP_GZ}"
        
        echo "⚡ Flushing USB write buffers (sync)..."
        sync
        
        if gzip -t "${USB_HERMES_DIR}/state.db.gz" 2>/dev/null; then
            echo "✅ Conversation database backed up & verified on USB!"
        else
            echo "⚠️ Warning: Archive test failed. Copying uncompressed state.db to USB as fallback..."
            cp "${HERMES_DIR}/state.db" "${USB_HERMES_DIR}/state.db"
            sync
        fi
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
    echo "📥 Restoring Hermes Personal Environment (GitHub Repo + USB Support)"
    echo "======================================================================"

    mkdir -p "${HERMES_DIR}"

    # 1. Pull Configs, Memories, and Repo Archives from GitHub
    echo "🌐 Cloning/Pulling configs, memories, and archives from GitHub repository..."
    TMP_REPO=$(mktemp -d)
    gh repo clone ThomasK2020/TK-Hermes-data "${TMP_REPO}" -- --depth 1 2>/dev/null || git clone --depth 1 "${REPO_URL}" "${TMP_REPO}" 2>/dev/null || true

    if [ -d "${TMP_REPO}" ]; then
        cp "${TMP_REPO}/config.yaml" "${HERMES_DIR}/" 2>/dev/null || true
        cp "${TMP_REPO}/.env" "${HERMES_DIR}/" 2>/dev/null || true
        cp "${TMP_REPO}/SOUL.md" "${HERMES_DIR}/" 2>/dev/null || true

        for db_file in projects.db shared-state.db kanban.db; do
            cp "${TMP_REPO}/${db_file}" "${HERMES_DIR}/" 2>/dev/null || true
        done

        for folder in memories cron plugins hooks scripts; do
            if [ -d "${TMP_REPO}/${folder}" ]; then
                rsync -av "${TMP_REPO}/${folder}/" "${HERMES_DIR}/${folder}/" 2>/dev/null || true
            fi
        done

        if [ -f "${HERMES_DIR}/.env" ]; then
            chmod 600 "${HERMES_DIR}/.env"
        fi
        echo "✅ GitHub configs, memories, and databases restored!"

        # Reassemble split state.db.xz.part_* if present in GitHub repository
        if ls "${TMP_REPO}"/state.db.xz.part_* &>/dev/null; then
            echo "📦 Reassembling and decompressing state.db from GitHub repository parts..."
            cat "${TMP_REPO}"/state.db.xz.part_* > "${TMP_REPO}/state.db.xz"
            unxz -c "${TMP_REPO}/state.db.xz" > "${HERMES_DIR}/state.db" 2>/dev/null || xz -d -c "${TMP_REPO}/state.db.xz" > "${HERMES_DIR}/state.db" 2>/dev/null || true
            echo "✅ Conversation database (state.db) restored from GitHub!"
        elif [ -f "${TMP_REPO}/state.db.gz" ]; then
            echo "📦 Decompressing state.db.gz from GitHub repository..."
            gunzip -c "${TMP_REPO}/state.db.gz" > "${HERMES_DIR}/state.db"
            echo "✅ Conversation database (state.db) restored from GitHub!"
        fi

        # Restore sessions.tar.xz if present in GitHub repo
        if [ -f "${TMP_REPO}/sessions.tar.xz" ]; then
            echo "📦 Extracting sessions.tar.xz from GitHub repository..."
            tar -xf "${TMP_REPO}/sessions.tar.xz" -C "${HERMES_DIR}" 2>/dev/null || true
            echo "✅ Sessions restored from GitHub!"
        fi

        # Restore skills if present in GitHub repo
        if [ -d "${TMP_REPO}/skills" ]; then
            echo "📦 Restoring skills/ from GitHub repository..."
            mkdir -p "${HERMES_DIR}/skills"
            rsync -av "${TMP_REPO}/skills/" "${HERMES_DIR}/skills/"
            echo "✅ Skills restored from GitHub!"
        fi

        rm -rf "${TMP_REPO}"
    fi

    # 2. Check USB Drive only if state.db or skills are still missing
    if [ ! -f "${HERMES_DIR}/state.db" ] || [ ! -d "${HERMES_DIR}/skills" ]; then
        echo "🔍 Checking USB drive for additional DB archives or skills..."
        find_usb_data_dir_optional

        if [ -n "${USB_HERMES_DIR:-}" ] && [ -d "${USB_HERMES_DIR}" ]; then
            if [ ! -f "${HERMES_DIR}/state.db" ]; then
                if [ -f "${USB_HERMES_DIR}/state.db.gz" ]; then
                    if gzip -t "${USB_HERMES_DIR}/state.db.gz" 2>/dev/null; then
                        echo "💾 Decompressing state.db from USB..."
                        gunzip -c "${USB_HERMES_DIR}/state.db.gz" > "${HERMES_DIR}/state.db"
                        echo "✅ Conversation database state.db restored from USB!"
                    fi
                elif [ -f "${USB_HERMES_DIR}/state.db" ]; then
                    echo "💾 Restoring state.db from USB..."
                    cp "${USB_HERMES_DIR}/state.db" "${HERMES_DIR}/state.db"
                    echo "✅ Conversation database state.db restored from USB!"
                fi
            fi

            if [ ! -d "${HERMES_DIR}/skills" ] && [ -d "${USB_HERMES_DIR}/skills" ]; then
                echo "💾 Restoring skills/ from USB..."
                mkdir -p "${HERMES_DIR}/skills"
                rsync -av "${USB_HERMES_DIR}/skills/" "${HERMES_DIR}/skills/"
                echo "✅ Skills restored from USB!"
            fi
        fi
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
