---
title: Explication Script Setup Workstation AI
last_updated: 2026-11-13 18:45:00 CEST
author: Hermes Agent
vault_folder: AMD TokenWatcher Radeon Linux
tags: [local-ai, hp-z2-mini, hp-z6, architecture, setup, hermes, lemonade, vllm, opencode, openwebui]
---

# 🚀 Guide & Spécifications Spécifiques du Kit de Déploiement IA Locale

Ce document détaille l'architecture complète, la cartographie des ports configurables, la matrice des options du script chef d'orchestre, le fonctionnement du proxy **Lemonade ↔ OpenCode**, et l'enchaînement orchestré des scripts d'installation pour les stations **HP Z2 Mini G1a (AMD Strix Halo 128 Go)** et **Serveur HP Z6 (Multi-GPU)**.

---

## 📌 1. Vision Générale & Principes d'Ingénierie

### 1.1 Paradigme "Hermes First"
1. **Copilote IA Actif Dès l'Étape 0 :** Hermes Agent et le profil personnel **`amd-tk`** (avec l'historique SQLite `state.db` de 281 Mo, les sessions et mémoires) sont restaurés sous la session utilisateur non-root en tout premier lieu.
2. **Flexibilité & Modularité Totale :** Il reste possible d'exécuter un déploiement sans Hermes Agent via le drapeau `--without-hermes` / `--skip-hermes` sans impacter la suite du système.
3. **Encapsulation 100% Autonome :** Toutes les archives de données (`state.db.xz.part_*`, `sessions.tar.xz`, `memories/`, `config.yaml`, `SOUL.md`) sont directement intégrées au dossier `data/` du kit central `local-ai-workstation-setup`.

---

## 🧩 2. Articulation & Rôle des 8 Scripts du Kit

| Script | Périmètre & Rôle Principal | Mode d'Exécution |
| :--- | :--- | :--- |
| **`setup-from-scratch.sh`** | **Chef d'Orchestre Tout-en-Un :** Pilote la séquence complète de A à Z (Hermes First → Système Root → Modèles LLM → Projets → Docker → Bilan). | `sudo ./setup-from-scratch.sh` |
| **`Deploy-Hermes-Perso-data.sh`** | **Restauration Profil Perso :** Décompresse `state.db`, extrait `sessions.tar.xz`, configure `.env` et le profil `amd-tk` sous `~/.hermes/profiles/amd-tk/`. | `./Deploy-Hermes-Perso-data.sh restore` |
| **`setup.sh`** | **Infrastructure Système Root :** Docker Engine, Google Chrome Stable (SSO), Node.js 22 LTS, isolation Python (`/var/lib/vllm-env/`), Snap Lemonade & vLLM. | `sudo ./setup.sh` |
| **`download-models.sh`** | **Téléchargement Modèles LLM :** Télécharge proprement les modèles LLM en ligne par défaut (ou réimporte depuis la clé USB si `--usb-import` est passé). | `./download-models.sh` |
| **`setup-user.sh`** | **Session Utilisateur & OpenCode :** Déploie OpenCode CLI, génère `~/.config/opencode/config.json` et configure le proxy Lemonade / vLLM. | `bash setup-user.sh` |
| **`setup-projects.sh`** | **Projets Applicatifs Git :** Clône `zurich-rental-flatfox-agent` et installe l'environnement virtuel Python applicatif. | `bash setup-projects.sh` |
| **`setup-docker-projects.sh`** | **Conteneurs Docker :** Déploie et démarre les services conteneurisés (`flatfox`, `astra-monitor`, `pirates-bay`, `open-webui`). | `bash setup-docker-projects.sh` |
| **`localAI-check-status.sh`** | **Diagnostic & Bilan de Santé :** Affiche le tableau de bord visuel couleur (🟢 OK / 🔴 KO) des 5 composants système. | `./localAI-check-status.sh` |

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
| **`--profile <nom>`** | Profil | `amd-tk` | Déclenche l'Étape 0 (Hermes First) et restaure le profil spécifié (`state.db`, sessions, mémoires). |
| **`--without-hermes`** / **`--skip-hermes`** | Switch | `false` (Hermes activé) | Saute intégralement l'installation et la restauration de Hermes Agent sans interrompre la suite du système. |
| **`--lemonade`** | Moteur | Optionnel | Active le moteur Lemonade Server (idéal pour APU AMD Strix Halo / Vulkan / ROCm). |
| **`--vllm`** | Moteur | Optionnel | Active le moteur vLLM Server sur GPU (idéal pour Serveur HP Z6 Multi-GPU). |
| **`--proxy-port <port>`** | Port | **`13306`** | Définit le port d'écoute du proxy Python `lemonade-opencode-proxy.py` pour OpenCode CLI. |
| **`--lemonade-vulkan-port <port>`** | Port | **`8001`** | Définit le port d'écoute du backend Lemonade Vulkan. |
| **`--lemonade-rocm-port <port>`** | Port | **`8002`** | Définit le port d'écoute du backend Lemonade ROCm. |
| **`--vllm-port <port>`** | Port | **`8000`** | Définit le port d'écoute du serveur vLLM. |
| **`--webui-port <port>`** | Port | **`8082`** | Définit le port d'écoute du conteneur/service Open WebUI. |
| **`--hermes-port <port>`** | Port | **`13305`** | Définit le port d'API interne de Hermes Agent Gateway. |
| **`--usb-import <chemin_USB>`** | Import | Aucun (Download en ligne) | Si fourni, active l'importation hors-ligne des modèles LLM depuis la clé USB. |
| **`--skip-opencode`** | Contournement | `false` | Saute l'installation et la configuration d'OpenCode CLI. |
| **`--skip-projects`** | Contournement | `false` | Saute le clonage des dépôts applicatifs Git et le lancement des conteneurs Docker. |

