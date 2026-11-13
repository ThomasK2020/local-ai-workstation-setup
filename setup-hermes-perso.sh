#!/usr/bin/env bash
# ==============================================================================
# SETUP-HERMES-PERSO.SH
# Complete Profile Restorer for Profile 'amd-tk' (state.db, sessions, memories, skills)
# ==============================================================================
set -euo pipefail

PROFILE_NAME="amd-tk"

# Parse CLI arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile|-p)
            PROFILE_NAME="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

HERMES_ROOT="${HOME}/.hermes"
PROFILE_DIR="${HERMES_ROOT}/profiles/${PROFILE_NAME}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "======================================================================"
echo "🤖 Restoring Full Hermes Personal Profile: '${PROFILE_NAME}'"
echo "📁 Target Directory: ${PROFILE_DIR}"
echo "======================================================================"

# 1. Install xz-utils if missing
sudo -S -p '' apt-get install -y xz-utils tar rsync 2>/dev/null || true

# 2. Ensure profile directory structure exists
mkdir -p "${HERMES_ROOT}" "${PROFILE_DIR}" "${PROFILE_DIR}/memories" "${PROFILE_DIR}/skills" "${PROFILE_DIR}/sessions"

# 3. Restore Configs, Keys, and Memories from this repository
echo "📦 Applying configurations, memories, and keys to profile '${PROFILE_NAME}'..."

if [ -f "${SCRIPT_DIR}/config.yaml" ]; then
    cp "${SCRIPT_DIR}/config.yaml" "${PROFILE_DIR}/config.yaml"
    cp "${SCRIPT_DIR}/config.yaml" "${HERMES_ROOT}/config.yaml"
    echo "✅ Applied config.yaml (Model aliases: gemma, coder, qwen, deepseek, gemini)"
fi

if [ -f "${SCRIPT_DIR}/.env" ]; then
    cp "${SCRIPT_DIR}/.env" "${PROFILE_DIR}/.env"
    cp "${SCRIPT_DIR}/.env" "${HERMES_ROOT}/.env"
    chmod 600 "${PROFILE_DIR}/.env" "${HERMES_ROOT}/.env"
    echo "✅ Applied .env (Gemini API Key - chmod 600)"
fi

if [ -f "${SCRIPT_DIR}/SOUL.md" ]; then
    cp "${SCRIPT_DIR}/SOUL.md" "${PROFILE_DIR}/SOUL.md"
    cp "${SCRIPT_DIR}/SOUL.md" "${HERMES_ROOT}/SOUL.md"
fi

for db_file in projects.db shared-state.db kanban.db; do
    if [ -f "${SCRIPT_DIR}/${db_file}" ]; then
        cp "${SCRIPT_DIR}/${db_file}" "${PROFILE_DIR}/${db_file}"
    fi
done

for folder in memories cron plugins hooks scripts; do
    if [ -d "${SCRIPT_DIR}/${folder}" ]; then
        rsync -av "${SCRIPT_DIR}/${folder}/" "${PROFILE_DIR}/${folder}/"
    fi
done

# 4. Reassemble split state.db.xz.part_* directly into profile directory
if ls "${SCRIPT_DIR}"/state.db.xz.part_* &>/dev/null; then
    echo "📦 Reassembling and decompressing state.db into profile '${PROFILE_NAME}'..."
    TMP_XZ=$(mktemp /tmp/state_db_XXXXXX.xz)
    cat "${SCRIPT_DIR}"/state.db.xz.part_* > "${TMP_XZ}"
    unxz -c "${TMP_XZ}" > "${PROFILE_DIR}/state.db" 2>/dev/null || xz -d -c "${TMP_XZ}" > "${PROFILE_DIR}/state.db" 2>/dev/null || true
    rm -f "${TMP_XZ}"
    echo "✅ Conversation history (state.db) restored into profile '${PROFILE_NAME}'!"
elif [ -f "${SCRIPT_DIR}/state.db.gz" ]; then
    gunzip -c "${SCRIPT_DIR}/state.db.gz" > "${PROFILE_DIR}/state.db"
    echo "✅ Conversation history (state.db) restored into profile '${PROFILE_NAME}'!"
fi

# 5. Extract sessions.tar.xz into profile directory
if [ -f "${SCRIPT_DIR}/sessions.tar.xz" ]; then
    echo "📦 Extracting chat sessions.tar.xz into profile '${PROFILE_NAME}'..."
    tar -xf "${SCRIPT_DIR}/sessions.tar.xz" -C "${PROFILE_DIR}" 2>/dev/null || true
    echo "✅ Chat sessions restored into profile '${PROFILE_NAME}'!"
fi

# 6. Check USB drive if available for state.db or skills/ fallback
USB_DIR=$(ls -d /run/media/$USER/*/LLM-backups/Hermes-data /media/$USER/*/LLM-backups/Hermes-data 2>/dev/null | head -n1)
if [ -n "${USB_DIR:-}" ] && [ -d "${USB_DIR}" ]; then
    echo "💾 USB drive detected at ${USB_DIR}..."
    if [ -f "${USB_DIR}/state.db.gz" ] && [ ! -s "${PROFILE_DIR}/state.db" ]; then
        echo "💾 Restoring state.db from USB..."
        gunzip -c "${USB_DIR}/state.db.gz" > "${PROFILE_DIR}/state.db"
    fi
    if [ -d "${USB_DIR}/skills" ]; then
        echo "💾 Syncing skills/ from USB..."
        rsync -av "${USB_DIR}/skills/" "${PROFILE_DIR}/skills/"
    fi
fi

# Set active profile in ~/.hermes/active_profile
echo "${PROFILE_NAME}" > "${HERMES_ROOT}/active_profile"

# Register profile with Hermes CLI
if command -v hermes &>/dev/null; then
    hermes profile create "${PROFILE_NAME}" 2>/dev/null || true
    hermes profile switch "${PROFILE_NAME}" 2>/dev/null || true
fi

# Fix Desktop UI permissions
if [ -d "/usr/local/lib/hermes-agent" ]; then
    sudo -S -p '' chown -R "${USER}:${USER}" /usr/local/lib/hermes-agent 2>/dev/null || true
    chmod -R 775 /usr/local/lib/hermes-agent 2>/dev/null || true
    (cd /usr/local/lib/hermes-agent && npm ci) 2>/dev/null || true
fi

echo "======================================================================"
echo "🎉 Profile '${PROFILE_NAME}' Fully Restored! (History, Sessions & Keys Ready)"
echo "======================================================================"
echo ""
echo "🚀 Launch commands for profile '${PROFILE_NAME}':"
echo "  hermes --profile ${PROFILE_NAME}"
echo "  hermes desktop --profile ${PROFILE_NAME}"
