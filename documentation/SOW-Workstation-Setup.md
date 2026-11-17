---
title: DOC Explication setup localAI workstation
last_updated: 2026-11-13 21:00:00 CEST
author: Hermes Agent
vault_folder: AMD Local AI Project/Workstation Setup
tags: [local-ai, hp-z2-mini, hp-z6, architecture, setup, hermes, lemonade, vllm, opencode, openwebui, docker, tokenwatcher]
---

# 📄 STATEMENT OF WORK (SOW) — ARCHITECTURE & SPÉCIFICATIONS COMPLÈTES DE DÉPLOIEMENT

**Dépôt Central :** `ThomasK2020/local-ai-workstation-setup`  
**Emplacement Note Maîtresse :** `/home/thomas/Documents/ThomasKRemoteVault/AMD Local AI Project/Workstation Setup/DOC Explication setup localAI workstation.md`  
**Machines Cibles :** HP Z2 Mini G1a (AMD Strix Halo APU 128 Go LPDDR5X) & Serveur HP Z6 (Multi-GPU)  
**Profil IA Utilisateur :** `amd-tk` (par défaut si Hermes est activé)  
**Auteur / Ingénieur :** Agent IA Hermes (Nous Research)  

---

## 📌 1. VISION GÉNÉRALE & SCHÉMA GLOBAL DE L'ARCHITECTURE

```text
                               ┌─────────────────────────────────────────┐
                               │       GLOBAL SYSTEM ARCHITECTURE        │
                               └─────────────────────────────────────────┘

                                ┌──────────────────────────────────────┐
                                │   Étape 0 : HERMES PERSO FIRST      │
                                │   Profiles: ~/.hermes/profiles/amd-tk│
                                └──────────────────┬───────────────────┘
                                                   │
                                                   ▼
 ┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
 │                                SOCLE NUCLEAIRE MOTEUR & APIS                                     │
 ├────────────────────────────────┬────────────────────────────────┬────────────────────────────────┤
 │ [ Lemonade Engine (APU) ]      │ [ vLLM Engine (Multi-GPU) ]    │ [ Open WebUI Docker Container ]│
 │ Ports: 13305 / 8001 / 8002     │ Port: 8000                     │ Port: -p 8082:8080             │
 └───────────────┬────────────────┴───────────────┬────────────────┴────────────────┬───────────────┘
                 │                                │                                 │
                 ▼                                ▼                                 ▼
┌─────────────────────────────────┐  ┌───────────────────────────┐     ┌───────────────────────────┐
│ Proxy OpenCode :13306           │  │ OpenCode CLI              │     │ Conteneurs Docker Démo    │
│ (Adaptateur OpenAI SSE Stream)  │  │ ~/.config/opencode/config │     │ - flatfox                 │
└─────────────────────────────────┘  └───────────────────────────┘     │ - pirates-bay-sandbox     │
                                                                       └───────────────────────────┘
```

### 🔑 Les 6 Piliers Fondamentaux du Déploiement :
1. **Séquence "Hermes First" (Étape 0) :** Restauration automatique du profil personnel **`amd-tk`** (avec sa base SQLite `state.db` de 281 Mo, ses sessions, ses mémoires et ses clés `.env`) dès l'Étape 0, tout en offrant la possibilité de sauter Hermes via `--without-hermes` / `--skip-hermes`.
2. **Support Dual-Engine Simultané (Lemonade ET/OU vLLM) :** Possibilité d'installer **Lemonade SEUL (`--lemonade`)**, **vLLM SEUL (`--vllm`)** ou les **DEUX SIMULTANÉMENT (`--both-engines` / `--dual-engine`)** pour des démonstrations comparatives.
3. **Opt-in Stricte des Composants (Inversion des Drapeaux) :**
   - **OpenCode CLI :** Non installé par défaut -> Activable via **`--setup-opencode`** ou **`--with-opencode`**.
   - **Projets Applicatifs & Docker :** Non installés par défaut -> Activables via **`--setup-projects`** ou **`--module <nom>`**.
