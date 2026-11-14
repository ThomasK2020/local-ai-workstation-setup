---
title: SOW Workstation Setup — Spécifications Completes
last_updated: 2026-11-13 19:15:00 CEST
author: Hermes Agent
vault_folder: AMD Local AI Project/Workstation Setup
tags: [local-ai, hp-z2-mini, hp-z6, architecture, setup, sow, hermes, lemonade, vllm, opencode, openwebui, tokenwatcher]
---

# 📄 STATEMENT OF WORK (SOW) — SPÉCIFICATIONS COMPLÈTES DU DÉPLOIEMENT WORKSTATION IA

**Dépôt Central :** `ThomasK2020/local-ai-workstation-setup`  
**Emplacement Note Maîtresse :** `/home/thomas/Documents/ThomasKRemoteVault/AMD Local AI Project/Workstation Setup/SOW Workstation Setup.md`  
**Machines Cibles :** HP Z2 Mini G1a (AMD Strix Halo APU 128 Go LPDDR5X) & Serveur HP Z6 (Multi-GPU)  
**Profil IA Utilisateur :** `amd-tk` (par défaut si Hermes est activé)  
**Auteur / Ingénieur :** Agent IA Hermes (Nous Research)  

---

## 📌 1. CONTEXTE & CADRAGE DE L'ARCHITECTURE

L'objectif de cette refonte est d'assurer un déploiement From Scratch 100% robust, modulaire et sans erreur sur toute station de travail Linux (Ubuntu 24.04/26.04 LTS).

### 🔑 Les 4 Piliers Fondamentaux de la Refonte :
1. **Séquence "Hermes First" (Étape 0) :** Restauration automatique du profil personnel **`amd-tk`** (avec sa base SQLite `state.db` de 281 Mo, ses sessions, ses mémoires et ses clés `.env`) dès l'Étape 0, tout en offrant la possibilité explicite de sauter Hermes via `--without-hermes` / `--skip-hermes`.
2. **Choix Explicite du Moteur d'Inférence :** Liberté totale de choisir `--lemonade` (port `13305` / `8001` / `8002` pour APU AMD Strix Halo) ou `--vllm` (port `8000` pour serveur Z6 Multi-GPU) sans aucune auto-détection imposée.
3. **Modularité à la Carte (`--skip-projects` et `--module <nom>`) :** Installation par défaut du **socle moteur et assistant uniquement** (sans imposer de projets lourds). Déploiement sélectif des projets via `./setup-projects.sh --module <tokenwatcher|flatfox|pirates-bay|dj-mix>`.
4. **Bilan de Santé Automatique (Étape 6) :** Contrôle visuel 🟢 OK / 🔴 KO des 5 services de l'architecture via `./localAI-check-status.sh` en fin d'exécution.

---

## 🎛️ 2. CARTOGRAPHIE DES PORTS & MAPPING DYNAMIQUE

L'ensemble des composants communique via des ports réseau isolés et configurables par CLI :

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

| Composant / Service | Port par Défaut | Option CLI | Rôle & Inférence |
| :--- | :--- | :--- | :--- |
| **Lemonade Engine (Vulkan)** | **`8001`** | `--lemonade-vulkan-port 8001` | Inférence GPU/APU AMD via Vulkan/ANGLE |
| **Lemonade Engine (ROCm)** | **`8002`** | `--lemonade-rocm-port 8002` | Inférence native AMD ROCm |
| **Moteur vLLM (Z6 Server)** | **`8000`** | `--vllm-port 8000` | Moteur d'inférence vLLM Multi-GPU |
| **Proxy Lemonade ↔ OpenCode** | **`13306`** | `--proxy-port 13306` | Intermediate translation OpenAI API pour OpenCode CLI |
| **Open WebUI (Docker / Service)** | **`8082`** | `--webui-port 8082` | Interface Web d'équipe (mappée Docker `-p 8082:8080`) |
| **Hermes Agent Gateway** | **`13305`** | `--hermes-port 13305` | Port daemon/API interne de Hermes Agent |

---

## 🛠️ 3. PLAN COMPLET DES MODIFICATIONS PAR SCRIPT

