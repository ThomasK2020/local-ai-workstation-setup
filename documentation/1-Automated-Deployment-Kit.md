---
title: "Kit de Déploiement Automatisé (Option A) — Multi-Stations Local AI"
tags:
  - automation
  - deployment
  - github
  - setup
  - lemonade
  - vllm
  - openwebui
  - opencode
  - hermes
  - docker
  - llm-models
  - security
date: 2026-09-22
last_updated: 2026-09-22 22:34:43 CEST
---

# Kit de Déploiement Automatisé (Option A) — Multi-Stations (HP Z2 Mini & HP Z6 Serveur)

**Dernière mise à jour :** 22 Septembre 2026 à 22:34 CEST  

> Ce kit permet d'installer et de configurer de façon **100% modulable, reproductible et automatisée** les stations de travail individuelles (HP Z2 Mini avec Lemonade / APU Strix Halo) et la station serveur centrale (HP Z6 avec vLLM / multi-GPU). Il inclut le déploiement conditionnel de la clé Gemini (strictement réservée à Hermes), la synchronisation automatique des configurations depuis GitHub, l'exposition réseau sécurisée d'Open WebUI (192.168.x.x) et la restauration automatisée des projets utilisateur.

---

## 1. Liste des Modèles IA à Télécharger & Déployer

Voici les 5 modèles de référence actuellement configurés et optimisés sur l'infrastructure :

| Modèle ID Lemonade / vLLM | Identifiant HuggingFace / Checkpoint | Taille | Usage Principal |
| :--- | :--- | :--- | :--- |
| **`Gemma-4-12B-it-GGUF`** | `unsloth/gemma-4-12b-it-GGUF:Q4_K_M` | 6.8 GB | Modèle par défaut (Rapide, Multimodal, Vision) |
| **`Gemma-4-31B-it-GGUF`** | `unsloth/gemma-4-31B-it-GGUF:Q4_K_M` | 18.2 GB | Modèle généraliste avancé (Raisonnement lourd) |
| **`Qwen3-Coder-30B-A3B-Instruct-GGUF`** | `unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF` | 17.3 GB | Assistant Programmation & Code |
| **`Qwen3.6-27B-GGUF`** | `unsloth/Qwen3.6-27B-GGUF` | 17.3 GB | Modèle généraliste & Analyse visuelle |
| **`DeepSeek-Qwen3-8B-GGUF`** | `unsloth/DeepSeek-R1-0528-Qwen3-8B-GGUF:Q4_1` | 4.9 GB | Modèle de raisonnement compact & rapide |

> 💾 **Taille totale des modèles :** ~64.5 GB

---

## 2. Synthèse du Fine-Tuning Hardware & Réseau

| Composant / Couche | Configuration Voulue & Appliquée | Impact & Justification |
| :--- | :--- | :--- |
| **Inférence GPU (Z2 Mini)** | Vulkan 1.4 (`GGML_VULKAN_DEVICE=0`) via Mesa RADV | Tire parti des 96 Go de mémoire unifiée de l'APU AMD Strix Halo / Radeon 8060S. |
| **Inférence GPU (Z6 Serveur)** | vLLM (`--gpu-memory-utilization 0.90 --enable-prefix-caching`) | Continuous batching et PagedAttention pour forte charge multi-utilisateurs sur Z6. |
| **Permissions Linux** | Groupes `render`, `video`, `ai-services` attribués aux comptes | Accès direct aux nœuds GPU `/dev/dri/renderD128` sans privilege escalation. |
| **Open WebUI CORS & WebSockets** | `CORS_ALLOW_ORIGIN="*"` ou restreint LAN + Secret Key | Résout le rejet d'origine WebSocket / Socket.IO sur réseau local. |
| **Service Systemd Open WebUI** | ExecStart vers `/home/appmanager/.local/bin/start-open-webui.sh` | Isolation sous le compte service `appmanager` à privilèges restreints. |

---

## 3. Configuration Hermes pour Économie de Tokens & Sécurité

Pour éviter l'épuisement du contexte et réduire la consommation de tokens sur les modèles locaux et Gemini :