4. **Variabilisation Réseau Docker (`--docker-subnet <CIDR>`) :** La plage sous-jacente (`base`) du daemon Docker est variabilisée `${DOCKER_SUBNET_POOL:-172.28.0.0/16}` dans `/etc/docker/daemon.json` pour éviter tout conflit IP avec le réseau physique LAN/VPN.
5. **Support Formats d'Aide `--help` / `-h` dans Tous les Scripts :** Tous les scripts implémentent un menu d'aide uniforme avec bannières couleur, descriptions de chaque paramètre et exemples de commandes.
6. **Bilan de Santé Adaptatif (Étape 6) :** Contrôle visuel 🟢 OK / 🔴 KO des 5 services de l'architecture via `./localAI-check-status.sh` en fin d'exécution.

---

## 🎛️ 2. CARTOGRAPHIE DES PORTS & MAPPING DYNAMIQUE

L'ensemble des composants communique via des ports réseau isolés et configurables par CLI :

| Composant / Service | Port par Défaut | Option CLI | Rôle & Inférence |
| :--- | :--- | :--- | :--- |
| **Lemonade Engine (Vulkan)** | **`8001`** | `--lemonade-vulkan-port 8001` | Inférence GPU/APU AMD via Vulkan/ANGLE |
| **Lemonade Engine (ROCm)** | **`8002`** | `--lemonade-rocm-port 8002` | Inférence native AMD ROCm |
| **Moteur vLLM (Z6 Server)** | **`8000`** | `--vllm-port 8000` | Moteur d'inférence vLLM Multi-GPU |
| **Proxy Lemonade ↔ OpenCode** | **`13306`** | `--proxy-port 13306` | Intermediate translation OpenAI API pour OpenCode CLI |
| **Open WebUI (Docker / Service)** | **`8082`** | `--webui-port 8082` | Interface Web d'équipe (mappée Docker `-p 8082:8080`) |
| **Hermes Agent Gateway** | **`13305`** | `--hermes-port 13305` | Port daemon/API interne de Hermes Agent |

---

## 🛠️ 3. ORDONNANCEMENT SÉQUENTIEL DES ÉTAPES & PLAN DES SCRIPTS

### 3.1 `setup-from-scratch.sh` (Chef d'Orchestre Tout-en-Un)
* **Aide CLI `--help` / `-h` :** Affiche le menu d'aide structuré avec tous les drapeaux et exemples.
* **Étape 0 (Hermes First) :**
  - Si `--without-hermes` / `--skip-hermes` : Saute l'Étape 0.
  - Sinon : Exécute `./Deploy-Hermes-Perso-data.sh restore --profile <profile_name>` sous `$SUDO_USER`.
* **Étape 1 (Système Root & Moteurs LLM) :** Exécute `sudo ./setup.sh` en transmettant `--lemonade`, `--vllm` ou `--both-engines` et `--docker-subnet <cidr>`.
* **Étape 2 (Modèles LLM) :** Exécute `download-models.sh` avec contrôle intelligent préalable (skip des modèles déjà présents) et support de `--model <id_ou_url_hf>`.
* **Étape 3 (Session Utilisateur & OpenCode) :** Exécute `bash setup-user.sh` uniquement si `--setup-opencode` est passé.
* **Étapes 4 & 5 (Projets Git & Docker) :** Exécute `setup-projects.sh` et `setup-docker-projects.sh` uniquement si `--setup-projects` ou `--module <nom>` est passé.
* **Étape 6 (Diagnostic Adaptatif Final) :** Exécute `./localAI-check-status.sh` pour afficher le bilan de santé 🟢/🔴.

### 3.2 `Deploy-Hermes-Perso-data.sh` (Restauration Profil `amd-tk`)
* **Résolution Auto-Terminaison (`SIGKILL`) :** Remplacement de `pgrep -f "hermes"` par `killall -9 -q hermes` (ne tue jamais le script shell).
* **Résolution HTTP 403 `profile_scope_mismatch` :** Suppression automatique des verrous `~/.hermes/auth.json`, `gateway.lock` et `processes.json`.
* **Extraction des Données Embarquées :** Fusion et décompression de `data/state.db.xz.part_*` -> `~/.hermes/profiles/amd-tk/state.db` (281 Mo) et décompression de `data/sessions.tar.xz`.

### 3.3 `setup-user.sh` (Session Utilisateur & OpenCode)
* **Protection Sudo / Non-Root :** Auto-détection de `EUID == 0` et bascule automatique sur `$SUDO_USER`.
* **Proxy OpenCode Config :** N'installe OpenCode QUE si `--setup-opencode` est passé et configure `~/.config/opencode/config.json` sur le port proxy (`13306`).