### 3.1 Script `setup-from-scratch.sh` (Chef d'Orchestre Tout-en-Un)
* **Étape 0 (Hermes First) :**
  - Si `--without-hermes` ou `--skip-hermes` est présent : Saute l'Étape 0 et affiche `ℹ️ Hermes Agent ignoré par l'utilisateur`.
  - Sinon : Exécute `./Deploy-Hermes-Perso-data.sh restore --profile <profile_name>` sous `$SUDO_USER`.
* **Étape 1 (Système Root) :** Exécute `sudo ./setup.sh` en transmettant `--lemonade` ou `--vllm` et les drapeaux de ports.
* **Étape 2 (Modèles LLM) :** Télécharge les modèles en ligne par défaut (ou via `--usb-import <path>` si fourni).
* **Étape 3 (Session Utilisateur & OpenCode) :** Exécute `bash setup-user.sh` configuré sur le port d'inférence choisi.
* **Étapes 4 & 5 (Projets & Docker) :** Sautés si `--skip-projects` est actif (par défaut) ou exécutés pour les modules choisis.
* **Étape 6 (Diagnostic Final) :** Exécute `./localAI-check-status.sh` pour afficher le bilan de santé 🟢 OK / 🔴 KO.

### 3.2 Script `Deploy-Hermes-Perso-data.sh` (Restauration Profil `amd-tk`)
* **Résolution Auto-Terminaison (`SIGKILL`) :** Remplacement de `pgrep -f "hermes"` par `killall -9 -q hermes` et `killall -9 -q Hermes` (qui ne tue jamais le script shell lui-même).
* **Résolution HTTP 403 `profile_scope_mismatch` :** Suppression automatique des fichiers temporaires d'authentification `~/.hermes/auth.json`, `~/.hermes/gateway.lock` et `~/.hermes/processes.json` avant la restauration.
* **Extraction des Données Embarquées :** Fusion et décompression de `data/state.db.xz.part_*` -> `~/.hermes/profiles/amd-tk/state.db` (281 Mo) et décompression de `data/sessions.tar.xz`.
* **Registre Hermes :** Exécution systématique de `hermes profile create amd-tk` et `hermes profile use amd-tk`.

### 3.3 Script `setup-user.sh` (Session Utilisateur & OpenCode)
* **Protection Sudo / Non-Root :** Auto-détection de `EUID == 0` et bascule automatique sur l'utilisateur réel `$SUDO_USER`.
* **Proxy OpenCode Config :** Inscription automatique du port du proxy (`13306`) dans `~/.config/opencode/config.json`.

### 3.4 Script `download-models.sh` (Téléchargement des Modèles)
* **Fix Surcharge Moteur :** Correction de la condition pour qu'un choix explicite `--lemonade` ne soit pas écrasé par la présence d'un fichier vLLM sur le système.
* **Téléchargement En Ligne par Défaut :** Téléchargement propre en ligne via Hugging Face CLI / Snap Lemonade, l'option `--usb-import` restant disponible sur demande.

### 3.5 Script `setup-projects.sh` (Gestionnaire de Modules à la Carte)
* **Support du Drapeau `--module <nom>` :** Permet d'installer sélectivement un module applicatif :
  - `--module tokenwatcher` : Clône `tokenwatcher-topbar`, installe et active l'extension TopBar GNOME.
  - `--module flatfox` : Clône `zurich-rental-flatfox-agent`, configure Google Chrome SSO et démarre le conteneur Docker.
  - `--module pirates-bay` : Clône `PiratesBayLocalAI` et démarre le bac à sable Docker.
  - `--module dj-mix` : Clône `DJ-Mix-Local-AI-Project` et configure le FastMCP Server.
  - `--all` : Installe l'ensemble des modules applicatifs.

### 3.6 Script `localAI-check-status.sh` (Diagnostic & Bilan de Santé)
* **Bilan Visuel Couleur (🟢 OK / 🔴 KO) :**
  - Moteur Lemonade (Port 13305 / 8001 / 8002) ou vLLM (Port 8000).
  - Open WebUI (Port 8082).
  - OpenCode CLI + Proxy (Port 13306).
  - Hermes Agent Daemon (Port 13305) & Profil Actif (`amd-tk`).
  - Daemon Docker & Conteneurs Actifs.

---

## 📋 4. MATRICE COMPLÈTE DES OPTIONS CLI

| Option CLI | Type | Valeur par Défaut | Description & Action |
| :--- | :--- | :--- | :--- |
| **`--profile <nom>`** | Profil | `amd-tk` | Définit le profil Hermes à créer et restaurer (si Hermes est activé). |
| **`--without-hermes`** / **`--skip-hermes`** | Switch | `false` (Hermes activé) | Saute intégralement l'installation et la restauration de Hermes Agent. |
| **`--lemonade`** | Moteur | Optionnel | Active le moteur Lemonade Server (APU AMD Strix Halo / Vulkan / ROCm). |
| **`--vllm`** | Moteur | Optionnel | Active le moteur vLLM Server sur GPU (Serveur HP Z6 Multi-GPU). |
| **`--proxy-port <port>`** | Port | **`13306`** | Définit le port d'écoute du proxy Python `lemonade-opencode-proxy.py` pour OpenCode. |
| **`--lemonade-vulkan-port <port>`** | Port | **`8001`** | Définit le port d'écoute du backend Lemonade Vulkan. |
| **`--lemonade-rocm-port <port>`** | Port | **`8002`** | Définit le port d'écoute du backend Lemonade ROCm. |
| **`--vllm-port <port>`** | Port | **`8000`** | Définit le port d'écoute du serveur vLLM. |
| **`--webui-port <port>`** | Port | **`8082`** | Définit le port d'écoute du service/conteneur Open WebUI. |
| **`--hermes-port <port>`** | Port | **`13305`** | Définit le port d'API interne de Hermes Agent Gateway. |
| **`--usb-import <chemin_USB>`** | Import | Aucun (Download en ligne) | Si fourni, active l'importation hors-ligne des modèles LLM depuis la clé USB. |
| **`--skip-opencode`** | Contournement | `false` | Saute l'installation et la configuration d'OpenCode CLI. |
| **`--skip-projects`** | Contournement | `true` (Socle seul) | Saute le clonage des projets applicatifs (installation du socle seul). |

---

## 🚀 5. EXEMPLES DE COMMANDES DE DÉPLOIEMENT

### A. Installation du Socle Core HP Z2 Mini (Lemonade + Hermes `amd-tk` + Ports Sur Mesure) :
```bash
sudo ./setup-from-scratch.sh \
  --profile amd-tk \
  --lemonade \
  --proxy-port 13306 \
  --lemonade-vulkan-port 8001 \
  --lemonade-rocm-port 8002 \
  --webui-port 8082
