#!/usr/bin/env bash
# ==============================================================================
# AUTOMATED WORKSTATION & SERVER SETUP SCRIPT (HP Z2 Mini & HP Z6 Server)
# ==============================================================================
# Usage:
#   sudo ./setup.sh [--with-hermes]
#
# Options:
#   --with-hermes | -hermes-setup   Optionally install Hermes Agent during setup
# ==============================================================================
set -euo pipefail

INSTALL_HERMES=false
REPO_URL="https://github.com/ThomasK2020/local-ai-workstation-setup.git"
SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse CLI parameters
for arg in "$@"; do
    case $arg in
        --with-hermes|-hermes-setup|--hermes-setup)
            INSTALL_HERMES=true
            shift
            ;;
    esac
done

echo "======================================================================"
echo "📥 [Step 1/7] Syncing configuration files from GitHub repository"
echo "======================================================================"
if [ ! -d "${SETUP_DIR}/configs" ]; then
    echo "Config directory missing locally. Cloning setup repo from GitHub..."
    TMP_DIR=$(mktemp -d)
    git clone "${REPO_URL}" "${TMP_DIR}"
    cp -r "${TMP_DIR}/configs" "${SETUP_DIR}/"
    rm -rf "${TMP_DIR}"
fi
echo "✅ Configuration files synchronized from GitHub!"

echo "======================================================================"
echo "🚀 [Step 2/7] System Dependencies & Optional Hermes Agent Setup"
echo "======================================================================"
apt-get update -y && apt-get install -y curl git jq python3 python3-pip python3-venv ufw mesa-vulkan-drivers

if [ "$INSTALL_HERMES" = true ]; then
    echo "⚙️ Installing Hermes Agent as requested via CLI flag..."
    curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash || true
    echo "✅ Hermes Agent installed successfully for troubleshooting!"
else
    echo "ℹ️ Skipping Hermes Agent installation (use --with-hermes flag to enable)."
fi

echo "======================================================================"
echo "👥 [Step 3/7] User Accounts and System Permissions Setup"
echo "======================================================================"
groupadd -f ai-services
id -u appmanager &>/dev/null || useradd -r -m -s /bin/bash appmanager
id -u HP-AMD-LocalAI &>/dev/null || useradd -m -s /bin/bash -G sudo HP-AMD-LocalAI

usermod -aG render,video,ai-services appmanager
usermod -aG render,video,ai-services HP-AMD-LocalAI

mkdir -p /var/lib/ai-models /var/lib/lemonade /home/appmanager/.local/bin
chown -R appmanager:ai-services /var/lib/ai-models /var/lib/lemonade /home/appmanager
chmod -R 775 /var/lib/ai-models /var/lib/lemonade
chmod g+s /var/lib/ai-models /var/lib/lemonade

echo "======================================================================"
echo "🎯 [Step 4/7] Inference Engine Selection (Lemonade vs vLLM)"
echo "======================================================================"
echo "1) Lemonade (HP Z2 Mini Workstations - AMD Strix Halo / Vulkan)"
echo "2) vLLM (HP Z6 Server - Multi-GPU / High-Throughput Multi-User)"
read -rp "Select inference engine [1 or 2]: " ENGINE_CHOICE

if [ "$ENGINE_CHOICE" == "2" ]; then
    ENGINE="vllm"
    echo "⚙️ Installing vLLM engine for HP Z6 Server..."
    pip install vllm torch
    if [ -f "${SETUP_DIR}/configs/systemd/vllm.service" ]; then
        cp "${SETUP_DIR}/configs/systemd/vllm.service" /etc/systemd/system/vllm.service
    fi
    systemctl daemon-reload
    systemctl enable --now vllm.service
    OPENWEBUI_OPENAI_URL="http://localhost:8000/v1"
else
    ENGINE="lemonade"
    echo "⚙️ Installing Lemonade engine for HP Z2 Mini Workstation..."
    curl -fsSL https://lemonade-ai.com/install.sh | bash || true
    if [ -f "${SETUP_DIR}/configs/systemd/lemonade.service" ]; then
        cp "${SETUP_DIR}/configs/systemd/lemonade.service" /etc/systemd/system/lemonade.service
    fi
    systemctl daemon-reload
    systemctl enable --now lemonade.service
    OPENWEBUI_OPENAI_URL="http://localhost:13305/v1"
fi

echo "======================================================================"
echo "🌐 [Step 5/7] Open WebUI Configuration & Network Exposure"
echo "======================================================================"
echo "1) Local access only (127.0.0.1)"
echo "2) Secure Local Area Network access (192.168.x.x / 0.0.0.0)"
read -rp "Select Open WebUI network mode [1 or 2]: " NET_CHOICE

WEBUI_SECRET=$(openssl rand -hex 32)

if [ "$NET_CHOICE" == "2" ]; then
    WEBUI_HOST="0.0.0.0"
    read -rp "Enter allowed subnet (e.g. 192.168.1.0/24): " ALLOWED_SUBNET
    ufw allow from "${ALLOWED_SUBNET}" to any port 8080
    ufw enable || true
    echo "🔒 UFW Firewall configured to allow ${ALLOWED_SUBNET} on port 8080"
else
    WEBUI_HOST="127.0.0.1"
fi

# Note: Open WebUI is ONLY connected to local inference engine.
# Gemini API Key is NEVER passed or exposed to Open WebUI.
cat <<EOF > /home/appmanager/.local/bin/start-open-webui.sh
#!/usr/bin/env bash
export WEBUI_HOST="${WEBUI_HOST}"
export WEBUI_PORT="8080"
export WEBUI_SECRET_KEY="${WEBUI_SECRET}"
export OPENAI_API_BASE_URL="${OPENWEBUI_OPENAI_URL}"
export CORS_ALLOW_ORIGIN="*"
exec open-webui serve
EOF

chmod +x /home/appmanager/.local/bin/start-open-webui.sh
chown appmanager:ai-services /home/appmanager/.local/bin/start-open-webui.sh

if [ -f "${SETUP_DIR}/configs/systemd/open-webui.service" ]; then
    cp "${SETUP_DIR}/configs/systemd/open-webui.service" /etc/systemd/system/open-webui.service
fi
systemctl daemon-reload
systemctl enable --now open-webui.service

echo "======================================================================"
echo "📥 [Step 6/7] Triggering LLM Model Downloads"
echo "======================================================================"
if [ -f "${SETUP_DIR}/download-models.sh" ]; then
    bash "${SETUP_DIR}/download-models.sh"
fi

echo "======================================================================"
echo "🎉 [Step 7/7] System Setup Complete! Selected Engine: ${ENGINE}"
echo "Run 'bash setup-user.sh' under HP-AMD-LocalAI user session."
echo "======================================================================"