### 3.4 `download-models.sh` (Téléchargement des Modèles)
* **Vérification Intelligente Préalable :** Interroge `:13305/v1/models` (Lemonade) ou le cache `/var/lib/ai-models/huggingface/hub/` (vLLM) et saute les modèles déjà présents en 0,1s.
* **Support Modèles Custom :** Accepte le drapeau `--model <id_ou_url_hf>`.

### 3.5 `setup-projects.sh` (Gestionnaire de Modules à la Carte)
* **Support du Drapeau `--module <nom>` :**
  - `--module tokenwatcher-topbar` : Clône `tokenwatcher-topbar`, installe Astra Monitor, déploie l'extension GNOME Shell TopBar et active `tokenwatcher.service`.
  - `--module tokenwatcher-widget` : Clône `TokenWatcherWidget` et déploie le cockpit dashboard WebGL/HTML5.
  - `--module flatfox` : Clône `zurich-rental-flatfox-agent`, configure Google Chrome SSO et démarre le conteneur Docker.
  - `--module pirates-bay` : Clône `PiratesBayLocalAI` et démarre le bac à sable Docker (`pirates-bay-sandbox`).
  - `--module dj-mix` : Clône `DJ-Mix-Local-AI-Project` et configure le FastMCP Server.
  - `--all-modules` : Installe l'ensemble des modules applicatifs.

### 3.6 `localAI-check-status.sh` (Diagnostic & Bilan de Santé Adaptatif)
* **Bilan Visuel Couleur (🟢 OK / 🔴 KO) :**
  - Moteur Lemonade (Port 13305 / 8001 / 8002).
  - Moteur vLLM (Port 8000).
  - Proxy OpenCode (Port 13306).
  - Open WebUI (Port 8082 / 8080).
  - Hermes Agent Daemon (Port 13305) & Profil Actif (`amd-tk`).
  - Moteur Docker & Conteneurs Actifs.

---

## 📋 4. MATRICES COMPLÈTES DES OPTIONS CLI PAR SCRIPT

### 4.1 Matrice des Options du Script `setup-from-scratch.sh`

| Option CLI | Type | Valeur par Défaut | Description & Action |
| :--- | :--- | :--- | :--- |
| **`-h`** / **`--help`** | Aide | - | Affiche l'aide CLI détaillée avec bannières et exemples de commandes. |
| **`--profile <nom>`** | Profil | `amd-tk` | Déclenche l'Étape 0 (Hermes First) et restaure le profil spécifié (`state.db`, sessions, mémoires). |
| **`--without-hermes`** / **`--skip-hermes`** | Switch | `false` (Hermes activé) | Saute intégralement l'installation et la restauration de Hermes Agent sans interrompre la suite du système. |
| **`--lemonade`** | Moteur | Optionnel | Active le moteur Lemonade Server (APU AMD Strix Halo / Vulkan / ROCm). |
| **`--vllm`** | Moteur | Optionnel | Active le moteur vLLM Server sur GPU (Serveur HP Z6 Multi-GPU). |
| **`--both-engines`** / **`--dual-engine`** | Moteur | Optionnel | Déploie **simultanément Lemonade (13305) ET vLLM (8000)** pour démos/comparatifs. |
| **`--setup-opencode`** / **`--with-opencode`** | Opt-in | `false` (Non installé) | **[Opt-in]** Active l'installation et la configuration d'OpenCode CLI. |
| **`--setup-projects`** / **`--with-projects`** | Opt-in | `false` (Non installé) | **[Opt-in]** Active le clonage des dépôts applicatifs Git et des conteneurs Docker. |
| **`--module <nom>`** | Module | Aucun | Installe sélectivement un module (`tokenwatcher-topbar`, `tokenwatcher-widget`, `flatfox`, `pirates-bay`, `dj-mix`). |
| **`--model <id_ou_url>`** | Modèle | Modèles défaut | Spécifie un modèle LLM personnalisé ou une URL Hugging Face directe. |
| **`--usb-import <chemin_USB>`** | Import | Aucun (Download en ligne) | Active l'importation hors-ligne des modèles LLM depuis la clé USB. |
| **`--docker-subnet <cidr>`** | Réseau | **`172.28.0.0/16`** | Variabilise la plage de réseau conteneurisée sous-jacente pour Docker. |
| **`--proxy-port <port>`** | Port | **`13306`** | Définit le port d'écoute du proxy Python `lemonade-opencode-proxy.py` pour OpenCode CLI. |
| **`--webui-port <port>`** | Port | **`8082`** | Définit le port d'écoute du conteneur/service Open WebUI. |

