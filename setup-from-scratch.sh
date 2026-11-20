#!/usr/bin/env bash
# ==============================================================================
# ALL-IN-ONE FROM SCRATCH DEPLOYMENT ORCHESTRATOR
# ==============================================================================
set -euo pipefail

# Ensure script is executed as root/sudo
if [ "$EUID" -ne 0 ]; then
    echo "❌ Error: setup-from-scratch.sh requires root privileges."
    echo "👉 Please re-run with sudo: sudo ./setup-from-scratch.sh $@"
    exit 1
fi

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_USER="${SUDO_USER:-$LOGNAME}"

WITH_HERMES=true
PROFILE_NAME="amd-tk"
SETUP_OPENCODE=false
SETUP_PROJECTS=false
SETUP_ALL_PROJECTS=false
MODULE_FLAGS=()
CUSTOM_MODEL=""
ENGINE_FLAG="--lemonade"
DOCKER_SUBNET="172.28.0.0/16"
USB_PATH=""

show_help() {
    echo "======================================================================"
    echo "🤖 SETUP-FROM-SCRATCH.SH — All-in-One Local AI Workstation Orchestrator"
    echo "======================================================================"
    echo "Usage: sudo ./setup-from-scratch.sh [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help                          Show this help message"
    echo "  --profile <name>                    Set Hermes profile to restore (default: amd-tk)"
    echo "  --without-hermes, --skip-hermes     Skip Hermes Agent restoration and CLI setup"
    echo "  --lemonade, --engine-lemonade       Use Lemonade Server Engine (Port 13305 / 8001 / 8002)"
    echo "  --vllm, --engine-vllm               Use vLLM Server Engine (Port 8000)"
    echo "  --both-engines, --dual-engine       Install BOTH Lemonade (13305) AND vLLM (8000) engines"
    echo "  --setup-opencode, --with-opencode   [Opt-in] Install and configure OpenCode CLI"
    echo "  --setup-projects, --with-projects   [Opt-in] Clone ALL application repositories & launch Docker"
    echo "  --module <name>                     [Opt-in] Install module(s) (repeatable/comma-separated: tokenwatcher-topbar, tokenwatcher-widget, flatfox, pirates-bay, dj-mix)"
    echo "  --model <id_or_url>                 Download custom Hugging Face model ID or direct URL"
    echo "  --docker-subnet <CIDR>              Set custom Docker address pool CIDR (default: 172.28.0.0/16)"
    echo "  --usb-import <path>                 Import models offline from USB directory"
    echo ""
    exit 0
}

# Parse CLI arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            ;;
        --profile|-p)
            PROFILE_NAME="$2"
            shift 2
            ;;
        --without-hermes|--skip-hermes)
            WITH_HERMES=false
            shift
            ;;
        --setup-opencode|--with-opencode)
            SETUP_OPENCODE=true
            shift
            ;;
        --setup-projects|--with-projects)
            SETUP_PROJECTS=true
            SETUP_ALL_PROJECTS=true
            shift
            ;;
        --module|--modules)
            MODULE_FLAGS+=("$2")
            SETUP_PROJECTS=true
            shift 2
            ;;
        --model)
            CUSTOM_MODEL="$2"
            shift 2
            ;;
        --vllm|--engine-vllm)
            ENGINE_FLAG="--vllm"
            shift
            ;;
        --lemonade|--engine-lemonade)
            ENGINE_FLAG="--lemonade"
            shift
            ;;
        --both-engines|--dual-engine|--both)
            ENGINE_FLAG="--both-engines"
            shift
            ;;
        --docker-subnet)
            DOCKER_SUBNET="$2"
            shift 2
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

# Step 0: HERMES FIRST (User Session Restorer)
if [ "$WITH_HERMES" = true ]; then
    echo "======================================================================"
    echo "🤖 [Step 0/6] Hermes Agent First — Restoring Profile '${PROFILE_NAME}'"
    echo "======================================================================"
    sudo -u "${REAL_USER}" bash "${SETUP_DIR}/Deploy-Hermes-Perso-data.sh" restore --profile "${PROFILE_NAME}" || true
