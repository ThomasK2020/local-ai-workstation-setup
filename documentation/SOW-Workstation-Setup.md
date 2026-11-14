---
title: SOW Workstation Setup — Spécifications Completes (Revision 4.1)
last_updated: 2026-11-13 19:30:00 CEST
author: Hermes Agent
vault_folder: AMD Local AI Project/Workstation Setup
tags: [local-ai, hp-z2-mini, hp-z6, architecture, setup, sow, hermes, lemonade, vllm, opencode, openwebui, tokenwatcher, dual-engine]
---

# 📄 STATEMENT OF WORK (SOW) — SPÉCIFICATIONS COMPLÈTES DU DÉPLOIEMENT WORKSTATION IA (REVISION 4.1)

**Dépôt Central :** `ThomasK2020/local-ai-workstation-setup`  
**Emplacement Note Maîtresse :** `/home/thomas/Documents/ThomasKRemoteVault/AMD Local AI Project/Workstation Setup/SOW Workstation Setup.md`  
**Machines Cibles :** HP Z2 Mini G1a (AMD Strix Halo APU 128 Go LPDDR5X) & Serveur HP Z6 (Multi-GPU)  
**Profil IA Utilisateur :** `amd-tk` (par défaut si Hermes est activé)  
**Auteur / Ingénieur :** Agent IA Hermes (Nous Research)  

---

## 📌 1. CONTEXTE & NOUVELLES RÈGLES D'ARCHITECTURE

L'objectif de cette révision 4.1 est de garantir une modularité absolue : **rien de superflus n'est installé par défaut**, tout composant additionnel (OpenCode, Projets applicatifs, Modèles LLM spécifiques) est un **choix explicite**, et les moteurs d'inférence peuvent être co-installés en mode **Dual-Engine (Lemonade + vLLM)** pour des besoins de démonstration.