### 4.2 Matrice des Options du Script `Deploy-Hermes-Perso-data.sh`

| Option CLI | Type | Valeur par Défaut | Description & Action |
| :--- | :--- | :--- | :--- |
| **`restore`** | Action | Action par défaut | Décompresse `state.db` (281 Mo), `sessions.tar.xz` et déploie le profil dans `~/.hermes/profiles/<profile>/`. |
| **`export`** | Action | Optionnel | Compresse et exporte `state.db` et `skills/` vers la clé USB (`/LLM-backups/Hermes-data`). |
| **`--profile <nom>`** / **`-p <nom>`** | Profil | `amd-tk` | Spécifie le nom du profil Hermes à restaurer ou exporter. |

### 4.3 Matrice des Options du Script `setup-projects.sh`

| Option CLI | Type | Valeur par Défaut | Description & Action |
| :--- | :--- | :--- | :--- |
| **`-h`** / **`--help`** | Aide | - | Affiche l'aide CLI détaillée avec la liste des modules disponibles. |
| **`--module tokenwatcher-topbar`** | Module | Optionnel | Clône `tokenwatcher-topbar`, installe Astra Monitor, déploie l'extension GNOME Shell TopBar et active `tokenwatcher.service`. |
| **`--module tokenwatcher-widget`** | Module | Optionnel | Clône `TokenWatcherWidget` et configure le cockpit dashboard WebGL/HTML5 autonome. |
| **`--module flatfox`** | Module | Optionnel | Clône `zurich-rental-flatfox-agent`, configure Google Chrome SSO et prépare le conteneur Docker. |
| **`--module pirates-bay`** | Module | Optionnel | Clône `PiratesBayLocalAI` et prépare le bac à sable Docker (`pirates-bay-sandbox`). |
| **`--module dj-mix`** | Module | Optionnel | Clône `DJ-Mix-Local-AI-Project` et configure le FastMCP Server. |
| **`--all-modules`** / **`--all`** | Restauration | `false` | Restaure l'ensemble des modules applicatifs. |

### 4.4 Matrice des Options du Script `download-models.sh`

| Option CLI | Type | Valeur par Défaut | Description & Action |
| :--- | :--- | :--- | :--- |
| **`-h`** / **`--help`** | Aide | - | Affiche l'aide CLI détaillée pour le pré-chargement des modèles. |
| **`--lemonade`** / **`lemonade`** | Moteur | `lemonade` (si vLLM inactif) | Télécharge les modèles GGUF pour Lemonade (`:13305`). Saute les modèles déjà téléchargés. |
| **`--vllm`** / **`vllm`** | Moteur | Optionnel | Télécharge les dépôts Hugging Face dans `/var/lib/ai-models/huggingface/hub`. Saute les modèles déjà en cache. |
| **`--both-engines`** / **`--dual-engine`** | Moteur | Optionnel | Télécharge et vérifie les modèles pour **Lemonade ET vLLM simultanément**. |
| **`--model <id_ou_url>`** | Modèle | Modèles défaut | Spécifie un modèle LLM personnalisé ou une URL Hugging Face directe à télécharger. |

---

## 🐳 5. STRATÉGIE & ARCHITECTURE DOCKER

### 5.1 Architecture, Setup et Configuration de Docker

Le déploiement de Docker repose sur un moteur conteneurisé moderne, isolé et entièrement personnalisable via les scripts d'infrastructure (`setup.sh` et `setup-docker-projects.sh`) :

1. **Setup & Installation du Moteur Docker (`setup.sh`) :**
   - **Installation Officielle :** Télécharge et installe le moteur officiel `docker-ce`, `docker-ce-cli`, `containerd.io` et `docker-compose-plugin` depuis `download.docker.com` (avec fallback automatique sur `docker.io` si le dépôt amont est indisponible).
   - **Gestion des Droits Utilisateurs & Accès GPU :** Crée le groupe `docker` et assigne les utilisateurs (`$SUDO_USER`, `hp-amd-localai`, `appmanager`) aux groupes `docker`, `render`, `video` et `ai-services` avec les permissions `chmod 660 /var/run/docker.sock`.
   - **Déploiement Conteneurisé Direct Open WebUI :** Open WebUI est déployé directement sous forme de conteneur Docker officiel (`ghcr.io/open-webui/open-webui:main`), éliminant tout conflit d'installation Python pip (PEP 668 sous Ubuntu 24.04+/Python 3.13+). Le port hôte est entièrement personnalisable via la variable CLI `-p ${WEBUI_PORT:-8082}:8080`.
   - **Isolation Stricte des Clés API :** La clé API Gemini reste strictement réservée à l'agent Hermes (`~/.hermes/.env`) et n'est jamais transmise ni exposée au conteneur Open WebUI.