```

### B. Installation du Socle Core HP Z6 Multi-GPU (vLLM + Hermes `amd-tk`) :
```bash
sudo ./setup-from-scratch.sh \
  --profile amd-tk \
  --vllm \
  --vllm-port 8000 \
  --webui-port 8082
```

### C. Installation du Socle Léger "Sans Hermes" :
```bash
sudo ./setup-from-scratch.sh \
  --without-hermes \
  --lemonade \
  --proxy-port 13306 \
  --webui-port 8082
```

### D. Installation à la Carte d'un Module Applicatif (ex: Widget TokenWatcher) :
```bash
./setup-projects.sh --module tokenwatcher
```

---

## 📊 6. MATRICE DES CRITÈRES D'ACCEPTATION

| Test / Critère | Méthode de Validation | Statut Attendu |
| :--- | :--- | :--- |
| **Restauration Hermes First** | `./Deploy-Hermes-Perso-data.sh restore --profile amd-tk` | `state.db` (281 Mo) extrait sans interruption. 🟢 |
| **Absence d'erreur 403** | `hermes desktop --profile amd-tk` | Démarrage propre de l'interface GUI Electron. 🟢 |
| **Proxy OpenCode** | `curl -s http://localhost:13306/v1/models` | Réponse JSON valide du proxy Python. 🟢 |
| **Open WebUI Docker** | `curl -I http://localhost:8082` | HTTP 200 OK du conteneur Open WebUI. 🟢 |
| **Diagnostic Global** | `./localAI-check-status.sh` | Affichage complet avec 5 indicateurs 🟢 OK. |
