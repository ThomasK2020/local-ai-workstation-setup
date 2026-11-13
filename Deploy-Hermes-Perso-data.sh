#!/usr/bin/env bash
# ==============================================================================
# DEPLOY-HERMES-PERSO-DATA.SH
# Hybrid Synchronizer & Profile Restorer: GitHub Repository + USB Support
# ==============================================================================
set -euo pipefail

PROFILE_NAME="amd-tk"
COMMAND="restore"

# Parse CLI arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile|-p)
            PROFILE_NAME="$2"
            shift 2
            ;;
        export|restore)
            COMMAND="$1"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${SETUP_DIR}/data"
HERMES_ROOT="${HOME}/.hermes"
PROFILE_DIR="${HERMES_ROOT}/profiles/${PROFILE_NAME}"
REPO_URL="https://github.com/ThomasK2020/TK-Hermes-data.git"

mkdir -p "${DATA_DIR}" "${HERMES_ROOT}" "${PROFILE_DIR}"

# Kill any running Hermes daemon to release background lock and prevent profile_scope_mismatch 403
pkill -f "hermes" 2>/dev/null || true
pkill -f "Hermes" 2>/dev/null || true

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

    find_usb_data_dir
    mkdir -p "${USB_HERMES_DIR}"

    SOURCE_DB="${PROFILE_DIR}/state.db"
    [ ! -f "${SOURCE_DB}" ] && SOURCE_DB="${HERMES_ROOT}/state.db"

    if [ -f "${SOURCE_DB}" ]; then
        echo "💾 Compressing state.db locally..."
        TMP_GZ=$(mktemp)
        gzip -c -9 "${SOURCE_DB}" > "${TMP_GZ}"
        
        echo "💾 Copying state.db.gz to USB (${USB_HERMES_DIR}/state.db.gz)..."
        cp "${TMP_GZ}" "${USB_HERMES_DIR}/state.db.gz"
        rm -f "${TMP_GZ}"
        
        sync
        echo "✅ Conversation database backed up to USB!"
    fi

    SOURCE_SKILLS="${PROFILE_DIR}/skills"
    [ ! -d "${SOURCE_SKILLS}" ] && SOURCE_SKILLS="${HERMES_ROOT}/skills"

    if [ -d "${SOURCE_SKILLS}" ]; then
        echo "💾 Syncing skills/ to USB (${USB_HERMES_DIR}/skills/)..."
        rsync -av --delete --exclude='node_modules' --exclude='.git' "${SOURCE_SKILLS}/" "${USB_HERMES_DIR}/skills/"
        echo "✅ Skills backed up to USB!"
    fi
}