### 🔑 Les 6 Piliers Fondamentaux de la Révision 4.1 :
1. **Inversion des Drapeaux par Défaut (Opt-in Stricte) :**
   - **OpenCode CLI :** Non installé par défaut -> Nécessite le drapeau explicite **`--setup-opencode`** ou **`--with-opencode`**.
   - **Projets Applicatifs & Docker :** Non installés par défaut -> Nécessitent le drapeau explicite **`--setup-projects`** ou **`--with-projects`** (ou l'option sélective `--module <nom>`).
2. **Support Dual-Engine Simultané (Lemonade ET/OU vLLM) :**
   - L'auto-détection matérielle suggère une recommandation (APU AMD -> Lemonade, NVIDIA Multi-GPU -> vLLM), mais l'utilisateur peut choisir d'installer **Lemonade SEUL (`--lemonade`)**, **vLLM SEUL (`--vllm`)** ou les **DEUX SIMULTANÉMENT (`--both-engines` / `--dual-engine`)** pour des démonstrations comparatives.
3. **Séquence "Hermes First" Conditionnelle :**
   - Invocable par défaut ou via `--profile <nom>`.
   - Saatable proprement via **`--without-hermes`** / **`--skip-hermes`** sans perturber le reste de l'installation.
4. **Gestion Flexible des Modèles LLM & URLs Hugging Face :**
   - Choix interactif ou CLI des modèles à télécharger (`--model <nom_ou_url_hf>`).
   - Prise en charge des URLs directes d'upload Hugging Face ou de l'importation hors-ligne par clé USB (`--usb-import <chemin>`).
5. **Support Formaté du Drapeau d'Aide `--help` / `-h` :**
   - Tous les scripts du kit implémentent une aide `--help` / `-h` uniforme, avec bannières couleur, descriptions de chaque paramètre et exemples de commandes.
6. **Diagnostic Bilan Adaptatif en Fin de Script :**
   - `./localAI-check-status.sh` s'adapte dynamiquement aux composants réellement sélectionnés lors de l'installation (Lemonade, vLLM, Dual-Engine, OpenCode, Hermes, Docker).

---

## 🎛️ 2. CARTOGRAPHIE DES PORTS & MAPPING DYNAMIQUE (DUAL-ENGINE)

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
* **Aide CLI `--help` / `-h` :** Affiche une aide complète décrivant tous les drapeaux et modes d'exécution.
* **Étape 0 (Hermes First) :**
  - Si `--without-hermes` / `--skip-hermes` : Saute l'Étape 0 cleanly.
  - Sinon : Exécute `./Deploy-Hermes-Perso-data.sh restore --profile <profile_name>` sous `$SUDO_USER`.
* **Étape 1 (Moteurs LLM & Système Root) :**
  - Accepte `--lemonade`, `--vllm` ou `--both-engines` (déploie Lemonade sur 13305/8001 et vLLM sur 8000).
* **Étape 2 (Téléchargement des Modèles) :**
  - Exécute `download-models.sh` avec sélection explicite (`--model <name_or_url>` ou import USB `--usb-import`).
* **Étape 3 (OpenCode CLI - Opt-in) :**
  - N'exécute `setup-user.sh --setup-opencode` QUE si `--setup-opencode` ou `--with-opencode` est présent.
* **Étapes 4 & 5 (Projets & Docker - Opt-in) :**
  - N'exécute `setup-projects.sh` et `setup-docker-projects.sh` QUE si `--setup-projects` ou `--module <nom>` est présent.
* **Étape 6 (Diagnostic Adaptatif) :** Exécute `./localAI-check-status.sh` qui filtre et contrôle uniquement les composants sélectionnés.

### 3.2 Script `download-models.sh` (Sélection des Modèles & URLs Custom)
* **Sélection Dynamique des Modèles :**
  - Accepte l'argument `--model <id_ou_url_hf>` (ex: `--model Qwen/Qwen2.5-Coder-32B-Instruct` ou URL Hugging Face).
  - Supporte l'importation hors-ligne via `--usb-import <chemin_USB>`.

### 3.3 Script `setup-projects.sh` (Gestionnaire de Modules à la Carte)
* **Installation par Module Sélectif :**
  - `--module tokenwatcher` : Clône `tokenwatcher-topbar`, installe et active l'extension TopBar GNOME.
  - `--module flatfox` : Clône `zurich-rental-flatfox-agent`, configure Google Chrome SSO et démarre le conteneur Docker.
  - `--module pirates-bay` : Clône `PiratesBayLocalAI` et démarre le bac à sable Docker.
  - `--module dj-mix` : Clône `DJ-Mix-Local-AI-Project` et configure le FastMCP Server.
  - `--all-modules` : Installe l'ensemble des modules applicatifs.

### 3.4 Script `localAI-check-status.sh` (Diagnostic Bilan Adaptatif)
* **Vérification Dynamique :**
  - Détecte quels moteurs sont installés (Lemonade, vLLM ou les deux simultanément) et affiche leur état 🟢/🔴.
  - Vérifie OpenCode uniquement si `--setup-opencode` a été exécuté.
  - Vérifie Hermes Agent et son profil actif.
  - Vérifie les conteneurs Docker projet uniquement s'ils ont été déployés.

---

## 📋 4. MATRICE COMPLÈTE DES OPTIONS CLI (`setup-from-scratch.sh`)

| Option CLI | Type | Valeur par Défaut | Description & Action |
| :--- | :--- | :--- | :--- |
| **`-h`** / **`--help`** | Aide | - | Affiche l'aide CLI détaillée avec descriptions et exemples de commandes. |
| **`--profile <nom>`** | Profil | `amd-tk` | Définit le profil Hermes à créer et restaurer (si Hermes est activé). |
| **`--without-hermes`** / **`--skip-hermes`** | Switch | `false` (Hermes activé) | Saute intégralement l'installation et la restauration de Hermes Agent. |
| **`--lemonade`** | Moteur | Optionnel | Active le moteur Lemonade Server (Port `13305` / `8001`). |
| **`--vllm`** | Moteur | Optionnel | Active le moteur vLLM Server (Port `8000`). |
| **`--both-engines`** / **`--dual-engine`** | Moteur | Optionnel | Déploie **simultanément Lemonade (13305) ET vLLM (8000)** pour démos/comparatifs. |
| **`--setup-opencode`** / **`--with-opencode`** | Opt-in | `false` (Non installé) | **[Nouveau]** Active l'installation et la configuration d'OpenCode CLI. |
| **`--setup-projects`** / **`--with-projects`** | Opt-in | `false` (Non installé) | **[Nouveau]** Active le clonage des dépôts applicatifs et des conteneurs Docker. |
| **`--module <nom>`** | Module | Aucun | Installe sélectivement un module (`tokenwatcher`, `flatfox`, `pirates-bay`, `dj-mix`). |
| **`--model <id_ou_url>`** | Modèle | Modèles défaut | Spécifie un modèle LLM personnalisé ou une URL Hugging Face directe. |
| **`--usb-import <path>`** | Import | Aucun (Download en ligne) | Active l'importation hors-ligne des modèles LLM depuis la clé USB. |
| **`--proxy-port <port>`** | Port | **`13306`** | Définit le port d'écoute du proxy Python pour OpenCode. |
| **`--webui-port <port>`** | Port | **`8082`** | Définit le port d'écoute du service/conteneur Open WebUI. |

---

## 🚀 5. EXEMPLES DE COMMANDES DE DÉPLOIEMENT

### A. Installation du Socle Minimal Core (Lemonade + Hermes `amd-tk` seul) :
```bash
sudo ./setup-from-scratch.sh --profile amd-tk --lemonade
```

### B. Déploiement DUAL-ENGINE de Démo (Lemonade + vLLM + OpenCode + Hermes) :
```bash
sudo ./setup-from-scratch.sh \
  --profile amd-tk \
  --both-engines \
  --setup-opencode \
  --proxy-port 13306 \
  --webui-port 8082
```

### C. Installation du Socle avec Modèle Hugging Face Sur Mesure :
```bash
sudo ./setup-from-scratch.sh \
  --profile amd-tk \
  --lemonade \
  --model Qwen/Qwen2.5-Coder-32B-Instruct
```

### D. Installation à la Carte du Widget TokenWatcher :
```bash
./setup-projects.sh --module tokenwatcher
```

---

## 📊 6. MATRICE DES CRITÈRES D'ACCEPTATION

| Test / Critère | Méthode de Validation | Statut Attendu |
| :--- | :--- | :--- |
| **Aide CLI `--help`** | `sudo ./setup-from-scratch.sh --help` | Affichage propre de l'aide et sortie 0. 🟢 |
| **Comportement Opt-in OpenCode** | `sudo ./setup-from-scratch.sh --lemonade` | OpenCode n'est pas installé à moins que `--setup-opencode` soit fourni. 🟢 |
| **Mode Dual-Engine** | `sudo ./setup-from-scratch.sh --both-engines` | Lemonade (13305/8001) ET vLLM (8000) répondent simultanément. 🟢 |
| **Diagnostic Adaptatif** | `./localAI-check-status.sh` | Seuls les composants installés sont évalués avec leur statut 🟢/🔴. |