---

## 🔀 4. Rôle du Proxy Python `lemonade-opencode-proxy.py`

```text
                               ┌─────────────────────────────────────────┐
                               │       PORT MAPPING ARCHITECTURE         │
                               └─────────────────────────────────────────┘

[ OpenCode CLI ] ──────────► [ Proxy Python :13306 ] ──┬──────► [ Lemonade Vulkan :8001 ]
                                                       ├──────► [ Lemonade ROCm :8002 ]
                                                       └──────► [ vLLM Server :8000 ]

[ Open WebUI ] ────────────► Port :8082 ──────────────► [ Moteur LLM Direct :8001 / :8000 ]

[ Hermes Desktop ] ────────► Port :13305 ─────────────► [ Hermes Daemon Local ]
```

### 💡 Pourquoi le Proxy est Indispensable :
1. **Compatibilité Stream SSE :** Traduit et formate les fragments de réponses d'inférence en streaming (Server-Sent Events `data: [DONE]`) pour OpenCode CLI.
2. **Réécriture des Modèles :** Mappe les alias de modèles (`Qwen3-Coder-30B-A3B-Instruct-GGUF`) entre OpenCode et Lemonade.
3. **Tolérance aux Erreurs :** Maintient la connexion persistante en évitant les coupures d'inférence lors des longs appels de code.

---

## 💻 5. Commandes de Lancement selon la Machine

### 🚀 A. Déploiement Complet HP Z2 Mini (Mode Lemonade APU + Profil `amd-tk`) :
```bash
sudo ./setup-from-scratch.sh \
  --profile amd-tk \
  --lemonade \
  --lemonade-vulkan-port 8001 \
  --lemonade-rocm-port 8002 \
  --proxy-port 13306 \
  --webui-port 8082
```

### 🚀 B. Déploiement Serveur HP Z6 (Mode vLLM Multi-GPU + Profil `amd-tk`) :
```bash
sudo ./setup-from-scratch.sh \
  --profile amd-tk \
  --vllm \
  --vllm-port 8000 \
  --webui-port 8082
```

### 🚀 C. Déploiement Sans Hermes (Moteurs, OpenCode & Docker Uniquement) :
```bash
sudo ./setup-from-scratch.sh \
  --without-hermes \
  --lemonade \
  --proxy-port 13306 \
  --webui-port 8082
```

---

## 🛠️ 6. Matrice de Résolution des Problèmes Fréquents

| Symptôme / Message d'Erreur | Cause Racine | Solution Appliquée |
| :--- | :--- | :--- |
| **`403: {"detail":"profile_scope_mismatch"}`** | Un daemon Hermes résiduel tourne sous le profil `default` et bloque l'accès Desktop sous `amd-tk`. | `./Deploy-Hermes-Perso-data.sh` purge automatiquement `auth.json` et exécute `killall -9 -q hermes`. |
| **Script interrompu (`Terminated`)** | La commande `pgrep -f "hermes"` tuait le script `.sh` lui-même. | Remplacement par `killall` ciblant uniquement le binaire compilé. |
| **Profile `amd-tk` introuvable** | Le profil n'a pas été inscrit dans le registre CLI Hermes. | Ajout automatique de `hermes profile create amd-tk` et `hermes profile use amd-tk`. |
| **Pip install open-webui error (PEP 668)** | Ubuntu 24.04+ (Python 3.13+) bloque l'install globale pip. | Fallback automatique vers le conteneur Docker officiel Open WebUI sur le port `8082`. |