2. **Configuration du Daemon Docker (`/etc/docker/daemon.json`) :**
   - **Rotation des Journaux :** Limite la taille des logs des conteneurs pour préserver le disque dur (`"max-size": "50m"`, `"max-file": "3"`).
   - **Variabilisation Réseau Sous-Jacente (Zéro Collision IP) :** La plage d'adresses sous-jacente des sous-réseaux conteneurisés est **dynamiquement variabilisée** via l'option `--docker-subnet <CIDR>` (par défaut `${DOCKER_SUBNET_POOL:-172.28.0.0/16}`) pour éviter tout conflit avec le réseau physique LAN de l'entreprise ou les liaisons VPN :
   ```json
   {
     "log-driver": "json-file",
     "log-opts": {
       "max-size": "50m",
       "max-file": "3"
     },
     "default-address-pools": [
       {
         "base": "${DOCKER_SUBNET_POOL:-172.28.0.0/16}",
         "size": 24
       }
     ]
   }
   ```

### 5.2 Comportement selon le Cas d'Usage (Use Case Matrix)

| Cas d'Usage Exécuté | Commande CLI | Comportement & Services Docker Déployés |
| :--- | :--- | :--- |
| **Cas 1 : OpenCode + Lemonade + Docker (Sans vLLM)** | `sudo ./setup-from-scratch.sh --lemonade --setup-opencode --setup-projects --webui-port 8082 --docker-subnet 172.30.0.0/16` | Moteur Lemonade APU (`13305`/`8001`), Proxy OpenCode (`13306`), Conteneur Open WebUI (`-p 8082:8080`), Conteneurs Docker applicatifs sur réseau `172.30.0.0/16`. **vLLM 100% ignoré**. |
| **Cas 2 : Socle Minimal Core (Sans Docker ni Projets)** | `sudo ./setup-from-scratch.sh --lemonade` | Installe Docker Engine mais **ne lance aucun conteneur**. Lemonade et Hermes seuls. |
| **Cas 3 : Déploiement DUAL-ENGINE de Démo (Lemonade + vLLM + Docker)** | `sudo ./setup-from-scratch.sh --both-engines --setup-projects --webui-port 8082` | Lemonade (`13305`) ET vLLM (`8000`) actifs. Open WebUI connecté au moteur principal. Conteneurs applicatifs lancés. |
| **Cas 4 : Module TopBar GNOME (`tokenwatcher-topbar`)** | `./setup-projects.sh --module tokenwatcher-topbar` | Ne lance aucun conteneur Docker applicatif. Installe l'extension GNOME Shell TopBar + daemon systemd `tokenwatcher.service`. |
| **Cas 5 : Module Cockpit Widget (`tokenwatcher-widget`)** | `./setup-projects.sh --module tokenwatcher-widget` | Ne lance aucun conteneur Docker applicatif. Installe le cockpit dashboard WebGL/HTML5 autonome. |

---

## 💻 6. EXEMPLES DE COMMANDES DE DÉPLOIEMENT

### 🚀 A. OpenCode + Lemonade + Docker SANS vLLM (Votre Cas Spécifique) :
```bash
sudo ./setup-from-scratch.sh \
  --profile amd-tk \
  --lemonade \
  --setup-opencode \
  --setup-projects \
  --docker-subnet 172.30.0.0/16 \
  --proxy-port 13306 \
  --webui-port 8082
```

### 🚀 B. Socle Minimal Core (Lemonade + Hermes seul) :
```bash
sudo ./setup-from-scratch.sh --profile amd-tk --lemonade
```

### 🚀 C. Déploiement DUAL-ENGINE de Démo (Lemonade + vLLM + OpenCode + Docker) :
```bash
sudo ./setup-from-scratch.sh \
  --profile amd-tk \
  --both-engines \
  --setup-opencode \
  --setup-projects
```

