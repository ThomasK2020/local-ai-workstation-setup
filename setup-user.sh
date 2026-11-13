#!/usr/bin/env bash
# ==============================================================================
# USER SESSION SETUP SCRIPT (Hermes Agent & OpenCode Configuration)
# ==============================================================================
# Usage:
#   bash setup-user.sh [--profile amd-tk] [--with-hermes] [--reset-demo] [--with-gemini] [--skip-opencode]
# ==============================================================================
set -euo pipefail

# If executed via sudo, re-run as non-root user ($SUDO_USER) so files land in user home
if [ "${EUID}" -eq 0 ] && [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
    echo "⚠️ setup-user.sh should run as non-root user. Switching execution to user '${SUDO_USER}'..."
    exec sudo -u "${SUDO_USER}" bash "$0" "$@"
fi

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_MODE=true
RESET_DEMO=false
ASK_GEMINI=false
INSTALL_OPENCODE=true
CONFIGURE_HERMES=true
PROFILE_NAME="amd-tk"

# Parse CLI arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile|-p)
            PROFILE_NAME="$2"
            shift 2
            ;;
        --hermes|--with-hermes)
            CONFIGURE_HERMES=true
            shift
            ;;
        --skip-opencode|--without-opencode)
            INSTALL_OPENCODE=false
            shift
            ;;
        --demo-profile|--demo-user)
            DEMO_MODE=true
            shift
            ;;
        --reset-demo|--force-demo)
            DEMO_MODE=true
            RESET_DEMO=true
            shift
            ;;
        --with-gemini)
            ASK_GEMINI=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Ensure ~/.local/bin is in PATH and imported into systemd user session for Desktop GUI
mkdir -p ~/.local/bin
export PATH="${HOME}/.local/bin:${PATH}"
systemctl --user import-environment PATH 2>/dev/null || true

HERMES_ROOT="${HOME}/.hermes"
PROFILE_DIR="${HERMES_ROOT}/profiles/${PROFILE_NAME}"

if [ "$CONFIGURE_HERMES" = true ]; then
    echo "⚙️ [1/3] Registering & Configuring Hermes Agent profile '${PROFILE_NAME}'..."
    if command -v hermes &>/dev/null; then
        hermes profile create "${PROFILE_NAME}" 2>/dev/null || hermes profile use "${PROFILE_NAME}" 2>/dev/null || hermes profile switch "${PROFILE_NAME}" 2>/dev/null || true
    fi
    mkdir -p "${HERMES_ROOT}" "${PROFILE_DIR}" "${PROFILE_DIR}/memories" "${PROFILE_DIR}/skills"

    # Handle reset/backup of previous state.db if --reset-demo is specified
    if [ "$RESET_DEMO" = true ] && [ -f "${PROFILE_DIR}/state.db" ]; then
        TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
        echo "⚠️ Resetting chat history: backing up ${PROFILE_DIR}/state.db -> state.db.bak.${TIMESTAMP}"
        mv "${PROFILE_DIR}/state.db" "${PROFILE_DIR}/state.db.bak.${TIMESTAMP}"
    fi

    # Optional Gemini API Key strictly reserved for Hermes Agent
    GEMINI_KEY=""
    if [ "$ASK_GEMINI" = true ]; then
        echo ""
        echo "----------------------------------------------------------------------"
        echo "🔑 Gemini API Key Setup (Optional - STRICTLY reserved for Hermes Agent)"
        echo "   Note: Open WebUI runs 100% locally and NEVER uses or receives"
        echo "   this Gemini API Key."
        echo "----------------------------------------------------------------------"
        read -rp "Do you want to configure a Gemini API Key for Hermes on THIS machine? (y/n): " USE_GEMINI

        if [[ "$USE_GEMINI" =~ ^[Yy]$ ]]; then
            read -rsp "Enter your Gemini API Key: " GEMINI_KEY
            echo ""
        fi
    fi

    cat <<EOF > "${PROFILE_DIR}/.env"
GEMINI_API_KEY=${GEMINI_KEY}
OBSIDIAN_VAULT_PATH=${HOME}/Documents/ThomasKRemoteVault
EOF
    chmod 600 "${PROFILE_DIR}/.env"

    cat <<EOF > "${HERMES_ROOT}/.env"
