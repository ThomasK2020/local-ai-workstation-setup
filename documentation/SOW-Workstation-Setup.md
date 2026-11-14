---
title: (current 13-11) SOW Workstation Setup
last_updated: 2026-11-13 20:15:00 CEST
author: Hermes Agent
vault_folder: AMD Local AI Project/Workstation Setup
tags: [local-ai, hp-z2-mini, hp-z6, architecture, setup, hermes, lemonade, vllm, opencode, openwebui, docker]
---

# 🚀 Guide & Spécifications Spécifiques du Kit de Déploiement IA Locale

Ce document détaille l'architecture complète, la cartographie des ports configurables, la matrice des options du script chef d'orchestre, la stratégie Docker conteneurisée, le fonctionnement du proxy **Lemonade ↔ OpenCode**, et l'enchaînement orchestré des scripts d'installation pour les stations **HP Z2 Mini G1a (AMD Strix Halo 128 Go)** et **Serveur HP Z6 (Multi-GPU)**.

---

## 📌 1. Vision Générale & Principes d'Ingénierie

### 1.1 Paradigme "Hermes First"
1. **Copilote IA Actif Dès l'Étape 0 :** Hermes Agent et le profil personnel **`amd-tk`** (avec l'historique SQLite `state.db` de 281 Mo, les sessions et mémoires) sont restaurés sous la session utilisateur non-root en tout premier lieu.
2. **Flexibilité & Modularité Totale :** Il reste possible d'exécuter un déploiement sans Hermes Agent via le drapeau `--without-hermes` / `--skip-hermes` sans impacter la suite du système.
3. **Opt-in Stricte des Composants (Inversion des Drapeaux) :**
   - OpenCode CLI : Non installé par défaut -> Option **`--setup-opencode`**.
   - Projets & Docker : Non installés par défaut -> Option **`--setup-projects`** (ou `--module <nom>`).
4. **Encapsulation 100% Autonome :** Toutes les archives de données (`state.db.xz.part_*`, `sessions.tar.xz`, `memories/`, `config.yaml`, `SOUL.md`) sont directement intégrées au dossier `data/` du kit central `local-ai-workstation-setup`.

---

## 🧩 2. Articulation & Rôle des 8 Scripts du Kit

| Script | Périmètre & Rôle Principal | Mode d'Exécution |
| :--- | :--- | :--- |
| **`setup-from-scratch.sh`** | **Chef d'Orchestre Tout-en-Un :** Pilote la séquence complète de A à Z (Hermes First → Système Root → Modèles LLM → Projets → Docker → Bilan). | `sudo ./setup-from-scratch.sh` |
| **`Deploy-Hermes-Perso-data.sh`** | **Restauration Profil Perso :** Décompresse `state.db`, extrait `sessions.tar.xz`, configure `.env` et le profil `amd-tk` sous `~/.hermes/profiles/amd-tk/`. | `./Deploy-Hermes-Perso-data.sh restore` |
| **`setup.sh`** | **Infrastructure Système Root :** Docker Engine, Google Chrome Stable (SSO), Node.js 22 LTS, isolation Python (`/var/lib/vllm-env/`), Snap Lemonade & vLLM. | `sudo ./setup.sh` |
| **`download-models.sh`** | **Téléchargement Modèles LLM :** Télécharge proprement les modèles LLM en ligne par défaut (ou réimporte depuis la clé USB si `--usb-import` est passé). | `./download-models.sh` |
| **`setup-user.sh`** | **Session Utilisateur & OpenCode :** Déploie OpenCode CLI (si `--setup-opencode`), génère `~/.config/opencode/config.json` et configure le proxy Lemonade / vLLM. | `bash setup-user.sh` |
| **`setup-projects.sh`** | **Projets Applicatifs Git :** Clône les dépôts applicatifs (si `--setup-projects` ou `--module <nom>`). | `bash setup-projects.sh` |
| **`setup-docker-projects.sh`** | **Conteneurs Docker :** Déploie et démarre les services conteneurisés (`flatfox`, `astra-monitor`, `pirates-bay`, `open-webui`). | `bash setup-docker-projects.sh` |
| **`localAI-check-status.sh`** | **Diagnostic & Bilan de Santé Adaptatif :** Affiche le tableau de bord visuel couleur (🟢 OK / 🔴 KO) des composants effectivement sélectionnés. | `./localAI-check-status.sh` |

---

## 🎛️ 3. Cartographie des Ports & Matrice Complète des Options CLI

### 3.1 Cartographie des Ports
Tous les ports de l'architecture sont paramétrables à la demande via les options CLI de `setup-from-scratch.sh` et `setup.sh` :

