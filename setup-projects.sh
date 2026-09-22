#!/usr/bin/env bash
# ==============================================================================
# PROJECT RESTORATION & GITHUB AUTHENTICATION SCRIPT (Flatfox & Pirates Bay)
# ==============================================================================
set -euo pipefail

PROJECTS_DIR="${HOME}/Projects"
mkdir -p "${PROJECTS_DIR}"

echo "🔑 [1/3] Checking / Authenticating GitHub CLI (gh)..."
if command -v gh &>/dev/null; then
    gh auth status || gh auth login --web -h github.com
else
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages/githubcli-archive-keyring.gpg main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update && sudo apt install gh -y
    gh auth login
fi

echo "📦 [2/3] Cloning & Restoring GitHub Repositories..."
cd "${PROJECTS_DIR}"

if [ ! -d "zurich-rental-flatfox-agent" ]; then
    echo "Cloning Zurich Rental Agent (Flatfox)..."
    git clone https://github.com/ThomasK2020/zurich-rental-flatfox-agent.git
fi

if [ ! -d "pirates_bay_local_coding" ]; then
    echo "Initializing Pirates Bay workspace..."
    mkdir -p pirates_bay_local_coding
fi

echo "📝 [3/3] Setting up Python virtual environment for Flatfox Agent..."
if [ -d "zurich-rental-flatfox-agent" ]; then
    cd zurich-rental-flatfox-agent
    python3 -m venv venv
    ./venv/bin/pip install --upgrade pip
    if [ -f "requirements.txt" ]; then
        ./venv/bin/pip install -r requirements.txt
    fi
fi

echo "----------------------------------------------------------------------"
echo "🎉 GitHub projects and workspace restored successfully!"
echo "----------------------------------------------------------------------"