restore_data() {
    echo "======================================================================"
    echo "📥 Restoring Hermes Personal Profile '${PROFILE_NAME}'"
    echo "📁 Target Profile Dir: ${PROFILE_DIR}"
    echo "📁 Data Storage Dir:   ${DATA_DIR}"
    echo "======================================================================"

    mkdir -p "${DATA_DIR}" "${HERMES_ROOT}" "${PROFILE_DIR}" "${PROFILE_DIR}/memories" "${PROFILE_DIR}/skills" "${PROFILE_DIR}/sessions"

    TK_REPO_DIR="${DATA_DIR}/TK-Hermes-data"
    if [ ! -d "${TK_REPO_DIR}/.git" ]; then
        echo "🌐 Cloning private repository ThomasK2020/TK-Hermes-data into ${TK_REPO_DIR}..."
        gh repo clone ThomasK2020/TK-Hermes-data "${TK_REPO_DIR}" -- --depth 1 2>/dev/null || git clone --depth 1 "${REPO_URL}" "${TK_REPO_DIR}" 2>/dev/null || true
    else
        echo "🌐 Updating local TK-Hermes-data repository..."
        (cd "${TK_REPO_DIR}" && git pull origin main 2>/dev/null || true)
    fi

    sudo apt-get install -y xz-utils tar rsync 2>/dev/null || true

    if [ -d "${TK_REPO_DIR}" ]; then
        cp "${TK_REPO_DIR}/config.yaml" "${PROFILE_DIR}/" 2>/dev/null || true
        cp "${TK_REPO_DIR}/config.yaml" "${HERMES_ROOT}/" 2>/dev/null || true
        cp "${TK_REPO_DIR}/.env" "${PROFILE_DIR}/" 2>/dev/null || true
        cp "${TK_REPO_DIR}/.env" "${HERMES_ROOT}/" 2>/dev/null || true
        chmod 600 "${PROFILE_DIR}/.env" "${HERMES_ROOT}/.env" 2>/dev/null || true
        cp "${TK_REPO_DIR}/SOUL.md" "${PROFILE_DIR}/" 2>/dev/null || true

        for db_file in projects.db shared-state.db kanban.db; do
            cp "${TK_REPO_DIR}/${db_file}" "${PROFILE_DIR}/" 2>/dev/null || true
            cp "${TK_REPO_DIR}/${db_file}" "${HERMES_ROOT}/" 2>/dev/null || true
        done

        for folder in memories cron plugins hooks scripts; do
            if [ -d "${TK_REPO_DIR}/${folder}" ]; then
                rsync -av "${TK_REPO_DIR}/${folder}/" "${PROFILE_DIR}/${folder}/" 2>/dev/null || true
                rsync -av "${TK_REPO_DIR}/${folder}/" "${HERMES_ROOT}/${folder}/" 2>/dev/null || true
            fi
        done

        # Reassemble state.db.xz.part_* directly into profile directory
        if ls "${TK_REPO_DIR}"/state.db.xz.part_* &>/dev/null; then
            echo "📦 Reassembling state.db from repository parts..."
            TMP_XZ=$(mktemp /tmp/state_db_XXXXXX.xz)
            cat "${TK_REPO_DIR}"/state.db.xz.part_* > "${TMP_XZ}"
            unxz -c "${TMP_XZ}" > "${PROFILE_DIR}/state.db" 2>/dev/null || xz -d -c "${TMP_XZ}" > "${PROFILE_DIR}/state.db" 2>/dev/null || true
            cp "${PROFILE_DIR}/state.db" "${HERMES_ROOT}/state.db" 2>/dev/null || true
            rm -f "${TMP_XZ}"
            echo "✅ Conversation database (state.db) restored!"
        elif [ -f "${TK_REPO_DIR}/state.db.gz" ]; then
            gunzip -c "${TK_REPO_DIR}/state.db.gz" > "${PROFILE_DIR}/state.db"
            cp "${PROFILE_DIR}/state.db" "${HERMES_ROOT}/state.db" 2>/dev/null || true
            echo "✅ Conversation database (state.db) restored!"
        fi

        # Extract sessions.tar.xz
        if [ -f "${TK_REPO_DIR}/sessions.tar.xz" ]; then
            echo "📦 Extracting chat sessions.tar.xz into profile '${PROFILE_NAME}'..."
            tar -xf "${TK_REPO_DIR}/sessions.tar.xz" -C "${PROFILE_DIR}" 2>/dev/null || true
            tar -xf "${TK_REPO_DIR}/sessions.tar.xz" -C "${HERMES_ROOT}" 2>/dev/null || true
            echo "✅ Chat sessions restored!"
        fi

        # Extract skills
        if [ -d "${TK_REPO_DIR}/skills" ]; then
            rsync -av "${TK_REPO_DIR}/skills/" "${PROFILE_DIR}/skills/" 2>/dev/null || true
            rsync -av "${TK_REPO_DIR}/skills/" "${HERMES_ROOT}/skills/" 2>/dev/null || true
            echo "✅ Skills restored!"
        fi
    fi

    # Check USB fallback if state.db is missing
    if [ ! -f "${PROFILE_DIR}/state.db" ]; then
        find_usb_data_dir_optional
        if [ -n "${USB_HERMES_DIR:-}" ] && [ -d "${USB_HERMES_DIR}" ]; then
            if [ -f "${USB_HERMES_DIR}/state.db.gz" ]; then
                gunzip -c "${USB_HERMES_DIR}/state.db.gz" > "${PROFILE_DIR}/state.db"
                cp "${PROFILE_DIR}/state.db" "${HERMES_ROOT}/state.db" 2>/dev/null || true
            fi
            if [ -d "${USB_HERMES_DIR}/skills" ]; then
                rsync -av "${USB_HERMES_DIR}/skills/" "${PROFILE_DIR}/skills/" 2>/dev/null || true
            fi
        fi
    fi

    # Set active profile in ~/.hermes/active_profile
    echo "${PROFILE_NAME}" > "${HERMES_ROOT}/active_profile"

    # Register profile with Hermes CLI
    if command -v hermes &>/dev/null; then
        hermes profile create "${PROFILE_NAME}" 2>/dev/null || hermes profile use "${PROFILE_NAME}" 2>/dev/null || hermes profile switch "${PROFILE_NAME}" 2>/dev/null || true
    fi

    # Fix Desktop UI permissions
    if [ -d "/usr/local/lib/hermes-agent" ]; then
        sudo chown -R "${USER}:${USER}" /usr/local/lib/hermes-agent 2>/dev/null || true
        chmod -R 775 /usr/local/lib/hermes-agent 2>/dev/null || true
        (cd /usr/local/lib/hermes-agent && npm ci) 2>/dev/null || true
    fi

    echo "======================================================================"
    echo "🎉 Profile '${PROFILE_NAME}' Restored & Activated!"
    echo "======================================================================"
    echo ""
    echo "🚀 Launch commands:"
    echo "  hermes --profile ${PROFILE_NAME}"
    echo "  hermes desktop --profile ${PROFILE_NAME}"
}

case "${COMMAND}" in
    export)
        export_data
        ;;
    restore)
        restore_data
        ;;
    *)
        restore_data
        ;;
esac