| Composant / Service | Port par Défaut | Exemple Sur Mesure | Drapeau CLI / Option | Rôle & Connexion |
| :--- | :--- | :--- | :--- | :--- |
| **Lemonade Engine (Vulkan)** | **`8001`** | `8001` | `--lemonade-vulkan-port 8001` | Moteur d'inférence APU/GPU AMD via Vulkan/ANGLE |
| **Lemonade Engine (ROCm)** | **`8002`** | `8002` | `--lemonade-rocm-port 8002` | Moteur d'inférence native AMD ROCm |
| **Moteur vLLM (Z6 Server)** | **`8000`** | `8000` | `--vllm-port 8000` | Moteur d'inférence vLLM Multi-GPU |
| **Proxy Lemonade ↔ OpenCode** | **`13306`** | **`13306`** | `--proxy-port 13306` | Intermediate translation OpenAI API pour OpenCode CLI |
| **Open WebUI (Docker / Service)** | **`8082`** | **`8082`** | `--webui-port 8082` | Interface Web d'équipe (mappée Docker `-p 8082:8080`) |
| **Hermes Agent Gateway** | **`13305`** | `13305` | `--hermes-port 13305` | Port daemon/API interne de Hermes Agent |

### 3.2 Matrice Complète des Options du Script `setup-from-scratch.sh`

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
| **`--module <nom>`** | Module | Aucun | Installe sélectivement un module (`tokenwatcher`, `flatfox`, `pirates-bay`, `dj-mix`). |
| **`--model <id_ou_url>`** | Modèle | Modèles défaut | Spécifie un modèle LLM personnalisé ou une URL Hugging Face directe. |
| **`--usb-import <chemin_USB>`** | Import | Aucun (Download en ligne) | Active l'importation hors-ligne des modèles LLM depuis la clé USB. |
| **`--docker-subnet <cidr>`** | Réseau | **`172.28.0.0/16`** | **[Nouveau]** Variabilise la plage de réseau conteneurisée sous-jacente pour Docker. |
| **`--proxy-port <port>`** | Port | **`13306`** | Définit le port d'écoute du proxy Python `lemonade-opencode-proxy.py` pour OpenCode CLI. |
| **`--webui-port <port>`** | Port | **`8082`** | Définit le port d'écoute du conteneur/service Open WebUI. |

---

## 🐳 4. STRATÉGIE & ARCHITECTURE DOCKER (ANALYSE & AMÉLIORATIONS)

### 4.1 Analyse du Setup Docker Actuel (Fonctionnement Existant)
1. **Installation du Moteur Docker Engine (`setup.sh`) :**
   - Télécharge et installe `docker-ce`, `docker-ce-cli`, `containerd.io` et `docker-compose-plugin` depuis `download.docker.com`.
   - Fallback automatique sur les paquets Ubuntu `docker.io` si le dépôt officiel échoue.
   - Configure la rotation des journaux Docker `/etc/docker/daemon.json` (`max-size: 50m`, `max-file: 3`).
   - Assigne les utilisateurs (`$SUDO_USER`, `hp-amd-localai`, `appmanager`) aux groupes `docker`, `render`, `video`, `ai-services`.
2. **Gestion d'Open WebUI (Historique) :**
   - Tentait une installation native `pip install open-webui` qui échouait sous Ubuntu 24.04+ (Python 3.13+), puis basculait sur le conteneur Docker officiel en mode `--network host` fixé sur le port `8080`.
3. **Conteneurs Applicatifs Démo (`setup-docker-projects.sh`) :**
   - Utilise Docker Compose pour lancer `flatfox`, `astra-monitor` et `pirates-bay-sandbox` (bridé à 4 Go RAM / 2 CPUs).

### 4.2 Propositions d'Améliorations Intégrées (Refonte Révision 4.1)
* **Amélioration 1 : Déploiement Direct Conteneurisé d'Open WebUI avec Port Mapping Dynamique**
  - Suppression de la tentative `pip` inutile : Open WebUI est déployé directement sous forme de conteneur Docker officiel avec port hôte personnalisable (`-p ${WEBUI_PORT:-8082}:8080`).
  - Strict respect de la confidentialité des clés : La clé API Gemini reste strictement réservée à Hermes Agent (`~/.hermes/.env`) et n'est JAMAIS injectée dans Open WebUI.
  ```bash
  docker run -d \
    --name open-webui \
    -p ${WEBUI_PORT:-8082}:8080 \
    -e WEBUI_SECRET_KEY="${WEBUI_SECRET}" \
    -e OPENAI_API_BASE_URL="${OPENWEBUI_OPENAI_URL}" \
    -v open-webui-data:/app/backend/data \
    --restart always \
    ghcr.io/open-webui/open-webui:main
  ```
