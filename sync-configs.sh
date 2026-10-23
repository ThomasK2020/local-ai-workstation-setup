#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGS_DIR="$REPO_DIR/configs"

echo "==> [1/4] Synchronisation des configurations Hermes Agent..."
mkdir -p "$CONFIGS_DIR/hermes/global" "$CONFIGS_DIR/hermes/profiles"

# Config globale
if [ -f "$HOME/.hermes/config.yaml" ]; then
    cp "$HOME/.hermes/config.yaml" "$CONFIGS_DIR/hermes/global/"
fi

# Profils Hermes
for prof in lively-tk perso-agent amd-tk LocalAIDemo; do
    if [ -f "$HOME/.hermes/profiles/$prof/config.yaml" ]; then
        mkdir -p "$CONFIGS_DIR/hermes/profiles/$prof"
        cp "$HOME/.hermes/profiles/$prof/config.yaml" "$CONFIGS_DIR/hermes/profiles/$prof/"
    fi
done

echo "==> [2/4] Synchronisation de Lemonade Server..."
mkdir -p "$CONFIGS_DIR/lemonade"
if [ -f "$HOME/.config/lemonade/config.json" ]; then
    cp "$HOME/.config/lemonade/config.json" "$CONFIGS_DIR/lemonade/user-config.json"
fi
if [ -f "/home/thomas/configure_lemonade_sampling.sh" ]; then
    cp "/home/thomas/configure_lemonade_sampling.sh" "$CONFIGS_DIR/lemonade/"
fi
if [ -f "/usr/lib/systemd/system/lemond.service" ]; then
    cp "/usr/lib/systemd/system/lemond.service" "$CONFIGS_DIR/lemonade/"
fi
if [ -f "/var/lib/lemonade/config.json" ]; then
    sudo cat /var/lib/lemonade/config.json > "$CONFIGS_DIR/lemonade/server-config.json" 2>/dev/null || true
fi

echo "==> [3/4] Synchronisation d'OpenCode & Proxies..."
mkdir -p "$CONFIGS_DIR/opencode"
if [ -f "$HOME/.config/opencode/opencode.json" ]; then
    cp "$HOME/.config/opencode/opencode.json" "$CONFIGS_DIR/opencode/"
fi
if [ -f "$HOME/.config/opencode/config.json" ]; then
    cp "$HOME/.config/opencode/config.json" "$CONFIGS_DIR/opencode/"
fi
if [ -f "$HOME/.local/bin/lemonade-opencode-proxy.py" ]; then
    cp "$HOME/.local/bin/lemonade-opencode-proxy.py" "$CONFIGS_DIR/opencode/"
fi
if [ -f "$HOME/.config/systemd/user/lemonade-opencode-proxy.service" ]; then
    cp "$HOME/.config/systemd/user/lemonade-opencode-proxy.service" "$CONFIGS_DIR/opencode/"
fi

echo "==> [4/4] Vérification de l'état Git..."
git -C "$REPO_DIR" status -s

echo "==> Synchronisation terminée avec succès !"
