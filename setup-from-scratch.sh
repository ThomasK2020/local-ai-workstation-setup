#!/usr/bin/env bash
# ==============================================================================
# ALL-IN-ONE FROM SCRATCH DEPLOYMENT SCRIPT (HP Z2 Mini & HP Z6 Server)
# ==============================================================================
# Usage:
#   sudo ./setup-from-scratch.sh [--with-hermes] [--vllm|--lemonade]
#                                [--skip-opencode] [--skip-projects] [--usb-import <path>]
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
SKIP_OPENCODE=false
SKIP_PROJECTS=false
ENGINE_FLAG=""
USB_PATH=""

# Parse CLI arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-opencode|--without-opencode)
            SKIP_OPENCODE=true
            shift
            ;;
        --skip-projects|--without-projects)
            SKIP_PROJECTS=true
            shift
            ;;
        --vllm|--engine-vllm)
            ENGINE_FLAG="--vllm"
            shift
            ;;
        --lemonade|--engine-lemonade)
            ENGINE_FLAG="--lemonade"
            shift
            ;;
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
SETUP_ARGS=()
if [ "$WITH_HERMES" = true ]; then
    SETUP_ARGS+=("--with-hermes")
fi
if [ -n "$ENGINE_FLAG" ]; then
    SETUP_ARGS+=("$ENGINE_FLAG")
    if [ "$ENGINE_FLAG" == "--vllm" ]; then
        export ENGINE="vllm"
    elif [ "$ENGINE_FLAG" == "--lemonade" ]; then
        export ENGINE="lemonade"
    fi
fi

sudo ENGINE="${ENGINE:-}" bash "${SETUP_DIR}/setup.sh" "${SETUP_ARGS[@]+"${SETUP_ARGS[@]}"}"

# Step 2: Import LLMs from USB if path provided
if [[ -n "${USB_PATH}" ]] && [ -d "${USB_PATH}" ]; then
    echo "======================================================================"
    echo "💾 Importing LLM models offline from ${USB_PATH}..."
    echo "======================================================================"
    bash "${SETUP_DIR}/backup-models.sh" import "${USB_PATH}"
fi

# Step 3: User session & OpenCode Setup
echo "======================================================================"
echo "⚙️ Configuring User Session (LocalAIDemoUser)..."
echo "======================================================================"
USER_ARGS=()
if [ "$RESET_DEMO" = true ]; then
    USER_ARGS+=("--reset-demo")
fi
if [ "$SKIP_OPENCODE" = true ]; then
    USER_ARGS+=("--skip-opencode")
fi

bash "${SETUP_DIR}/setup-user.sh" "${USER_ARGS[@]+"${USER_ARGS[@]}"}"

# Step 4 & 5: Restore GitHub Repositories & Docker Projects if not skipped
if [ "$SKIP_PROJECTS" = false ]; then
    echo "======================================================================"
    echo "📦 Restoring GitHub Repositories..."
    echo "======================================================================"
    bash "${SETUP_DIR}/setup-projects.sh"

    echo "======================================================================"
    echo "🐳 Deploying Dockerized Projects (Flatfox, Astra Monitor, Pirates Bay)..."
    echo "======================================================================"
    bash "${SETUP_DIR}/setup-docker-projects.sh"
else
    echo "======================================================================"
    echo "ℹ️ Skipping GitHub Repositories & Docker Projects setup (--skip-projects)."
    echo "======================================================================"
fi

echo "======================================================================"
echo "🎉 Full 'From Scratch' Deployment Completed Successfully!"
echo "======================================================================"
