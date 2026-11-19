#!/usr/bin/env bash
# ==============================================================================
# PROJECT RESTORATION & SELECTIVE MODULE MANAGER
# ==============================================================================
set -euo pipefail

PROJECTS_DIR="${HOME}/Projects"
SELECTED_MODULE=""
RESTORE_ALL=false

show_help() {
    echo "======================================================================"
    echo "📦 SETUP-PROJECTS.SH — Selective Application Module Installer"
    echo "======================================================================"
    echo "Usage: bash setup-projects.sh [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help               Show this help message"
    echo "  --module <name>          Install specific module:"
    echo "                           - tokenwatcher-topbar (GNOME TopBar Extension + daemon)"
    echo "                           - tokenwatcher-widget (Standalone Cockpit WebGL Widget)"
    echo "                           - flatfox            (Zurich Flatfox Rental Search Agent)"
    echo "                           - pirates-bay        (Pirates Bay Local AI Coding Sandbox)"
    echo "                           - dj-mix             (DJ Mix Studio AI & Kokoro TTS)"
    echo "  --all-modules, --all     Restore ALL application modules"
    echo ""
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            ;;
        --module)
            SELECTED_MODULE="$2"
            shift 2
            ;;
        --all-modules|--all)
            RESTORE_ALL=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Default to restoring all if neither --module nor --all specified when called directly
if [ -z "${SELECTED_MODULE}" ] && [ "${RESTORE_ALL}" = false ]; then
    RESTORE_ALL=true
fi

mkdir -p "${PROJECTS_DIR}"

echo "🔑 [1/3] Checking GitHub CLI (gh) & Git Helper..."
if command -v gh &>/dev/null && gh auth status &>/dev/null; then
    gh auth setup-git || true
    echo "✅ GitHub CLI credential helper configured ('gh auth setup-git')"
else
    echo "ℹ️ GitHub CLI is not authenticated. Public repositories will be cloned via HTTPS."
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

cd "${PROJECTS_DIR}"

clone_repo() {
    local repo_url="$1"
    local repo_dir="$2"
    if [ ! -d "${repo_dir}" ]; then
        echo "Cloning ${repo_dir}..."
        git clone "${repo_url}" "${repo_dir}" || echo "⚠️ Failed to clone ${repo_url}."
    else
        echo "📁 Directory ${repo_dir} already exists, skipping clone."
    fi
}

install_tokenwatcher_topbar() {
    echo "📦 [Module] Installing TokenWatcher TopBar GNOME Extension..."
    clone_repo "https://github.com/ThomasK2020/tokenwatcher-topbar.git" "tokenwatcher-topbar"
    
    python3 -m pip install --user --break-system-packages gnome-extensions-cli &>/dev/null || true
    export PATH="${HOME}/.local/bin:${PATH}"
    gext install monitor@astraext.github.io &>/dev/null || true

    if [ -d "tokenwatcher-topbar" ]; then
        (cd tokenwatcher-topbar && bash ./install.sh) || true
    fi

    gsettings set org.gnome.shell disable-user-extensions false 2>/dev/null || true
    gsettings set org.gnome.shell enabled-extensions "['tokenwatcher@thomas.local', 'monitor@astraext.github.io']" 2>/dev/null || true
    echo "✅ TokenWatcher TopBar installed & enabled!"
}

install_tokenwatcher_widget() {
    echo "📦 [Module] Installing TokenWatcher Widget Cockpit..."
    clone_repo "https://github.com/ThomasK2020/TokenWatcherWidget.git" "TokenWatcherWidget"
    if [ -d "TokenWatcherWidget" ]; then
        local widget_target="TokenWatcherWidget"
        [ -d "TokenWatcherWidget/Widget" ] && widget_target="TokenWatcherWidget/Widget"
        /usr/bin/python3 -m venv --system-site-packages "${widget_target}/.venv" 2>/dev/null || true
        if [ ! -f "/usr/lib/x86_64-linux-gnu/girepository-1.0/WebKit-6.0.typelib" ] && [ ! -f "${HOME}/.local/lib/girepository-1.0/WebKit-6.0.typelib" ]; then
            mkdir -p /tmp/gir_dl "${HOME}/.local/lib/girepository-1.0"
            (
                cd /tmp/gir_dl
                apt-get download gir1.2-webkit-6.0 gir1.2-javascriptcoregtk-6.0 2>/dev/null || true
                for deb in *.deb; do
                    [ -f "$deb" ] && dpkg-deb -x "$deb" /tmp/gir_dl/extracted
                done
                cp -f /tmp/gir_dl/extracted/usr/lib/x86_64-linux-gnu/girepository-1.0/*.typelib "${HOME}/.local/lib/girepository-1.0/" 2>/dev/null || true
            )
            rm -rf /tmp/gir_dl
        fi
    fi
    echo "✅ TokenWatcher Widget Cockpit restored in ${PROJECTS_DIR}/TokenWatcherWidget!"
}

install_flatfox() {
    echo "📦 [Module] Installing Zurich Flatfox Rental Agent..."
    clone_repo "https://github.com/ThomasK2020/zurich-rental-flatfox-agent.git" "zurich-rental-flatfox-agent"
    if [ -d "zurich-rental-flatfox-agent" ]; then
        (
            cd zurich-rental-flatfox-agent
            python3 -m venv venv
            ./venv/bin/pip install --upgrade pip
            [ -f "requirements.txt" ] && ./venv/bin/pip install -r requirements.txt || true
        )
    fi
    echo "✅ Flatfox agent module installed!"
}

install_pirates_bay() {
    echo "📦 [Module] Installing Pirates Bay Local AI Coding Sandbox..."
    clone_repo "https://github.com/ThomasK2020/PiratesBayLocalAI.git" "pirates_bay_local_coding"
    echo "✅ Pirates Bay sandbox restored in ${PROJECTS_DIR}/pirates_bay_local_coding!"
}

install_dj_mix() {
    echo "📦 [Module] Installing DJ Mix Local AI Project..."
    clone_repo "https://github.com/ThomasK2020/DJ-Mix-Local-AI-Project.git" "DJ-Mix-Local-AI-Project"
    echo "✅ DJ Mix project restored in ${PROJECTS_DIR}/DJ-Mix-Local-AI-Project!"
}

echo "📦 [2/3] Restoring Selected Application Modules..."

if [ "${RESTORE_ALL}" = true ]; then
    install_tokenwatcher_topbar
    install_tokenwatcher_widget
    install_flatfox
    install_pirates_bay
    install_dj_mix
else
    case "${SELECTED_MODULE}" in
        tokenwatcher-topbar|topbar)
            install_tokenwatcher_topbar
            ;;
        tokenwatcher-widget|widget)
            install_tokenwatcher_widget
            ;;
        flatfox)
            install_flatfox
            ;;
        pirates-bay|piratesbay)
            install_pirates_bay
            ;;
        dj-mix|djmix)
            install_dj_mix
            ;;
        *)
            echo "⚠️ Unknown module '${SELECTED_MODULE}'. Restoring all default modules."
            install_tokenwatcher_topbar
            install_flatfox
            ;;
    esac
fi

echo "----------------------------------------------------------------------"
echo "🎉 Requested application modules restored successfully!"
echo "----------------------------------------------------------------------"
