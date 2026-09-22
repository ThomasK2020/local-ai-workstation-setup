#!/usr/bin/env bash
# ==============================================================================
# ALL-IN-ONE FROM SCRATCH DEPLOYMENT SCRIPT (HP Z2 Mini & HP Z6 Server)
# ==============================================================================
# Usage:
#   sudo ./setup-from-scratch.sh [--with-hermes] [--usb-import <path>]
# ==============================================================================
set -euo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WITH_HERMES=false
USB_PATH=""

# Parse CLI arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --with-hermes|-hermes-setup)
            WITH_HERMES=true
            shift
            ;;
        --usb-import)
            USB_PATH="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

echo "======================================================================"
echo "🚀 Starting Full 'From Scratch' Local AI Deployment"
echo "======================================================================"

# Step 1: Execute Root System & Docker Setup
if [ "$WITH_HERMES" = true ]; then
    sudo bash "${SETUP_DIR}/setup.sh" --with-hermes
else
    sudo bash "${SETUP_DIR}/setup.sh"
fi

# Step 2: Import LLMs from USB if path provided
if [[ -n "${USB_PATH}" ]] && [ -d "${USB_PATH}" ]; then
    echo "======================================================================"
    echo "💾 Importing LLM models offline from ${USB_PATH}..."
    echo "======================================================================"
    bash "${SETUP_DIR}/backup-models.sh" import "${USB_PATH}"
fi

# Step 3: User session & OpenCode Setup
echo "======================================================================"
echo "⚙️ Configuring User Session & OpenCode CLI..."
echo "======================================================================"
bash "${SETUP_DIR}/setup-user.sh"

# Step 4: Restore GitHub Repositories
echo "======================================================================"
echo "📦 Restoring GitHub Repositories..."
echo "======================================================================"
bash "${SETUP_DIR}/setup-projects.sh"

# Step 5: Deploy Docker Compose Multi-Projects
echo "======================================================================"
echo "🐳 Deploying Dockerized Projects (Flatfox, Astra Monitor, Pirates Bay)..."
echo "======================================================================"
bash "${SETUP_DIR}/setup-docker-projects.sh"

echo "======================================================================"
echo "🎉 Full 'From Scratch' Deployment Completed Successfully!"
echo "======================================================================"
