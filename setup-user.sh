#!/usr/bin/env bash
# ==============================================================================
# USER SESSION SETUP SCRIPT (Hermes Agent & OpenCode Configuration)
# ==============================================================================
set -euo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "⚙️ [1/3] Configuring Hermes Agent environment..."
mkdir -p ~/.hermes

# Optional Gemini API Key strictly reserved for Hermes Agent
echo ""
echo "----------------------------------------------------------------------"
echo "🔑 Gemini API Key Setup (Optional - STRICTLY reserved for Hermes Agent)"
echo "   Note: Open WebUI runs 100% locally and NEVER uses or receives"
echo "   this Gemini API Key."
echo "----------------------------------------------------------------------"
read -rp "Do you want to configure a Gemini API Key for Hermes on THIS machine? (y/n): " USE_GEMINI

GEMINI_KEY=""
if [[ "$USE_GEMINI" =~ ^[Yy]$ ]]; then
    read -rsp "Enter your Gemini API Key: " GEMINI_KEY
    echo ""
fi

cat <<EOF > ~/.hermes/.env
GEMINI_API_KEY=${GEMINI_KEY}
OBSIDIAN_VAULT_PATH=${HOME}/Documents/ThomasKRemoteVault
EOF
chmod 600 ~/.hermes/.env

if [ -f "${SETUP_DIR}/configs/hermes/config.yaml" ]; then
    cp "${SETUP_DIR}/configs/hermes/config.yaml" ~/.hermes/config.yaml
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

echo "✅ [3/3] User session setup completed successfully!"
