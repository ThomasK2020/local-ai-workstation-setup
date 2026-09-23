#!/usr/bin/env bash
# ==============================================================================
# PROJECT RESTORATION & GITHUB AUTHENTICATION SCRIPT (Flatfox & Pirates Bay)
# ==============================================================================
set -euo pipefail

PROJECTS_DIR="${HOME}/Projects"
mkdir -p "${PROJECTS_DIR}"

echo "🔑 [1/3] Checking GitHub CLI (gh) & Git Helper..."
if command -v gh &>/dev/null && gh auth status &>/dev/null; then
    gh auth setup-git || true
    echo "✅ GitHub CLI credential helper configured ('gh auth setup-git')"
else
    echo "ℹ️ GitHub CLI is not authenticated (or not installed). Public repositories will be cloned via standard HTTPS without authentication."
fi

# Configure Git global user identity if missing
if [ -z "$(git config --global user.name || true)" ]; then
    git config --global user.name "Thomas Krotkine"
    echo "👤 Git global user.name set to 'Thomas Krotkine'"
fi

if [ -z "$(git config --global user.email || true)" ]; then
    git config --global user.email "thomas.krotkine@gmail.com"
    echo "📧 Git global user.email set to 'thomas.krotkine@gmail.com'"
fi

echo "📦 [2/3] Cloning & Restoring GitHub Repositories..."
cd "${PROJECTS_DIR}"

clone_repo() {
    local repo_url="$1"
    local repo_dir="$2"
    if [ ! -d "${repo_dir}" ]; then
        echo "Cloning ${repo_dir}..."
        if ! git clone "${repo_url}"; then
            echo "⚠️ Failed to clone ${repo_url}. If this is a private repository, ensure GitHub CLI is authenticated via 'gh auth login'."
        fi
    else
        echo "📁 Directory ${repo_dir} already exists, skipping clone."
    fi
}

clone_repo "https://github.com/ThomasK2020/zurich-rental-flatfox-agent.git" "zurich-rental-flatfox-agent"
clone_repo "https://github.com/ThomasK2020/tokenwatcher-topbar.git" "tokenwatcher-topbar"

if [ ! -d "pirates_bay_local_coding" ]; then
    echo "Initializing Pirates Bay workspace..."
    mkdir -p pirates_bay_local_coding
fi

echo "📝 [3/3] Setting up Python virtual environment, Astra Monitor & TokenWatcher plugin..."
echo "Installing GNOME extension tool (gnome-extensions-cli)..."
python3 -m pip install --user --break-system-packages gnome-extensions-cli &>/dev/null || true
export PATH="${HOME}/.local/bin:${PATH}"

echo "Installing Astra Monitor GNOME Extension (monitor@astraext.github.io)..."
gext install monitor@astraext.github.io &>/dev/null || true

if [ -d "tokenwatcher-topbar" ]; then
    echo "Installing TokenWatcher / Astra TopBar extension and daemon..."
    (cd tokenwatcher-topbar && bash ./install.sh) || true
fi

echo "Enabling GNOME Shell extensions (TokenWatcher TopBar & Astra Monitor)..."
gsettings set org.gnome.shell disable-user-extensions false 2>/dev/null || true
gsettings set org.gnome.shell enabled-extensions "['tokenwatcher@thomas.local', 'monitor@astraext.github.io']" 2>/dev/null || true

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
