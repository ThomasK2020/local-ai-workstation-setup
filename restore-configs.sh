#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGS_DIR="$REPO_DIR/configs"

echo "==> Restauration des configurations Local AI Workstation..."

# 1. Hermes Agent
echo "-> Restauration Hermes Agent..."
mkdir -p "$HOME/.hermes"
if [ -f "$CONFIGS_DIR/hermes/global/config.yaml" ]; then
    cp -n "$CONFIGS_DIR/hermes/global/config.yaml" "$HOME/.hermes/" || true
fi

for prof in lively-tk perso-agent amd-tk LocalAIDemo; do
    if [ -f "$CONFIGS_DIR/hermes/profiles/$prof/config.yaml" ]; then
        mkdir -p "$HOME/.hermes/profiles/$prof"
        cp "$CONFIGS_DIR/hermes/profiles/$prof/config.yaml" "$HOME/.hermes/profiles/$prof/"
        echo "   Profil '$prof' restauré."
    fi
done

# 2. Lemonade
echo "-> Restauration Lemonade..."
mkdir -p "$HOME/.config/lemonade"
if [ -f "$CONFIGS_DIR/lemonade/user-config.json" ]; then
    cp "$CONFIGS_DIR/lemonade/user-config.json" "$HOME/.config/lemonade/config.json"
fi
if [ -f "$CONFIGS_DIR/lemonade/configure_lemonade_sampling.sh" ]; then
    cp "$CONFIGS_DIR/lemonade/configure_lemonade_sampling.sh" "$HOME/"
    chmod +x "$HOME/configure_lemonade_sampling.sh"
fi

# 3. OpenCode
echo "-> Restauration OpenCode & Proxy..."
mkdir -p "$HOME/.config/opencode" "$HOME/.local/bin" "$HOME/.config/systemd/user"
if [ -f "$CONFIGS_DIR/opencode/opencode.json" ]; then
    cp "$CONFIGS_DIR/opencode/opencode.json" "$HOME/.config/opencode/"
fi
if [ -f "$CONFIGS_DIR/opencode/config.json" ]; then
    cp "$CONFIGS_DIR/opencode/config.json" "$HOME/.config/opencode/"
fi
if [ -f "$CONFIGS_DIR/opencode/lemonade-opencode-proxy.py" ]; then
    cp "$CONFIGS_DIR/opencode/lemonade-opencode-proxy.py" "$HOME/.local/bin/"
    chmod +x "$HOME/.local/bin/lemonade-opencode-proxy.py"
fi
if [ -f "$CONFIGS_DIR/opencode/lemonade-opencode-proxy.service" ]; then
    cp "$CONFIGS_DIR/opencode/lemonade-opencode-proxy.service" "$HOME/.config/systemd/user/"
fi

echo "==> Restauration terminée avec succès !"