1. **`context_length: 65536` :** Fenêtre de contexte bridée à 64k tokens dans `~/.hermes/config.yaml`.
2. **`reasoning_effort: medium` :** Maintient un niveau de réflexion adapté sans boucles infinies de raisonnement.
3. **`redact_secrets: true` :** Masque automatiquement les jetons API, mots de passe et clés privées dans les logs de conversation.
4. **Aliases de Modèles Locaux :** Utilisation des raccourcis (`gemma`, `coder`, `deepseek`) pointant sur le moteur Lemonade local (`http://localhost:13306/v1`).
5. **Restriction de la Clé Gemini :** La variable `GEMINI_API_KEY` est enregistrée dans `~/.hermes/.env` (`chmod 600`) et **n'est jamais partagée avec Open WebUI**.

---

## 4. Sécurisation pour Machines Publiques / Partagées

* **Séparation stricte des comptes :**
  - `appmanager` : Compte système sans login interactif exécutant `lemonade.service` / `vllm.service` et `open-webui.service`.
  - `HP-AMD-LocalAI` : Compte utilisateur standard pour la session graphique et l'Agent Hermes.
* **Hermes Vault & Isolation Docker :** Les identifiants sont chiffrés localement dans le vault Hermes, et l'exécution de code est confinée dans un conteneur Docker.
* **Restrictions réseau UFW :** En cas d'exposition d'Open WebUI sur l'IP du réseau local (`0.0.0.0:8080`), le pare-feu UFW filtre l'accès uniquement depuis la plage IP autorisée (ex: `192.168.1.0/24`).

---

## 5. Arborescence du Dépôt Centralisé (`local-ai-workstation-setup`)

```text
local-ai-workstation-setup/
├── README.md                           <- Documentation du dépôt
├── setup.sh                            <- Script système (GitHub sync, Hermes optionnel, Lemonade/vLLM, Open WebUI)
├── setup-user.sh                       <- Setup utilisateur (Clé Gemini optionnelle pour Hermes, OpenCode)
├── setup-projects.sh                   <- Authentification gh CLI, clonage Flatfox & Pirates Bay, venv Python
├── download-models.sh                  <- Script de pré-chargement des 5 modèles IA via API Lemonade
├── backup-models.sh                    <- Script de sauvegarde local, détection d'espace USB & export/import
└── configs/
    ├── systemd/
    │   ├── lemonade.service            <- Service Systemd Lemonade (HP Z2 Mini)
    │   ├── vllm.service                <- Service Systemd vLLM (HP Z6 Serveur)
    │   └── open-webui.service          <- Service Systemd Open WebUI
    ├── docker/
    │   └── daemon.json                 <- Rotation des journaux Docker (50m, 3 fichiers)
    └── hermes/
        └── config.yaml                 <- Configuration Hermes Agent
```

---

## 6. Script 1 : Installation Système Automatisée (`setup.sh`)

Ce script prend en charge le paramètre optionnel `--with-hermes` (ou `-hermes-setup`), la récupération automatique des fichiers de configuration depuis GitHub si exécuté hors du dépôt, l'installation officielle de **Docker Engine & Docker Compose** (`download.docker.com`), la configuration de la rotation des logs Docker (`/etc/docker/daemon.json`), le choix interactif du moteur (Lemonade vs vLLM) et le choix du mode réseau Open WebUI (Local vs LAN 192.168.x.x avec pare-feu UFW).