else
    echo "ℹ️ Skipping Hermes Agent First setup (--without-hermes)."
fi

# Step 1: Execute Root System & Docker Setup
echo "======================================================================"
echo "🚀 [Step 1/6] Installing Root Infrastructure & Engines"
echo "======================================================================"
SETUP_ARGS=("${ENGINE_FLAG}" "--docker-subnet" "${DOCKER_SUBNET}")
if [ "$WITH_HERMES" = true ]; then
    SETUP_ARGS+=("--with-hermes")
fi

bash "${SETUP_DIR}/setup.sh" "${SETUP_ARGS[@]}"

# Step 2: Download Models (Online default or USB import)
echo "======================================================================"
echo "📥 [Step 2/6] LLM Model Download & Pre-Loading"
echo "======================================================================"
if [ -n "${USB_PATH}" ] && [ -d "${USB_PATH}" ]; then
    echo "💾 Importing models offline from USB (${USB_PATH})..."
    bash "${SETUP_DIR}/backup-models.sh" import "${USB_PATH}"
else
    DOWNLOAD_ARGS=("${ENGINE_FLAG}")
    if [ -n "${CUSTOM_MODEL}" ]; then
        DOWNLOAD_ARGS+=("--model" "${CUSTOM_MODEL}")
    fi
    bash "${SETUP_DIR}/download-models.sh" "${DOWNLOAD_ARGS[@]}"
fi

# Step 3: User Session & OpenCode Setup (Opt-In)
if [ "$SETUP_OPENCODE" = true ]; then
    echo "======================================================================"
    echo "⚙️ [Step 3/6] Configuring OpenCode CLI & Proxy for User '${REAL_USER}'"
    echo "======================================================================"
    USER_ARGS=("--profile" "${PROFILE_NAME}" "--setup-opencode")
    if [ "$WITH_HERMES" = true ]; then
        USER_ARGS+=("--hermes")
    fi
    sudo -u "${REAL_USER}" bash "${SETUP_DIR}/setup-user.sh" "${USER_ARGS[@]}"
else
    echo "ℹ️ Skipping OpenCode CLI setup (use --setup-opencode to enable)."
fi

# Step 4 & 5: Restore Projects & Docker Containers (Opt-In; NO projects installed by default)
if [ "$SETUP_PROJECTS" = true ]; then
    echo "======================================================================"
    echo "📦 [Step 4/6] Restoring Application Repositories..."
    echo "======================================================================"
    PROJECT_ARGS=()
    NEED_DOCKER_PROJECTS=false
    if [ "$SETUP_ALL_PROJECTS" = true ] && [ ${#MODULE_FLAGS[@]} -eq 0 ]; then
        PROJECT_ARGS+=("--all")
        NEED_DOCKER_PROJECTS=true
    else
        for mf in "${MODULE_FLAGS[@]}"; do
            PROJECT_ARGS+=("--module" "${mf}")
            case ",${mf}," in
                *,flatfox,*|*,pirates-bay,*|*,piratesbay,*) NEED_DOCKER_PROJECTS=true ;;
            esac
        done
    fi
    sudo -u "${REAL_USER}" bash "${SETUP_DIR}/setup-projects.sh" "${PROJECT_ARGS[@]+"${PROJECT_ARGS[@]}"}"

    if [ "$NEED_DOCKER_PROJECTS" = true ]; then
        echo "======================================================================"
        echo "🐳 [Step 5/6] Deploying Dockerized Projects..."
        echo "======================================================================"
        bash "${SETUP_DIR}/setup-docker-projects.sh"
    else
        echo "ℹ️ Skipping Dockerized app containers (no Docker project module selected)."
    fi
else
    echo "ℹ️ Skipping Projects & Docker containers (default: no projects installed; use --setup-projects or --module <name>)."
fi

# Step 6: Diagnostic & Final Health Check
echo "======================================================================"
echo "📊 [Step 6/6] Final Diagnostic & System Health Check"
echo "======================================================================"
sudo -u "${REAL_USER}" bash "${SETUP_DIR}/localAI-check-status.sh" || true

echo "======================================================================"
echo "🎉 Full Deployment Completed Successfully!"
echo "======================================================================"
