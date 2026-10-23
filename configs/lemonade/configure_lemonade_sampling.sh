#!/usr/bin/env bash
set -euo pipefail

echo "==> Configuration des paramètres Vulkan de Lemonade..."
lemonade config set llamacpp.vulkan_args="-fa on -b 512 -ub 128 --cache-reuse 256 -ctk q8_0 -ctv q8_0 --temp 0.2 --repeat-penalty 1.0"

echo "==> Redémarrage du service Lemonade natif (lemond)..."
sudo systemctl restart lemond.service

echo "==> Attente de disponibilité du serveur..."
sleep 3

echo "==> Chargement de Qwen3-Coder-30B-A3B-Instruct-GGUF..."
lemonade load Qwen3-Coder-30B-A3B-Instruct-GGUF

echo "==> Lemonade est prêt avec Qwen Coder !"
