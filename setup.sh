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

# Ensure script is executed as root/sudo
if [ "$EUID" -ne 0 ]; then
    echo "❌ Error: setup.sh requires root privileges to install system packages and Docker."
    echo "👉 Please re-run with sudo: sudo ./setup.sh $@"
    exit 1
fi

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
echo "📥 [Step 1/8] Syncing configuration files from GitHub repository"
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
echo "🚀 [Step 2/8] System Dependencies, Python Tooling, Node.js 22 LTS & Chrome"
echo "======================================================================"
apt-get update -y && apt-get install -y curl git jq python3 python3-pip python3-venv python3-full pipx build-essential libffi-dev ufw mesa-vulkan-drivers ca-certificates gnupg

# Install Google Chrome Stable for host-level interactive SSO login (Flatfox, etc.)
if ! command -v google-chrome &>/dev/null; then
    echo "🌐 Installing Google Chrome Stable for interactive SSO login..."
    curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg --yes
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | tee /etc/apt/sources.list.d/google-chrome.list > /dev/null
    apt-get update -y && apt-get install -y google-chrome-stable || true
    echo "✅ Google Chrome Stable installed!"
fi

# Purge legacy or conflicting nodejs/npm packages first
apt-get remove -y nodejs npm libnode-dev || true

# Install Node.js 22 LTS system-wide via official NodeSource APT repository
echo "🟢 Installing Node.js 22 LTS system-wide via official NodeSource APT..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg --yes
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list > /dev/null

apt-get update -y
apt-get install -y nodejs build-essential
echo "✅ Official APT Node.js $(node -v) & npm $(npm -v) installed in $(which node)!"

# Export ~/.local/bin globally for all desktop GUI sessions
cat <<'EOF' > /etc/profile.d/10-local-bin.sh
if [ -d "$HOME/.local/bin" ] ; then
    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) PATH="$HOME/.local/bin:$PATH" ;;
    esac
fi
export PATH
EOF
chmod +x /etc/profile.d/10-local-bin.sh

if [ "$INSTALL_HERMES" = true ]; then
    echo "⚙️ Installing Hermes Agent non-interactively..."
    HERMES_NON_INTERACTIVE=1 HERMES_YES=1 DEBIAN_FRONTEND=noninteractive curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --yes --non-interactive || true
    
    # Fix permissions on /usr/local/lib/hermes-agent for user npm dependencies (Desktop GUI)
    REAL_USER="${SUDO_USER:-$LOGNAME}"
    for target_dir in "/usr/local/lib/hermes-agent" "${HOME}/.hermes"; do
        if [ -d "${target_dir}" ]; then
            chown -R "${REAL_USER}:${REAL_USER}" "${target_dir}" 2>/dev/null || true
            chmod -R 775 "${target_dir}" 2>/dev/null || true
        fi
    done
    echo "✅ Hermes Agent installed silently and permissions configured for ${REAL_USER}!"
else
    echo "ℹ️ Skipping Hermes Agent installation (use --with-hermes flag to enable)."
fi

echo "======================================================================"
echo "🐳 [Step 3/8] Official Docker Engine & Docker Compose Setup"
echo "======================================================================"
# 1. Stop, unmask and purge legacy or conflicting docker packages
systemctl stop docker.service docker.socket containerd.service 2>/dev/null || true
systemctl unmask docker.service docker.socket 2>/dev/null || true
apt-get remove -y docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc || true

# 2. Add Docker official GPG key & APT repository
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
if ! apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
    echo "⚠️ Upstream download.docker.com install failed. Falling back to Ubuntu APT docker.io & docker-compose-v2..."
    apt-get install -y docker.io docker-compose-v2 containerd
fi

# 3. Configure Docker log-rotation daemon.json
mkdir -p /etc/docker
if [ -f "${SETUP_DIR}/configs/docker/daemon.json" ]; then
    cp "${SETUP_DIR}/configs/docker/daemon.json" /etc/docker/daemon.json
else
    cat <<'EOF' > /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "3"
  }
}
EOF
fi

systemctl daemon-reload
systemctl unmask docker.service docker.socket 2>/dev/null || true
systemctl restart docker || systemctl start docker
systemctl enable docker
echo "✅ Official Docker Engine & Compose Plugin installed!"

echo "======================================================================"
echo "👥 [Step 4/8] User Accounts, Permissions & GPU Passthrough Setup"
echo "======================================================================"
groupadd -f ai-services
groupadd -f docker

id -u appmanager &>/dev/null || useradd -r -m -s /bin/bash appmanager

# Dynamically add calling user and all user variants to docker & GPU groups
REAL_USER="${SUDO_USER:-$LOGNAME}"
for u in "$REAL_USER" "hp-amd-localai" "HP-AMD-LocalAI" "appmanager"; do
    if id -u "$u" &>/dev/null; then
        usermod -aG render,video,ai-services,docker "$u"
        echo "✅ User '$u' added to render, video, ai-services, and docker groups!"
    fi
done

chown root:docker /var/run/docker.sock 2>/dev/null || true
chmod 660 /var/run/docker.sock 2>/dev/null || true

mkdir -p /var/lib/ai-models /var/lib/lemonade /home/appmanager/.local/bin
chown -R appmanager:ai-services /var/lib/ai-models /var/lib/lemonade /home/appmanager
chmod -R 775 /var/lib/ai-models /var/lib/lemonade
chmod g+s /var/lib/ai-models /var/lib/lemonade

echo "======================================================================"
echo "🎯 [Step 5/8] Inference Engine Selection (Lemonade vs vLLM)"
echo "======================================================================"
echo "1) Lemonade (HP Z2 Mini Workstations - AMD Strix Halo / Vulkan)"
echo "2) vLLM (HP Z6 Server - Multi-GPU / High-Throughput Multi-User)"
read -rp "Select inference engine [1 or 2]: " ENGINE_CHOICE