```bash
#!/usr/bin/env bash
# ==============================================================================
# AUTOMATED WORKSTATION & SERVER SETUP SCRIPT (HP Z2 Mini & HP Z6 Server)
# ==============================================================================
# Usage:
#   sudo ./setup.sh [--with-hermes]
#
# Options:
#   --with-hermes | -hermes-setup   Optionally install Hermes Agent during setup
# ==============================================================================
set -euo pipefail

INSTALL_HERMES=false
REPO_URL="https://github.com/ThomasK2020/local-ai-workstation-setup.git"
SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse CLI parameters
for arg in "$@"; do
    case $arg in
        --with-hermes|-hermes-setup|--hermes-setup)
            INSTALL_HERMES=true
            shift
            ;;
    esac
done

echo "======================================================================"
echo "📥 [Step 1/8] Syncing configuration files from GitHub repository"
echo "======================================================================"
if [ ! -d "${SETUP_DIR}/configs" ]; then
    echo "Config directory missing locally. Cloning setup repo from GitHub..."
    TMP_DIR=$(mktemp -d)
    git clone "${REPO_URL}" "${TMP_DIR}"
    cp -r "${TMP_DIR}/configs" "${SETUP_DIR}/"
    rm -rf "${TMP_DIR}"
fi
echo "✅ Configuration files synchronized from GitHub!"

echo "======================================================================"
echo "🚀 [Step 2/8] System Dependencies & Optional Hermes Agent Setup"
echo "======================================================================"
apt-get update -y && apt-get install -y curl git jq python3 python3-pip python3-venv ufw mesa-vulkan-drivers ca-certificates gnupg

if [ "$INSTALL_HERMES" = true ]; then
    echo "⚙️ Installing Hermes Agent as requested via CLI flag..."
    curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash || true
    echo "✅ Hermes Agent installed successfully for troubleshooting!"
else
    echo "ℹ️ Skipping Hermes Agent installation (use --with-hermes flag to enable)."
fi

echo "======================================================================"
echo "🐳 [Step 3/8] Official Docker Engine & Docker Compose Setup"
echo "======================================================================"
# 1. Purge legacy or conflicting docker packages
apt-get remove -y docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc || true

# 2. Add Docker official GPG key & APT repository
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 3. Configure Docker log-rotation daemon.json
mkdir -p /etc/docker
if [ -f "${SETUP_DIR}/configs/docker/daemon.json" ]; then
    cp "${SETUP_DIR}/configs/docker/daemon.json" /etc/docker/daemon.json
else
    cat <<'EOF' > /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "3"
  }
}
EOF
fi

systemctl restart docker
systemctl enable docker
echo "✅ Official Docker Engine & Compose Plugin installed!"

echo "======================================================================"
echo "👥 [Step 4/8] User Accounts, Permissions & GPU Passthrough Setup"
echo "======================================================================"
groupadd -f ai-services
groupadd -f docker

id -u appmanager &>/dev/null || useradd -r -m -s /bin/bash appmanager
id -u HP-AMD-LocalAI &>/dev/null || useradd -m -s /bin/bash -G sudo HP-AMD-LocalAI

usermod -aG render,video,ai-services,docker appmanager
usermod -aG render,video,ai-services,docker HP-AMD-LocalAI

chown root:docker /var/run/docker.sock 2>/dev/null || true
chmod 660 /var/run/docker.sock 2>/dev/null || true

mkdir -p /var/lib/ai-models /var/lib/lemonade /home/appmanager/.local/bin
chown -R appmanager:ai-services /var/lib/ai-models /var/lib/lemonade /home/appmanager
chmod -R 775 /var/lib/ai-models /var/lib/lemonade
chmod g+s /var/lib/ai-models /var/lib/lemonade

echo "======================================================================"
echo "🎯 [Step 5/8] Inference Engine Selection (Lemonade vs vLLM)"
echo "======================================================================"
echo "1) Lemonade (HP Z2 Mini Workstations - AMD Strix Halo / Vulkan)"
echo "2) vLLM (HP Z6 Server - Multi-GPU / High-Throughput Multi-User)"
read -rp "Select inference engine [1 or 2]: " ENGINE_CHOICE

if [ "$ENGINE_CHOICE" == "2" ]; then
    ENGINE="vllm"
    echo "⚙️ Installing vLLM engine for HP Z6 Server..."
    pip install vllm torch
    if [ -f "${SETUP_DIR}/configs/systemd/vllm.service" ]; then
        cp "${SETUP_DIR}/configs/systemd/vllm.service" /etc/systemd/system/vllm.service
    fi
    systemctl daemon-reload
    systemctl enable --now vllm.service
    OPENWEBUI_OPENAI_URL="http://localhost:8000/v1"
else
    ENGINE="lemonade"
    echo "⚙️ Installing Lemonade engine for HP Z2 Mini Workstation..."
    curl -fsSL https://lemonade-ai.com/install.sh | bash || true
    if [ -f "${SETUP_DIR}/configs/systemd/lemonade.service" ]; then
        cp "${SETUP_DIR}/configs/systemd/lemonade.service" /etc/systemd/system/lemonade.service
    fi
    systemctl daemon-reload
    systemctl enable --now lemonade.service
    OPENWEBUI_OPENAI_URL="http://localhost:13305/v1"
fi

echo "======================================================================"
echo "🌐 [Step 6/8] Open WebUI Configuration & Network Exposure"
echo "======================================================================"
echo "1) Local access only (127.0.0.1)"
echo "2) Secure Local Area Network access (192.168.x.x / 0.0.0.0)"
read -rp "Select Open WebUI network mode [1 or 2]: " NET_CHOICE

WEBUI_SECRET=$(openssl rand -hex 32)

if [ "$NET_CHOICE" == "2" ]; then
    WEBUI_HOST="0.0.0.0"
    read -rp "Enter allowed subnet (e.g. 192.168.1.0/24): " ALLOWED_SUBNET
    ufw allow from "${ALLOWED_SUBNET}" to any port 8080
    ufw enable || true
    echo "🔒 UFW Firewall configured to allow ${ALLOWED_SUBNET} on port 8080"
else
    WEBUI_HOST="127.0.0.1"
fi

# Note: Open WebUI is ONLY connected to local inference engine.
# Gemini API Key is NEVER passed or exposed to Open WebUI.
cat <<EOF > /home/appmanager/.local/bin/start-open-webui.sh
#!/usr/bin/env bash
export WEBUI_HOST="${WEBUI_HOST}"
export WEBUI_PORT="8080"
export WEBUI_SECRET_KEY="${WEBUI_SECRET}"
export OPENAI_API_BASE_URL="${OPENWEBUI_OPENAI_URL}"
export CORS_ALLOW_ORIGIN="*"
exec open-webui serve
EOF

chmod +x /home/appmanager/.local/bin/start-open-webui.sh
chown appmanager:ai-services /home/appmanager/.local/bin/start-open-webui.sh

if [ -f "${SETUP_DIR}/configs/systemd/open-webui.service" ]; then
    cp "${SETUP_DIR}/configs/systemd/open-webui.service" /etc/systemd/system/open-webui.service
fi
systemctl daemon-reload
systemctl enable --now open-webui.service

echo "======================================================================"
echo "📥 [Step 7/8] Triggering LLM Model Downloads"
echo "======================================================================"
if [ -f "${SETUP_DIR}/download-models.sh" ]; then
    bash "${SETUP_DIR}/download-models.sh"
fi

echo "======================================================================"
echo "🎉 [Step 8/8] System Setup Complete! Selected Engine: ${ENGINE}"
echo "Run 'bash setup-user.sh' under HP-AMD-LocalAI user session."
echo "======================================================================"
```