* **Amélioration 2 : Variabilisation Dynamique du Daemon Docker (`/etc/docker/daemon.json`)**
  - **Zéro Hardcode Réseau :** La plage d'adresses sous-jacente (`base`) est **entièrement variabilisée** via l'option CLI `--docker-subnet <cidr>` (par défaut `${DOCKER_SUBNET_POOL:-172.28.0.0/16}`) pour éviter tout conflit avec le sous-réseau LAN du site ou de l'entreprise.
  - **Génération Dynamique du JSON :**
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
* **Amélioration 3 : Opt-In Stricte et Isolation des Modules Applicatifs**
  - Aucun conteneur projet n'est démarré par défaut -> Déclenché uniquement si `--setup-projects` ou `--module <nom>` est passé.

### 4.3 Comportement selon le Cas d'Usage (Use Case Matrix)

| Cas d'Usage Exécuté | Commande CLI | Comportement & Services Docker Déployés |
| :--- | :--- | :--- |
| **Cas 1 : OpenCode + Lemonade + Docker (Sans vLLM)** | `sudo ./setup-from-scratch.sh --lemonade --setup-opencode --setup-projects --webui-port 8082 --docker-subnet 172.30.0.0/16` | Moteur Lemonade APU (`13305`/`8001`), Proxy OpenCode (`13306`), Conteneur Open WebUI (`-p 8082:8080`), Conteneurs Docker applicatifs sur réseau `172.30.0.0/16`. **vLLM 100% ignoré**. |
| **Cas 2 : Socle Minimal Core (Sans Docker ni Projets)** | `sudo ./setup-from-scratch.sh --lemonade` | Installe Docker Engine mais **ne lance aucun conteneur**. Lemonade et Hermes seuls. |
| **Cas 3 : Déploiement DUAL-ENGINE de Démo (Lemonade + vLLM + Docker)** | `sudo ./setup-from-scratch.sh --both-engines --setup-projects --webui-port 8082` | Lemonade (`13305`) ET vLLM (`8000`) actifs. Open WebUI connecté au moteur principal. Conteneurs applicatifs lancés. |
| **Cas 4 : Module Spécifique à la Carte (ex: Widget TokenWatcher)** | `./setup-projects.sh --module tokenwatcher` | Ne lance aucun conteneur Docker applicatif lourd. Installe uniquement l'extension GNOME Topbar. |

---

## 🔀 5. Rôle du Proxy Python `lemonade-opencode-proxy.py`

```text
                               ┌─────────────────────────────────────────┐
                               │     DUAL-ENGINE PORT ARCHITECTURE       │
                               └─────────────────────────────────────────┘

[ OpenCode CLI ] ──────────► [ Proxy Python :13306 ] ──┬──────► [ Lemonade Vulkan :8001 ]
                                                       ├──────► [ Lemonade ROCm :8002 ]
                                                       └──────► [ vLLM Server :8000 ]

[ Open WebUI ] ────────────► Port :8082 ──────────────► [ Direct LLM Engine :8001 / :8000 ]

[ Hermes Desktop ] ────────► Port :13305 ─────────────► [ Hermes Daemon Local ]
```

---

## 💻 6. Exemples de Commandes selon le Besoin

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

### 🚀 D. Installation à la Carte du Widget TokenWatcher :
```bash
./setup-projects.sh --module tokenwatcher
```

---

## 🛠️ 7. Matrice de Résolution des Problèmes Fréquents

| Symptôme / Message d'Erreur | Cause Racine | Solution Appliquée |
| :--- | :--- | :--- |
| **`403: {"detail":"profile_scope_mismatch"}`** | Un daemon Hermes résiduel tourne sous le profil `default` et bloque l'accès Desktop sous `amd-tk`. | `./Deploy-Hermes-Perso-data.sh` purge automatiquement `auth.json` et exécute `killall -9 -q hermes`. |
| **Script interrompu (`Terminated`)** | La commande `pgrep -f "hermes"` tuait le script `.sh` lui-même. | Remplacement par `killall` ciblant uniquement le binaire compilé. |
| **Profile `amd-tk` introuvable** | Le profil n'a pas été inscrit dans le registre CLI Hermes. | Ajout automatique de `hermes profile create amd-tk` et `hermes profile use amd-tk`. |
| **Pip install open-webui error (PEP 668)** | Ubuntu 24.04+ (Python 3.13+) bloque l'install globale pip. | Déploiement direct du conteneur Docker officiel Open WebUI avec mapping de port `-p 8082:8080`. |