GEMINI_API_KEY=${GEMINI_KEY}
OBSIDIAN_VAULT_PATH=${HOME}/Documents/ThomasKRemoteVault
EOF
    chmod 600 "${HERMES_ROOT}/.env"

    # Deploy default config.yaml for profile
    if [ -f "${SETUP_DIR}/configs/hermes/config.yaml" ]; then
        cp "${SETUP_DIR}/configs/hermes/config.yaml" "${PROFILE_DIR}/config.yaml"
        cp "${SETUP_DIR}/configs/hermes/config.yaml" "${HERMES_ROOT}/config.yaml"
    fi

    # Create profile memory document
    cat <<EOF > "${PROFILE_DIR}/memories/USER.md"
# USER PROFILE — ${PROFILE_NAME}
- Profile: ${PROFILE_NAME}
- Preferred Mode: 100% Local Inference (Lemonade / vLLM)
- Interface: Open WebUI (port 8080) & Hermes Agent / OpenCode CLI
EOF

    # Copy shared technical skills if available
    if [ -d "${SETUP_DIR}/configs/hermes/skills" ]; then
        rsync -av "${SETUP_DIR}/configs/hermes/skills/" "${PROFILE_DIR}/skills/" 2>/dev/null || true
    fi

    # Set active profile
    echo "${PROFILE_NAME}" > "${HERMES_ROOT}/active_profile"

    # Fix permissions and install Desktop UI workspace dependencies if system Hermes is present
    if [ -d "/usr/local/lib/hermes-agent" ]; then
        echo "📦 Configuring Hermes Desktop UI workspace permissions & dependencies..."
        sudo chown -R "${USER}:${USER}" /usr/local/lib/hermes-agent 2>/dev/null || true
        chmod -R 775 /usr/local/lib/hermes-agent 2>/dev/null || true
        (cd /usr/local/lib/hermes-agent && npm ci) 2>/dev/null || true
        echo "✅ Hermes Desktop UI dependencies ready!"
    fi
fi

if [ "$INSTALL_OPENCODE" = true ]; then
    echo "🤖 [2/3] Installing OpenCode CLI..."
    if ! command -v opencode &>/dev/null; then
        npm install -g --allow-scripts=opencode-ai opencode-ai || curl -fsSL https://opencode.ai/install.sh | bash || true
        mkdir -p "${HOME}/.local/bin"
        [ -n "$(command -v opencode 2>/dev/null)" ] && ln -sf "$(command -v opencode)" "${HOME}/.local/bin/opencode" || true
    else
        echo "✅ OpenCode CLI already installed ($(opencode --version 2>/dev/null || echo 'present'))"
    fi

    # Auto-detect whether system runs vLLM (port 8000) or Lemonade (port 13305)
    OPENCODE_BASE_URL="http://localhost:13305/v1"
    OPENCODE_API_KEY="lemonade"

    if curl -s http://localhost:8000/v1/models >/dev/null 2>&1 || systemctl is-active --quiet vllm.service 2>/dev/null; then
        OPENCODE_BASE_URL="http://localhost:8000/v1"
        OPENCODE_API_KEY="vllm"
        echo "⚙️ OpenCode configured for vLLM Server on port 8000"
    else
        echo "⚙️ OpenCode configured for Lemonade Workstation on port 13305"
    fi

    mkdir -p ~/.config/opencode
    cat <<EOF > ~/.config/opencode/config.json
{
  "\$schema": "https://opencode.ai/config.json",
  "provider": {
    "lemonade": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Lemonade Local",
      "options": {
        "baseURL": "${OPENCODE_BASE_URL}"
      },
      "models": {
        "Qwen3-Coder-30B-A3B-Instruct-GGUF": {
          "name": "Qwen3-Coder-30B-A3B-Instruct-GGUF"
        }
      }
    }
  },
  "model": "lemonade/Qwen3-Coder-30B-A3B-Instruct-GGUF"
}
EOF
else
    echo "ℹ️ Skipping OpenCode CLI installation & configuration (--skip-opencode)."
fi

echo "✅ [3/3] User session setup completed successfully for profile '${PROFILE_NAME}'!"