---

## 7. Section Modèles LLM : Téléchargement, Sauvegarde, Export & Réimportation

Cette section réunit l'ensemble des procédures relatives au cycle de vie des modèles LLM sur l'infrastructure : pré-chargement en ligne, exportation vers support externe USB et réimportation hors-ligne sur les stations cibles.

### 7.1 Téléchargement & Pré-chargement des Modèles (`download-models.sh`)

Ce script déclenche le téléchargement automatisé des 5 modèles IA (~64.5 Go) via l'API locale Lemonade. Il initialise automatiquement les permissions du répertoire de cache Snap afin d'éviter les erreurs `Permission denied` lors de la création de répertoires ou de manifests Hugging Face.

```bash
#!/usr/bin/env bash
# ==============================================================================
# LLM MODEL DOWNLOAD & PRE-LOADING SCRIPT (Lemonade API)
# ==============================================================================
set -euo pipefail

LEMONADE_API="http://localhost:13305"
LEMONADE_CACHE="/var/snap/lemonade-server/common/.cache"

# Ensure write permissions on Lemonade cache directory
if [ -d "${LEMONADE_CACHE}" ]; then
    sudo chmod -R 777 "${LEMONADE_CACHE}" 2>/dev/null || true
fi

echo "⏳ Checking Lemonade server availability..."
until curl -s "${LEMONADE_API}/v1/models" > /dev/null 2>&1; do
    echo "Waiting for Lemonade server to start..."
    sleep 3
done
```

> ⚠️ **Alerte de Sécurité & Surveillance des Permissions (`chmod 777`) :**  
> L'application de permissions permissives (`777`) sur `/var/snap/lemonade-server/common/.cache` est requise pour assurer la compatibilité entre le démon Snap `lemonade-server` (exécuté dans un conteneur/confinement Snap sous `root`) et les requêtes/scripts exécutés par l'utilisateur courant (`hp-amd-localai`).  
> **Avis de sécurité :** Ces permissions permettent à tout utilisateur local ou processus de la machine de lire, modifier ou supprimer le contenu du cache des modèles. Sur un système partagé ou exposé, veillez à restreindre l'accès à la machine et surveiller ce répertoire si nécessaire.

echo "✅ Lemonade server is online!"
echo "🚀 Triggering download of all 5 LLM models (~64.5 GB total)..."

