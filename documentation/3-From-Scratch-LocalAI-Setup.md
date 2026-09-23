---
title: "Guide d'Installation From Scratch — Local AI Workstation Architecture"
tags:
  - deployment
  - setup
  - from-scratch
  - automation
  - github
  - lemonade
  - vllm
  - openwebui
  - opencode
  - hermes
  - docker
  - llm-models
  - security
date: 2026-09-22
last_updated: 2026-09-23 08:35:10 CEST
---

# 🚀 Guide d'Installation From Scratch — Local AI Workstation Architecture

**Dernière mise à jour :** 23 Septembre 2026 à 08:35 CEST  

> Ce document fournit le pas-à-pas intégral pour installer et configurer **à partir de zéro (from scratch)** une nouvelle station de travail individuelle (HP Z2 Mini APU Strix Halo / Vulkan) ou un serveur central (HP Z6 Multi-GPU) sur l'infrastructure local AI. Il orchestre l'installation du moteur d'inférence, du moteur Docker officiel, d'Open WebUI, d'Hermes Agent, d'OpenCode CLI et des conteneurs applicatifs multi-projets.

---

## 📋 Matrix des Rôles & Préréquis

### Hardware & OS Préréquis
- **OS :** Ubuntu Linux 24.04 / 26.04 LTS (installation fraîche).
- **Accès :** Compte utilisateur avec privilèges `sudo`.
- **Réseau :** Connexion Internet active (pour l'installation initiale des paquets).

### Distinctions d'Architecture selon le Type de Machine

| Composant / Option | Station Individuelle (HP Z2 Mini) | Serveur Central (HP Z6 Multi-GPU) |
| :--- | :--- | :--- |
| **Accélération Hardware** | APU AMD Strix Halo / Radeon 8060S (96 Go unifiés) | GPUs dédiés (ROCm / CUDA) |
| **Moteur d'Inférence** | **Lemonade** (Vulkan 1.4 RADV) | **vLLM** (PagedAttention & Continuous Batching) |
| **Port API Locale** | `13305` (API) / `13306` (Hermes provider) | `8000` (API OpenAI compatible) |
| **Emplacement Cache LLM** | `/var/snap/lemonade-server/common/.cache/huggingface/hub/` | `/var/lib/ai-models/huggingface/hub/` |

---

## 🛠️ Étape 0 : Authentification GitHub CLI (`gh`) & Clonage Initial

Depuis août 2021, GitHub n'accepte plus les mots de passe de compte pour les opérations Git en HTTPS. Sur une machine neuve, la toute première étape consiste à installer `gh` et à configurer le credential helper Git :

```bash
# 1. Installation de GitHub CLI si absent
sudo apt update && sudo apt install -y gh

# 2. Authentification interactive sur votre compte GitHub (ThomasK2020)
gh auth login
# -> Sélectionner : GitHub.com -> HTTPS -> Authentification via le navigateur

# 3. Configuration de gh comme gestionnaire d'identifiants Git HTTPS
gh auth setup-git

# 4. Clonage du dépôt centralisé de déploiement
gh repo clone ThomasK2020/local-ai-workstation-setup
cd local-ai-workstation-setup
```

---

## 🛠️ Étape 1 : Lancement de l'Installation Système Root (`setup.sh`)

Une fois le dépôt cloné et le dossier ouvert :

```bash
# Option A : Installation standard (Recommandée - Installe Docker, Node.js 22 LTS système et Lemonade/vLLM)
sudo ./setup.sh

# Option B : Installation avec Hermes Agent pré-installé (pour dépannage automatisé)
sudo ./setup.sh --with-hermes
```

### 💡 Inclusions Clés du Script `setup.sh` :
- **Node.js 22 LTS Système :** Installé globalement via le dépôt officiel NodeSource dans `/usr/bin/node` et `/usr/bin/npm`. Cela garantit que toutes les applications graphiques (GUI Desktop, Electron, extensions GNOME, services systemd) détectent immédiatement `node` et `npm` sans erreur de PATH.
- **Export Global PATH (`/etc/profile.d/10-local-bin.sh`) :** Injecte `${HOME}/.local/bin` dans l'environnement de toutes les sessions de bureau et services GUI.

### Ce que réalise le script `setup.sh` de façon automatisée :
1. **Synchronisation :** Vérifie la présence des fichiers sous `configs/` et clone les dernières versions depuis GitHub si nécessaire.
2. **Dépendances Système :** Installe `curl`, `git`, `jq`, `python3`, `python3-venv`, `ufw` et les drivers Vulkan `mesa-vulkan-drivers`.
3. **Moteur Docker Officiel :** Purge les versions obsolètes d'Ubuntu (`docker.io`, `containerd`, `runc`), ajoute la clé GPG officielle `download.docker.com` et installe **Docker Engine `29.7.2` & Compose Plugin `v5.5.0`**.
4. **Rotation des Logs Docker :** Déploie `/etc/docker/daemon.json` configuré avec la limite de logs à **50 Mo x 3 fichiers max** par conteneur.
5. **Comptes & Permissions :** Crée le groupe `ai-services`, le compte service système `appmanager` et l'utilisateur `HP-AMD-LocalAI`. Rattached ces comptes aux groupes `render`, `video`, `ai-services` et `docker` avec sécurisation des permissions du socket `/var/run/docker.sock` (`chmod 660`).
6. **Sélection du Moteur d'Inférence :** Propose le menu interactif :
   - `1` pour **Lemonade** (Z2 Mini APU Strix Halo).
   - `2` pour **vLLM** (Z6 Server Multi-GPU).
7. **Exposition Réseau Open WebUI & UFW :** Propose le menu interactif :
   - `1` pour accès local strict (`127.0.0.1:8080`).
   - `2` pour accès LAN sécurisé (`0.0.0.0:8080`) avec configuration automatique du pare-feu UFW (`ufw allow from 192.168.x.x/24 to any port 8080`).
8. **Sécurité :** Génère une clé secrète `WEBUI_SECRET_KEY` de 32 octets aléatoires et active le service systemd `open-webui.service`.

---

## 💾 Étape 2 : Importation Hors-Ligne des Modèles LLM (`backup-models.sh`)

Pour éviter de télécharger ~58 Go de modèles sur chaque nouvelle machine via Internet, les modèles sont réimportés hors-ligne depuis le support USB externe.

### 2.1 Comment identifier si l'on a la bonne clé USB ?
1. **Lister les périphériques de stockage branchés :**
   ```bash
   lsblk -f
   ```
2. **Repérer la clé USB / SSD externe :**
   Chercher le disque contenant la partition de stockage (ex: `/dev/sda4`, `/dev/sdb1` ou un SSD externe étiqueté `writable`, `LLM-STORAGE` ou formaté en exFAT/ext4).
3. **Vérifier la présence du dossier de sauvegarde `LLM-backups` :**
   ```bash
   # Vérification du répertoire de sauvegarde
   ls -d /run/media/$USER/*/LLM-backups /media/$USER/*/LLM-backups /mnt/LLM-backups 2>/dev/null
   
   # Vérifier qu'il contient bien les fichiers .gguf des modèles
   ls -lh /run/media/$USER/*/LLM-backups/
   ```
   *Signature attendue :* Le dossier doit contenir les sous-dossiers `models--unsloth--gemma-4-12b-it-GGUF`, `models--unsloth--Qwen3-Coder-30B-A3B-Instruct-GGUF`, etc.

### 2.2 Vérification et montage du point de stockage (`mount`)
Sous Ubuntu Desktop, le support USB est généralement auto-monté sous `/run/media/$USER/<LABEL>/`. Si le point de montage n'apparaît pas :
```bash
# Option A : Monter la partition via udisks2 (sans sudo)
udisksctl mount -b /dev/sda4

# Option B : Montage manuel sous /mnt (avec sudo)
sudo mkdir -p /mnt/usb
sudo mount /dev/sda4 /mnt/usb
```

### 2.3 Exécution de l'Importation Automatique
Une fois le point de montage identifié (ex: `/run/media/$USER/writable/LLM-backups/` ou `/mnt/usb/LLM-backups/`) :

```bash
# Lancement de l'importation hors-ligne
./backup-models.sh import /run/media/$USER/writable/LLM-backups/
```

### Fonctionnement Interne d'Importation :
* **Détection du Moteur :** Le script teste si `vllm.service` ou `lemonade.service` est actif.
  - Sur **HP Z2 Mini (Lemonade)** : Importe les modèles directement dans `/var/snap/lemonade-server/common/.cache/huggingface/hub/` et recharge Lemonade.
  - Sur **HP Z6 (vLLM)** : Importe les modèles dans le cache centralisé `/var/lib/ai-models/huggingface/hub/` et recharge vLLM.
* **Auto-Scannage :** Au redémarrage du service, les modèles `.gguf` sont immédiatement disponibles hors-ligne dans Open WebUI et OpenCode.

> 🌐 **Alternative 100% en ligne (sans clé USB) :** Si aucune clé USB n'est disponible, le script `download-models.sh` déclenche le téléchargement en ligne des 5 modèles via l'API Lemonade.

---

## ⚙️ Étape 3 : Configuration Session Utilisateur & OpenCode CLI (`setup-user.sh`)

Basculez sous votre session utilisateur standard et lancez la configuration de session :

```bash
# Configuration de la session utilisateur et d'OpenCode CLI
bash setup-user.sh
```

### Ce que réalise `setup-user.sh` :
1. **Isolation Stricte de la Clé Gemini :** Propose de configurer de manière optionnelle une clé `GEMINI_API_KEY`.
   - Si acceptée, la clé est inscrite dans `~/.hermes/.env` (`chmod 600`) et liée au vault Obsidian (`${HOME}/Documents/ThomasKRemoteVault`).
   - **Règle de Sécurité :** Open WebUI et Docker ne reçoivent et ne voient **jamais** cette clé Gemini.
2. **Installation OpenCode CLI :** Installe le binaire `opencode` via `https://opencode.ai/install.sh`.
3. **Configuration Globale OpenCode :** Écrit `~/.config/opencode/config.json` configuré sur le modèle local `Qwen3-Coder-30B-A3B-Instruct-GGUF`.

### 🔄 Restauration des Données Personnelles Hermes (Mémoires, Skills & Conversations)

Si vous souhaitez restaurer l'intégralité de vos mémoires (`MEMORY.md`, `USER.md`), de vos compétences personnalisées (`skills/`), de vos configurations et de votre historique de conversation sur une nouvelle machine :

#### 1. Comment obtenir le script `Deploy-Hermes-Perso-data.sh` ?
Le script est directement présent à la racine des deux dépôts GitHub :
* Dans le dépôt de déploiement : `local-ai-workstation-setup/Deploy-Hermes-Perso-data.sh`
* Dans votre dépôt privé de données : `TK-Hermes-data/Deploy-Hermes-Perso-data.sh`

#### 2. Procédure de Restauration Pas-à-Pas :
```bash
# A. Assurez-vous que la clé USB (contenant le dossier Hermes-data/) est branchée

# B. Commande Tout-en-Un pour mettre à jour TOUS les scripts locaux depuis GitHub :
(cd ~/local-ai-workstation-setup && git pull origin main) && (cd ~/TK-Hermes-data 2>/dev/null && git pull origin main || true)

# C. Lancer la restauration hybride GitHub + USB :
cd ~/local-ai-workstation-setup
./Deploy-Hermes-Perso-data.sh restore

# D. Alternativement (si TK-Hermes-data est cloné séparément) :
cd ~/TK-Hermes-data 2>/dev/null || gh repo clone ThomasK2020/TK-Hermes-data ~/TK-Hermes-data
cd ~/TK-Hermes-data && git pull origin main
bash Deploy-Hermes-Perso-data.sh restore
```

#### Ce que réalise la restauration :
* **Depuis GitHub (`ThomasK2020/TK-Hermes-data`) :** Restaure vos configurations (`config.yaml`), votre clé Gemini isolée (`.env`), vos notes de mémoire (`MEMORY.md`, `USER.md`), vos automatisations (`cron/`, `plugins/`) et vos bases `projects.db` / `kanban.db`.
* **Depuis la Clé USB (`/Hermes-data/`) :** Restaure et décompresse votre base de conversation `state.db` et l'ensemble de vos compétences `skills/` (~643 Mo).

---

## 📦 Étape 4 : Restauration des Projets GitHub & Authentification (`setup-projects.sh`)

```bash
# Authentification GitHub et restauration des dépôts de code
bash setup-projects.sh
```

### Ce que réalise `setup-projects.sh` :
1. **Authentification GitHub CLI :** Vérifie `gh auth status` ou déclenche `gh auth login` interactif.
2. **Espace de Travail Dynamique :** Crée le répertoire `${HOME}/Projects/`.
3. **Clonage des Dépôts :** Clone automatiquement `zurich-rental-flatfox-agent` et initialise `pirates_bay_local_coding`.
4. **Environnement Virtuel Python :** Crée le `venv` local pour le projet Flatfox et installe les paquets `requirements.txt`.

---

## 🐳 Étape 5 : Déploiement des Conteneurs Docker Multi-Projets (`setup-docker-projects.sh`)

```bash
# Orchestration et lancement des conteneurs Docker Compose
bash setup-docker-projects.sh
```

### Ce que réalise `setup-docker-projects.sh` :
1. **Agent Flatfox (`flatfox-rental-agent`) :** Construit l'image Playwright Python 1.40 + Chromium, monte le volume de session persistant `./data:/app/data` (`flatfox_auth_state.json`) et lance l'agent avec healthcheck HTTP.
2. **Astra Monitor Daemon (`astra-monitor-daemon`) :** Construit l'image Python avec passthrough GPU `/dev/dri`, configure l'accès aux métriques VRAM/GPU AMD RADV et monte le fichier IPC `/tmp/astra_state.json`.
3. **Pirates Bay Sandbox (`pirates-bay-sandbox`) :** Construit le conteneur de dev isolé avec bridage cgroups (4 Go RAM / 2 CPUs) et profil `no-new-privileges:true`.

---

## 🔍 Étape 6 : Bilan de Validation, Healthchecks & Tests

Exécutez ces commandes pour valider l'installation globale :

```bash
# 1. Vérifier que tous les conteneurs Docker tournent avec le statut HEALTHY 🟢
docker ps

# Expected output:
# CONTAINER ID   IMAGE                               COMMAND            STATUS                    NAMES
# 1a10a9035075   zurich_rental_agent-flatfox-agent   "python main.py"   Up 2 minutes (healthy)   flatfox-rental-agent
# ...

# 2. Vérifier l'état du service d'inférence et d'Open WebUI
systemctl status lemonade.service open-webui.service

# 3. Accéder à l'interface Open WebUI
# URL : http://localhost:8080 (ou http://192.168.x.x:8080 depuis le réseau local)

# 4. Tester l'exécution d'OpenCode CLI dans un projet
cd ~/Projects/zurich-rental-flatfox-agent
opencode "Vérifie la validité des fichiers du projet"
```

---

## 🛠️ Résolution des Problèmes Courants (Troubleshooting)

### A. Erreur `Permission denied` sur `/var/run/docker.sock`
Si un utilisateur ne peut pas lancer `docker ps` sans `sudo` :
```bash
sudo usermod -aG docker $USER
sudo chown root:docker /var/run/docker.sock
sudo chmod 660 /var/run/docker.sock
# Puis se déconnecter et se reconnecter à la session utilisateur
```

### B. Session Flatfox expirée ou Erreur 403 Cloudflare
Si le conteneur `flatfox-rental-agent` passe au statut `unhealthy` :
```bash
cd ~/Projects/zurich-rental-flatfox-agent
# Exécuter le login interactif sur l'hôte avec le Chrome système
python3 login_flatfox_interactive.py
# Puis redémarrer le conteneur Docker
docker compose up -d --build
```

### C. Diagnostic & Solution : Lemonade (Vérification & Redémarrage)

#### 1. Nom exact du service Snap Lemonade
Sous Ubuntu/Snap, le service système ne s'appelle pas `lemonade.service`, mais **`snap.lemonade-server.daemon.service`**.
```bash
# Vérification du statut du service Snap Lemonade
systemctl status snap.lemonade-server.daemon.service

# Redémarrage du service Snap Lemonade si inactif
sudo snap restart lemonade-server
```

#### 2. Test d'inférence en direct (HTTP 200 & Vitesse Tokens/sec)
Tester si le serveur Lemonade répond correctement sur le port `13305` (API OpenAI) ou `13306` (Proxy OpenCode) :
```bash
# Tester la liste des modèles reconnus par Lemonade
curl -s http://localhost:13305/v1/models | jq .

# Tester l'inférence en direct avec Gemma 4 12B
curl -s http://localhost:13305/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Gemma-4-12B-it-GGUF",
    "messages": [{"role": "user", "content": "Reply with ONE word: ONLINE"}],
    "max_tokens": 10
  }' | jq .
```
*Signature attendue :* Statut `200 OK`, réponse générée et métrique `predicted_per_second` > 20 tokens/sec sous Vulkan RADV sur APU Strix Halo.
