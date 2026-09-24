#!/usr/bin/env bash
# ==============================================================================
# ALL-IN-ONE FROM SCRATCH DEPLOYMENT SCRIPT (HP Z2 Mini & HP Z6 Server)
# ==============================================================================
# Usage:
#   sudo ./setup-from-scratch.sh [--with-hermes] [--demo-profile|--reset-demo] [--usb-import <path>]
# ==============================================================================
set -euo pipefail

# Ensure script is executed as root/sudo
if [ "$EUID" -ne 0 ]; then
    echo "❌ Error: setup-from-scratch.sh requires root privileges."
    echo "👉 Please re-run with sudo: sudo ./setup-from-scratch.sh $@"
    exit 1
fi

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WITH_HERMES=false
RESET_DEMO=false
USB_PATH=""

# Parse CLI arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --with-hermes|-hermes-setup)
            WITH_HERMES=true
            shift
            ;;
        --reset-demo|--force-demo)
            RESET_DEMO=true
            shift
            ;;
        --demo-profile|--demo-user)
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
echo "⚙️ Configuring User Session & OpenCode CLI (LocalAIDemoUser)..."
echo "======================================================================"
if [ "$RESET_DEMO" = true ]; then
    bash "${SETUP_DIR}/setup-user.sh" --reset-demo
else
    bash "${SETUP_DIR}/setup-user.sh" --demo-profile
fi

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