if [ "$ENGINE_CHOICE" == "2" ]; then
    ENGINE="vllm"
    echo "⚙️ Installing vLLM engine in dedicated venv (/var/lib/vllm-env) for HP Z6 Server..."
    apt-get install -y python3-full python3-venv build-essential libffi-dev
    mkdir -p /var/lib/vllm-env
    python3 -m venv /var/lib/vllm-env
    /var/lib/vllm-env/bin/pip install --upgrade pip setuptools wheel
    /var/lib/vllm-env/bin/pip install vllm torch
    chown -R appmanager:ai-services /var/lib/vllm-env 2>/dev/null || true
    
    if [ -f "${SETUP_DIR}/configs/systemd/vllm.service" ]; then
        cp "${SETUP_DIR}/configs/systemd/vllm.service" /etc/systemd/system/vllm.service
    fi
    systemctl daemon-reload
    systemctl enable --now vllm.service
    OPENWEBUI_OPENAI_URL="http://localhost:8000/v1"
else
    ENGINE="lemonade"
    echo "⚙️ Installing Lemonade engine via official Snap package..."
    snap install lemonade-server || snap refresh lemonade-server || true
    
    # Clean up any legacy custom systemd service that caused restart loops
    systemctl disable --now lemonade.service 2>/dev/null || true
    rm -f /etc/systemd/system/lemonade.service
    systemctl daemon-reload

    # Start native Snap Lemonade daemon
    snap start lemonade-server.daemon 2>/dev/null || systemctl enable --now snap.lemonade-server.daemon.service 2>/dev/null || true
    
    # Ensure Lemonade cache directory exists with proper write permissions
    mkdir -p /var/snap/lemonade-server/common/.cache
    chmod -R 777 /var/snap/lemonade-server/common/.cache 2>/dev/null || true

    OPENWEBUI_OPENAI_URL="http://localhost:13305/v1"
fi

echo "======================================================================"
echo "🌐 [Step 6/8] Open WebUI Configuration & Network Exposure"
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
echo "🌐 Installing Open WebUI..."

# Open WebUI requires Python >= 3.11, < 3.13.0a1
PYTHON_BIN="python3"
if ! python3 -c 'import sys; exit(0 if sys.version_info < (3, 13) else 1)' 2>/dev/null; then
    echo "⚙️ Host Python is >= 3.13. Installing Python 3.11 for Open WebUI compatibility..."
    apt-get install -y python3.11 python3.11-venv 2>/dev/null || apt-get install -y python3.12 python3.12-venv 2>/dev/null || true
    if command -v python3.11 &>/dev/null; then
        PYTHON_BIN="python3.11"
    elif command -v python3.12 &>/dev/null; then
        PYTHON_BIN="python3.12"
    fi
fi

mkdir -p /home/appmanager/openwebui-venv
"$PYTHON_BIN" -m venv /home/appmanager/openwebui-venv
/home/appmanager/openwebui-venv/bin/pip install --upgrade pip

if /home/appmanager/openwebui-venv/bin/pip install open-webui; then
    echo "✅ Open WebUI installed successfully in Python virtualenv!"
    cat <<EOF > /home/appmanager/.local/bin/start-open-webui.sh
#!/usr/bin/env bash
export WEBUI_HOST="${WEBUI_HOST}"
export WEBUI_PORT="8080"
export WEBUI_SECRET_KEY="${WEBUI_SECRET}"
export OPENAI_API_BASE_URL="${OPENWEBUI_OPENAI_URL}"
export CORS_ALLOW_ORIGIN="*"
exec /home/appmanager/openwebui-venv/bin/open-webui serve
EOF
    chmod +x /home/appmanager/.local/bin/start-open-webui.sh
    chown appmanager:ai-services /home/appmanager/.local/bin/start-open-webui.sh

    if [ -f "${SETUP_DIR}/configs/systemd/open-webui.service" ]; then
        cp "${SETUP_DIR}/configs/systemd/open-webui.service" /etc/systemd/system/open-webui.service
    fi
    systemctl daemon-reload
    systemctl enable --now open-webui.service
else
    echo "⚠️ Pip install open-webui failed. Deploying official Docker container fallback..."
    systemctl disable --now open-webui.service 2>/dev/null || true
    rm -f /etc/systemd/system/open-webui.service
    systemctl daemon-reload
    
    docker rm -f open-webui 2>/dev/null || true
    docker run -d \
      --name open-webui \
      --network host \
      -e WEBUI_HOST="${WEBUI_HOST}" \
      -e WEBUI_PORT="8080" \
      -e WEBUI_SECRET_KEY="${WEBUI_SECRET}" \
      -e OPENAI_API_BASE_URL="${OPENWEBUI_OPENAI_URL}" \
      -e CORS_ALLOW_ORIGIN="*" \
      -v open-webui-data:/app/backend/data \
      --restart always \
      ghcr.io/open-webui/open-webui:main
    echo "✅ Open WebUI container deployed and running on port 8080!"
fi

echo "======================================================================"
echo "📥 [Step 7/8] Triggering LLM Model Downloads"
echo "======================================================================"
if [ -f "${SETUP_DIR}/download-models.sh" ]; then
    ENGINE="${ENGINE}" bash "${SETUP_DIR}/download-models.sh"
fi

echo "======================================================================"
echo "🎉 [Step 8/8] System Setup Complete! Selected Engine: ${ENGINE}"
echo "Run 'bash setup-user.sh' under HP-AMD-LocalAI user session."
echo "======================================================================"
