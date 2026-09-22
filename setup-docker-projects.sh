#!/usr/bin/env bash
# ==============================================================================
# AUTOMATED MULTI-PROJECT DOCKER & OPENCODE SETUP SCRIPT
# ==============================================================================
set -euo pipefail

PROJECTS_DIR="${HOME}/Projects"
mkdir -p "${PROJECTS_DIR}"

echo "🚀 Setting up Dockerized Projects under ${PROJECTS_DIR}..."

# 1. Flatfox Rental Agent
cd "${PROJECTS_DIR}"
if [ ! -d "zurich-rental-flatfox-agent" ]; then
    echo "Cloning Zurich Rental Flatfox Agent..."
    git clone https://github.com/ThomasK2020/zurich-rental-flatfox-agent.git
fi
if [ -d "zurich-rental-flatfox-agent" ]; then
    cd zurich-rental-flatfox-agent
    echo "Starting Docker container for Flatfox Agent..."
    docker compose up -d --build
fi

# 2. Astra Monitor Daemon
cd "${PROJECTS_DIR}"
if [ ! -d "astra-monitor-plugin" ]; then
    echo "Initializing Astra Monitor workspace..."
    mkdir -p astra-monitor-plugin
fi
if [ -d "astra-monitor-plugin" ] && [ -f "astra-monitor-plugin/docker-compose.yml" ]; then
    cd astra-monitor-plugin
    docker compose up -d --build
fi

# 3. Pirates Bay Sandbox
cd "${PROJECTS_DIR}"
if [ ! -d "pirates_bay_local_coding" ]; then
    echo "Initializing Pirates Bay workspace..."
    mkdir -p pirates_bay_local_coding/workspace
fi
if [ -d "pirates_bay_local_coding" ] && [ -f "pirates_bay_local_coding/docker-compose.yml" ]; then
    cd pirates_bay_local_coding
    docker compose up -d --build
fi

echo "======================================================================"
echo "✅ All 3 projects configured and running under Docker Compose!"
echo "======================================================================"