### 🚀 D. Installation à la Carte du Module TokenWatcher TopBar :
```bash
./setup-projects.sh --module tokenwatcher-topbar
```

---

## 🛠️ 7. MATRICE DE RÉSOLUTION DES PROBLÈMES FREQUENTS

| Symptôme / Message d'Erreur | Cause Racine | Solution Appliquée |
| :--- | :--- | :--- |
| **`403: {"detail":"profile_scope_mismatch"}`** | Un daemon Hermes résiduel tourne sous le profil `default` et bloque l'accès Desktop sous `amd-tk`. | `./Deploy-Hermes-Perso-data.sh` purge automatiquement `auth.json` et exécute `killall -9 -q hermes`. |
| **Script interrompu (`Terminated`)** | La commande `pgrep -f "hermes"` tuait le script `.sh` lui-même. | Remplacement par `killall` ciblant uniquement le binaire compilé. |
| **Profile `amd-tk` introuvable** | Le profil n'a pas été inscrit dans le registre CLI Hermes. | Ajout automatique de `hermes profile create amd-tk` et `hermes profile use amd-tk`. |
| **Pip install open-webui error (PEP 668)** | Ubuntu 24.04+ (Python 3.13+) bloque l'install globale pip. | Déploiement direct du conteneur Docker officiel Open WebUI avec mapping de port `-p 8082:8080`. |

---

## 📁 8. ARBORESCENCE DU DÉPÔT CENTRALISÉ (`local-ai-workstation-setup`)

```text
local-ai-workstation-setup/
├── README.md                           <- Documentation principale & matrice des scripts
├── setup-from-scratch.sh               <- Chef d'orchestre All-in-One (Étape 0 à Étape 6)
├── setup.sh                            <- Script système Root (Docker Engine, Node.js 22 LTS, Snap/Venv, Open WebUI)
├── setup-user.sh                       <- Setup utilisateur (Profil Hermes & OpenCode CLI Proxy)
├── setup-projects.sh                   <- Gestionnaire de modules à la carte (--module tokenwatcher-topbar, etc.)
├── setup-docker-projects.sh            <- Déploiement et orchestration des conteneurs Docker applicatifs
├── download-models.sh                  <- Pré-chargement des modèles LLM avec vérification préalable intelligente
├── backup-models.sh                    <- Export/Import hors-ligne des modèles IA via clé USB
├── Deploy-Hermes-Perso-data.sh         <- Restaurateur autonome du profil personnel amd-tk (state.db 281 Mo, sessions)
├── localAI-check-status.sh             <- Diagnostic & bilan de santé adaptatif couleur (🟢/🔴)
├── data/                               <- Données d'historique & configuration embarquées (0% fuite de secrets)
│   ├── state.db.xz.part_aa             <- Base SQLite d'historique de conversations (Partie 1/3)
│   ├── state.db.xz.part_ab             <- Base SQLite d'historique de conversations (Partie 2/3)
│   ├── state.db.xz.part_ac             <- Base SQLite d'historique de conversations (Partie 3/3)
│   ├── sessions.tar.xz                 <- Archive des sessions de chat historiques
│   ├── config.yaml                     <- Configuration Hermes Agent
│   ├── SOUL.md                         <- System Persona Hermes Agent
│   └── memories/                       <- Fichiers de mémoire durable (USER.md, MEMORY.md)
├── documentation/                      <- Coffre de documentation Markdown synchronisé
│   ├── DOC-Explication-setup-localAI-workstation.md  <- Guide d'explication maître
│   └── SOW-Workstation-Setup.md                      <- Document SOW d'architecture
└── configs/                            <- Fichiers de configurations système & services
    ├── docker/
    │   └── daemon.json                 <- Config daemon Docker (rotation logs & subnet CIDR variabilisé)
    ├── systemd/
    │   ├── vllm.service                <- Service systemd pour moteur vLLM (Port 8000)
    │   └── open-webui.service          <- Service systemd Open WebUI
    ├── opencode/
    │   ├── lemonade-opencode-proxy.py  <- Proxy Python adaptateur OpenAI SSE Stream (Port 13306)
    │   └── opencode.json               <- Configuration provider OpenCode
    └── hermes/
        └── config.yaml                 <- Template de configuration Hermes Agent
```