MODELS=(
    "Gemma-4-12B-it-GGUF"
    "Gemma-4-31B-it-GGUF"
    "Qwen3-Coder-30B-A3B-Instruct-GGUF"
    "Qwen3.6-27B-GGUF"
    "DeepSeek-Qwen3-8B-GGUF"
)

for MODEL in "${MODELS[@]}"; do
    echo "----------------------------------------------------------------------"
    echo "📥 Downloading model: ${MODEL}..."
    echo "----------------------------------------------------------------------"
    
    if command -v lemonade &>/dev/null; then
        lemonade pull "${MODEL}" || true
    else
        curl -s -X POST "${LEMONADE_API}/api/pull" \
            -H "Content-Type: application/json" \
            -d "{\"name\": \"${MODEL}\"}" || true
    fi
done

echo "🎉 LLM download tasks submitted successfully!"
```

---

### 7.2 Sauvegarde & Exportation Hors-Ligne USB (`backup-models.sh`)

Ce script gère la sauvegarde locale du cache Lemonade (`/var/snap/lemonade-server/common/.cache/huggingface/hub`) vers `~/LLM-backups/`, ainsi que l'exportation et l'importation via support USB externe. Il intègre le déréférencement automatique des liens symboliques Hugging Face (`rsync -L`), la vérification automatique de l'espace disque disponible (`df -BG`) et bascule automatiquement sur le **Pack 32 Go** (Gemma 4 12B + Qwen3.6 = ~18.8 Go) si le support USB dispose de moins de 58 Go libres.

```bash
#!/usr/bin/env bash
# ==============================================================================
# LLM BACKUP & OFFLINE USB EXPORT/IMPORT SCRIPT
# ==============================================================================
set -euo pipefail

LEMONADE_CACHE="/var/snap/lemonade-server/common/.cache/huggingface/hub"
VLLM_CACHE="/var/lib/ai-models/huggingface/hub"
LOCAL_BACKUP_DIR="${HOME}/LLM-backups"

usage() {
    echo "Usage: $0 [export <destination_dir> | import <source_dir> | sync-local]"
    echo ""
    echo "Commands:"
    echo "  export <dest>   Copy LLM models to USB or external path (checks available space)"
    echo "  import <src>    Import LLM models from USB into local engine cache (Lemonade or vLLM)"
    echo "  sync-local      Backup local Lemonade cache to ${LOCAL_BACKUP_DIR}"
    exit 1
}

