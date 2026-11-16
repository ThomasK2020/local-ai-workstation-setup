#!/usr/bin/env bash
# ==============================================================================
# LOCAL AI SYSTEM STATUS & HEALTH CHECK DIAGNOSTIC
# ==============================================================================
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "======================================================================"
echo -e "${BLUE}🔍 LOCAL AI WORKSTATION STATUS DIAGNOSTIC${NC}"
echo "======================================================================"

# 1. Check Lemonade Server (Port 13305)
echo -n "1. Lemonade Server (Port 13305) : "
if curl -s http://localhost:13305/v1/models >/dev/null 2>&1; then
    MODELS=$(curl -s http://localhost:13305/v1/models | jq -r '.data[].id' 2>/dev/null | tr '\n' ', ' | sed 's/, $//')
    echo -e "${GREEN}🟢 ONLINE${NC} (Models: ${MODELS:-None})"
else
    echo -e "${RED}🔴 OFFLINE${NC} (Service snap.lemonade-server.daemon not responding on port 13305)"
fi

# 2. Check vLLM Server (Port 8000)
echo -n "2. vLLM Server (Port 8000)      : "
if curl -s http://localhost:8000/v1/models >/dev/null 2>&1; then
    VLLM_MODELS=$(curl -s http://localhost:8000/v1/models | jq -r '.data[].id' 2>/dev/null | tr '\n' ', ' | sed 's/, $//')
    echo -e "${GREEN}🟢 ONLINE${NC} (Models: ${VLLM_MODELS:-None})"
else
    echo -e "${YELLOW}⚪ INACTIVE / OPTIONAL${NC} (vLLM service on port 8000 not running)"
fi

# 3. Check OpenCode Python Proxy (Port 13306)
echo -n "3. OpenCode Proxy (Port 13306)  : "
if curl -s http://localhost:13306/v1/models >/dev/null 2>&1; then
    echo -e "${GREEN}🟢 ONLINE${NC} (Proxy listening on http://localhost:13306/v1)"
else
    echo -e "${YELLOW}⚪ INACTIVE / OPTIONAL${NC} (Proxy on port 13306 not running)"
fi

# 4. Check Open WebUI (Port 8082 / 8080)
echo -n "4. Open WebUI (Port 8082/8080)  : "
if curl -s http://localhost:8082 >/dev/null 2>&1; then
    echo -e "${GREEN}🟢 ONLINE${NC} (Running on http://localhost:8082)"
elif curl -s http://localhost:8080 >/dev/null 2>&1; then
    echo -e "${GREEN}🟢 ONLINE${NC} (Running on http://localhost:8080)"
else
    echo -e "${YELLOW}⚪ INACTIVE / OPTIONAL${NC} (Open WebUI container/service not running)"
fi

# 5. Check Hermes Agent Profile
echo -n "5. Hermes Agent CLI/Desktop     : "
if command -v hermes &>/dev/null; then
    ACTIVE_PROF=$(cat ~/.hermes/active_profile 2>/dev/null || echo "default")
    echo -e "${GREEN}🟢 INSTALLED${NC} (Active Profile: '${ACTIVE_PROF}')"
else
    echo -e "${YELLOW}⚪ NOT INSTALLED${NC} (Hermes CLI missing)"
fi

# 6. Check Docker Engine & Active Containers
echo "----------------------------------------------------------------------"
echo -e "${BLUE}🐳 Docker Engine & Running Containers:${NC}"
echo "----------------------------------------------------------------------"
if command -v docker &>/dev/null && docker ps >/dev/null 2>&1; then
    RUNNING_COUNT=$(docker ps -q | wc -l)
    if [ "$RUNNING_COUNT" -gt 0 ]; then
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    else
        echo "ℹ️ Docker daemon active (0 running containers)."
    fi
else
    echo -e "${RED}🔴 Docker daemon inactive or permission denied.${NC}"
fi

echo "======================================================================"
echo -e "${GREEN}✅ Diagnostic Completed!${NC}"
echo "======================================================================"
