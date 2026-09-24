#!/usr/bin/env bash
# ==============================================================================
# USER SESSION SETUP SCRIPT (Hermes Agent & OpenCode Configuration)
# ==============================================================================
# Usage:
#   bash setup-user.sh [--demo-profile] [--reset-demo] [--with-gemini]
# ==============================================================================
set -euo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_MODE=true
RESET_DEMO=false
ASK_GEMINI=false

# Parse CLI arguments
for arg in "$@"; do
    case $arg in
        --demo-profile|--demo-user)
            DEMO_MODE=true
            ;;
        --reset-demo|--force-demo)
            DEMO_MODE=true
            RESET_DEMO=true
            ;;
        --with-gemini)
            ASK_GEMINI=true
            ;;
    esac
done

# Ensure ~/.local/bin is in PATH and imported into systemd user session for Desktop GUI
mkdir -p ~/.local/bin
export PATH="${HOME}/.local/bin:${PATH}"
systemctl --user import-environment PATH 2>/dev/null || true

echo "⚙️ [1/3] Configuring Hermes Agent environment for LocalAIDemoUser..."
mkdir -p ~/.hermes ~/.hermes/memories

# Handle reset/backup of previous state.db if --reset-demo is specified
if [ "$RESET_DEMO" = true ] && [ -f ~/.hermes/state.db ]; then
    TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
    echo "⚠️ Resetting demo chat history: backing up ~/.hermes/state.db -> ~/.hermes/state.db.bak.${TIMESTAMP}"
    mv ~/.hermes/state.db "${HOME}/.hermes/state.db.bak.${TIMESTAMP}"
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

cat <<EOF > ~/.hermes/.env
GEMINI_API_KEY=${GEMINI_KEY}
OBSIDIAN_VAULT_PATH=${HOME}/Documents/ThomasKRemoteVault
EOF
chmod 600 ~/.hermes/.env

# Deploy default config.yaml for LocalAIDemoUser
if [ -f "${SETUP_DIR}/configs/hermes/config.yaml" ]; then
    cp "${SETUP_DIR}/configs/hermes/config.yaml" ~/.hermes/config.yaml
fi

# Create default clean LocalAIDemoUser memory profile
cat <<'EOF' > ~/.hermes/memories/USER.md
# USER PROFILE — LocalAIDemoUser
- Account: Local AI Workstation Demo User
- Preferred Mode: 100% Local Inference (Lemonade / Qwen3-Coder-30B)
- Interface: Open WebUI (port 8080) & Hermes Agent / OpenCode CLI
EOF

# Copy shared technical skills to ~/.hermes/skills/ if available
if [ -d "${SETUP_DIR}/configs/hermes/skills" ]; then
    mkdir -p ~/.hermes/skills
    rsync -av "${SETUP_DIR}/configs/hermes/skills/" ~/.hermes/skills/ 2>/dev/null || true
fi

# Fix permissions and install Desktop UI workspace dependencies if system Hermes is present
if [ -d "/usr/local/lib/hermes-agent" ]; then
    echo "📦 Configuring Hermes Desktop UI workspace permissions & dependencies..."
    sudo chown -R "${USER}:${USER}" /usr/local/lib/hermes-agent 2>/dev/null || true
    chmod -R 775 /usr/local/lib/hermes-agent 2>/dev/null || true
    (cd /usr/local/lib/hermes-agent && npm ci) || true
    echo "✅ Hermes Desktop UI dependencies ready!"
fi

echo "🤖 [2/3] Installing OpenCode CLI..."
curl -fsSL https://opencode.ai/install.sh | bash || true

mkdir -p ~/.config/opencode
cat <<'EOF' > ~/.config/opencode/config.json
{
  "provider": "openai",
  "options": {
    "baseURL": "http://localhost:13305/v1",
    "apiKey": "lemonade",
    "model": "Qwen3-Coder-30B-A3B-Instruct-GGUF"
  }
}
EOF

echo "✅ [3/3] User session setup completed successfully for LocalAIDemoUser!"