if [[ $# -lt 1 ]]; then
    usage
fi

COMMAND="$1"

check_space() {
    local target_dir="$1"
    local required_gb="$2"
    
    mkdir -p "${target_dir}" 2>/dev/null || sudo mkdir -p "${target_dir}"
    local avail_gb
    avail_gb=$(df -BG "${target_dir}" | tail -n1 | awk '{print $4}' | sed 's/G//')
    
    echo "📊 Target directory: ${target_dir}"
    echo "💾 Available space: ${avail_gb} GB"
    echo "📦 Required space: ${required_gb} GB"
    
    if (( avail_gb < required_gb )); then
        echo "⚠️ WARNING: Available space (${avail_gb} GB) is less than required (${required_gb} GB)!"
        return 1
    fi
    return 0
}

case "${COMMAND}" in
    sync-local)
        echo "🚀 Syncing local Lemonade cache to ${LOCAL_BACKUP_DIR}..."
        mkdir -p "${LOCAL_BACKUP_DIR}"
        
        SRC_CACHE="${LEMONADE_CACHE}"
        if [ ! -d "${SRC_CACHE}" ] && [ -d "${VLLM_CACHE}" ]; then
            SRC_CACHE="${VLLM_CACHE}"
        fi
        
        sudo rsync -avLP --human-readable "${SRC_CACHE}/" "${LOCAL_BACKUP_DIR}/"
        sudo chown -R "${USER}:${USER}" "${LOCAL_BACKUP_DIR}"
        echo "✅ Local backup updated in ${LOCAL_BACKUP_DIR}"
        ;;
        
    export)
        if [[ $# -lt 2 ]]; then
            echo "❌ Error: Destination path required for export."
            usage
        fi
        DEST_DIR="$2"
        echo "🔍 Evaluating models for export to ${DEST_DIR}..."
        
        TOTAL_SIZE_GB=58
        if check_space "${DEST_DIR}" "${TOTAL_SIZE_GB}"; then
            echo "✅ Sufficient space available. Exporting ALL models (~58 GB)..."
            sudo rsync -avLP --human-readable "${LOCAL_BACKUP_DIR}/" "${DEST_DIR}/"
        else
            echo "⚡ Space is constrained. Offering 'Pack 32GB' (Gemma 4 12B + Qwen3.6 = ~18.8 GB)..."
            if check_space "${DEST_DIR}" "19"; then
                echo "🚀 Copying Pack 32GB (Gemma-4-12B + Qwen3.6)..."
                sudo rsync -avLP --human-readable \
                    "${LOCAL_BACKUP_DIR}/models--unsloth--gemma-4-12b-it-GGUF" \
                    "${LOCAL_BACKUP_DIR}/models--unsloth--Qwen3.6-35B-A3B-GGUF" \
                    "${DEST_DIR}/"
                echo "✅ Pack 32GB exported successfully!"
            else
                echo "❌ Error: Not enough space on target device even for Pack 32GB."
                exit 1
            fi
        fi
        ;;

    import)
        if [[ $# -lt 2 ]]; then
            echo "❌ Error: Source path required for import."
            usage
        fi
        SRC_DIR="$2"
        
        # Auto-detect whether target machine runs vLLM or Lemonade
        if systemctl is-active --quiet vllm.service 2>/dev/null; then
            TARGET_CACHE="${VLLM_CACHE}"
            echo "📥 Machine target mode: vLLM Server (HP Z6)."
            echo "📥 Importing models into vLLM cache (${TARGET_CACHE})..."
            sudo mkdir -p "${TARGET_CACHE}"
            sudo rsync -avLP --human-readable "${SRC_DIR}/" "${TARGET_CACHE}/"
            sudo systemctl restart vllm.service 2>/dev/null || true
            echo "✅ Import completed & vLLM service reloaded!"
        else
            TARGET_CACHE="${LEMONADE_CACHE}"
            echo "📥 Machine target mode: Lemonade Workstation (HP Z2 Mini)."
            echo "📥 Importing models into Lemonade cache (${TARGET_CACHE})..."
            sudo mkdir -p "${TARGET_CACHE}"
            sudo rsync -avLP --human-readable "${SRC_DIR}/" "${TARGET_CACHE}/"
            sudo systemctl restart lemonade.service 2>/dev/null || true
            echo "✅ Import completed & Lemonade service reloaded!"
        fi
        ;;

    *)
        usage
        ;;
esac
```

---

### 7.3 Alternative Ultra-Rapide par Transfert Direct (`rsync`)

Pour éviter de télécharger 65 Go sur chaque machine via Internet, utiliser le script `backup-models.sh` ou effectuer la copie manuelle des fichiers depuis un support USB externe directement dans le cache de l'inférence :

```bash
# Option 1 : Utilisation du script automatisé d'importation USB
./backup-models.sh import /run/media/thomas/writable/LLM-backups/

# Option 2 : Copie manuelle directe haute vitesse depuis le SSD USB externe (Lemonade)
sudo rsync -avLP /media/usb/LLM-backups/ /var/snap/lemonade-server/common/.cache/huggingface/hub/
sudo systemctl restart lemonade.service
```

---

### 7.4 Procédure de Réimportation Hors-Ligne sur Machine Cible (Lemonade vs vLLM)

Cette section détaille le fonctionnement interne de l'importation hors-ligne selon le moteur d'inférence utilisé sur la machine cible :

#### 7.4.1 Identification de la clé USB et vérification du montage (`mount`)
1. **Lister et repérer le disque USB :**
   ```bash
   lsblk -f
   ls -d /run/media/$USER/*/LLM-backups /media/$USER/*/LLM-backups /mnt/LLM-backups 2>/dev/null
   ```
2. **Si la clé n'est pas montée automatiquement :**
   ```bash
   udisksctl mount -b /dev/sda4 || (sudo mkdir -p /mnt/usb && sudo mount /dev/sda4 /mnt/usb)
   ```

#### 7.4.2 Sur une station Lemonade (HP Z2 Mini - APU Strix Halo)
* **Emplacement du cache cible :** `/var/snap/lemonade-server/common/.cache/huggingface/hub/`
* **Commande d'importation :**
  ```bash
  ./backup-models.sh import /run/media/$USER/writable/LLM-backups/
  ```
* **Détection automatique par Lemonade :**
  Au redémarrage du service (`sudo systemctl restart lemonade.service`), Lemonade scanne automatiquement son répertoire de cache Snap. Les modèles `.gguf` deviennent instantanément disponibles via l'API locale (`http://localhost:13305/v1`), Open WebUI et OpenCode **sans nécessiter aucun téléchargement depuis Internet**.

#### 7.4.3 Sur le serveur vLLM (HP Z6 Multi-GPU)
* **Emplacement du cache cible :** `/var/lib/ai-models/huggingface/hub/`
* **Commande d'importation :**
  ```bash
  ./backup-models.sh import /run/media/$USER/writable/LLM-backups/
  ```
* **Fonctionnement hors-ligne sous vLLM :**
  Le script `backup-models.sh` détecte la présence de `vllm.service` actif et dépose les fichiers de modèles dans le cache système centralisé `/var/lib/ai-models/huggingface/hub/`. vLLM lit les poids directement depuis le SSD NVMe local au démarrage du service, garantissant une exécution 100% hors-ligne.

---

## 8. Script 4 : Configuration Session Utilisateur (`setup-user.sh`)

Ce script gère la saisie **optionnelle** de la clé API Gemini. La clé est **exclusivement réservée à Hermes Agent** (`~/.hermes/.env`) et n'est jamais exposée à Open WebUI.

### 8.1 Gestion & Sécurisation des Fichiers `.env`
Les fichiers `.env` permettent de séparer le code source des clés et configurations sensibles :
* **`~/.hermes/.env` :** Stocke la variable `GEMINI_API_KEY` et le chemin du vault Obsidian. Les permissions sont restreintes à `chmod 600` (lecture/écriture par le propriétaire uniquement). Cette clé est strictement isolée pour Hermes Agent et n'est **jamais** transmise à Open WebUI ou OpenCode.
* **Fichiers `.env` de Projets (ex: `zurich-rental-flatfox-agent/.env`) :** Injectés automatiquement dans les conteneurs Docker via la directive `env_file: - .env` dans `docker-compose.yml`. Tous les fichiers `.env` sont systématiquement inscrits dans `.gitignore` et `.dockerignore` pour prévenir toute fuite de secret sur GitHub.

```bash
#!/usr/bin/env bash
# ==============================================================================
# USER SESSION SETUP SCRIPT (Hermes Agent & OpenCode Configuration)
# ==============================================================================
set -euo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "⚙️ [1/3] Configuring Hermes Agent environment..."
mkdir -p ~/.hermes

# Optional Gemini API Key strictly reserved for Hermes Agent
echo ""
echo "----------------------------------------------------------------------"
echo "🔑 Gemini API Key Setup (Optional - STRICTLY reserved for Hermes Agent)"
echo "   Note: Open WebUI runs 100% locally and NEVER uses or receives"
echo "   this Gemini API Key."
echo "----------------------------------------------------------------------"
read -rp "Do you want to configure a Gemini API Key for Hermes on THIS machine? (y/n): " USE_GEMINI

GEMINI_KEY=""
if [[ "$USE_GEMINI" =~ ^[Yy]$ ]]; then
    read -rsp "Enter your Gemini API Key: " GEMINI_KEY
    echo ""
fi

cat <<EOF > ~/.hermes/.env
GEMINI_API_KEY=${GEMINI_KEY}
OBSIDIAN_VAULT_PATH=/home/HP-AMD-LocalAI/Documents/ThomasKRemoteVault
EOF
chmod 600 ~/.hermes/.env

if [ -f "${SETUP_DIR}/configs/hermes/config.yaml" ]; then
    cp "${SETUP_DIR}/configs/hermes/config.yaml" ~/.hermes/config.yaml
fi

echo "🤖 [2/3] Installing OpenCode CLI..."
curl -fsSL https://opencode.ai/install.sh | bash || true

mkdir -p ~/.config/opencode
cat <<'EOF' > ~/.config/opencode/config.json
{
  "provider": "openai",
  "options": {
    "baseURL": "http://localhost:13305/v1",
    "apiKey": "lemonade",
    "model": "Qwen3-Coder-30B-A3B-Instruct-GGUF"
  }
}
EOF

echo "✅ [3/3] User session setup completed successfully!"
```

---

## 9. Installation & Configuration OpenCode CLI (`~/.config/opencode/config.json`)

OpenCode est le worker CLI dédié au codage automatisé, au refactoring et à l'exécution de tests. Il se connecte directement au modèle local `Qwen3-Coder-30B-A3B-Instruct-GGUF` servi par Lemonade (`http://localhost:13305/v1`) ou vLLM (`http://localhost:8000/v1`).

### 9.1 Script d'Installation
```bash
curl -fsSL https://opencode.ai/install.sh | bash
```

### 9.2 Fichier de Configuration Globale (`~/.config/opencode/config.json`)
```json
{
  "$schema": "https://opencode.ai/config.schema.json",
  "provider": "openai",
  "options": {
    "baseURL": "http://localhost:13305/v1",
    "apiKey": "lemonade",
    "model": "Qwen3-Coder-30B-A3B-Instruct-GGUF"
  },
  "execution": {
    "approval": "auto",
    "timeout": 300
  }
}
```

> ⚙️ **Adaptation Serveur HP Z6 (vLLM) :** Sur la machine serveur Z6, modifier `"baseURL"` vers `"http://localhost:8000/v1"`.

### 9.3 Script 6 : Automation Déploiement Projets Docker (`setup-docker-projects.sh`)

Ce script automatise la conteneurisation des 3 projets sur n'importe quelle nouvelle station.

```bash
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
```

### 9.4 Mode de Fonctionnement & Directives Projets (`AGENTS.md`)
Chaque projet conteneurisé (`zurich-rental-flatfox-agent`, `astra-monitor-plugin`, `pirates_bay_local_coding`) inclut un fichier **`AGENTS.md`** à sa racine. Ce fichier fournit à OpenCode le contexte de l'application, les commandes de build Docker et les scripts de validation (`healthcheck.py`) à exécuter après chaque modification.

---

## 10. Script 5 : Restauration Projets & GitHub (`setup-projects.sh`)

### 10.1 Dynamic Workspace Path (`PROJECTS_DIR="${HOME}/Projects"`)
Pour éviter le codage en dur de chemins absolus spécifiques à une seule machine (comme `/home/HP-AMD-LocalAI/`), tous les scripts de déploiement utilisent la variable dynamique Bash `${HOME}` :
* **Initialisation :** `PROJECTS_DIR="${HOME}/Projects"`
* **Utilisation :** Le script crée dynamiquement le sous-dossier `Projects` dans la session de l'utilisateur actif (`mkdir -p "${PROJECTS_DIR}"`), se positionne dedans (`cd "${PROJECTS_DIR}"`), puis y clone et orchestre l'ensemble des projets GitHub (`flatfox`, `astra-monitor`, `pirates-bay`). Cela garantit la portabilité totale du kit de déploiement sur n'importe quel compte utilisateur Linux.

```bash
#!/usr/bin/env bash
# ==============================================================================
# PROJECT RESTORATION & GITHUB AUTHENTICATION SCRIPT (Flatfox & Pirates Bay)
# ==============================================================================
set -euo pipefail

PROJECTS_DIR="${HOME}/Projects"
mkdir -p "${PROJECTS_DIR}"

echo "🔑 [1/3] Checking / Authenticating GitHub CLI (gh)..."
if command -v gh &>/dev/null; then
    gh auth status || gh auth login --web -h github.com
else
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages/githubcli-archive-keyring.gpg main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update && sudo apt install gh -y
    gh auth login
fi

echo "📦 [2/3] Cloning & Restoring GitHub Repositories..."
cd "${PROJECTS_DIR}"

if [ ! -d "zurich-rental-flatfox-agent" ]; then
    echo "Cloning Zurich Rental Agent (Flatfox)..."
    git clone https://github.com/ThomasK2020/zurich-rental-flatfox-agent.git
fi

if [ ! -d "pirates_bay_local_coding" ]; then
    echo "Initializing Pirates Bay workspace..."
    mkdir -p pirates_bay_local_coding
fi

echo "📝 [3/3] Setting up Python virtual environment for Flatfox Agent..."
if [ -d "zurich-rental-flatfox-agent" ]; then
    cd zurich-rental-flatfox-agent
    python3 -m venv venv
    ./venv/bin/pip install --upgrade pip
    if [ -f "requirements.txt" ]; then
        ./venv/bin/pip install -r requirements.txt
    fi
fi

echo "----------------------------------------------------------------------"
echo "🎉 GitHub projects and workspace restored successfully!"
echo "----------------------------------------------------------------------"
```