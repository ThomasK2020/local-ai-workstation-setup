---
title: "Architecture Multi-Projets Docker & OpenCode — Spécifications & Guide de Configuration"
tags:
  - docker
  - opencode
  - hermes
  - architecture
  - flatfox
  - astra-monitor
  - pirates-bay
  - gpu-amd
  - security
date: 2026-09-22
last_updated: 2026-09-22 22:34:43 CEST
---

# 🏗️ Architecture Multi-Projets : Docker, OpenCode & Moteur IA Local

**Dernière mise à jour :** 22 Septembre 2026 à 22:34 CEST  

> Ce document spécifie la conteneurisation Docker, la configuration OpenCode CLI (`AGENTS.md`) et la stratégie de déploiement pour les 3 projets de développement de l'infrastructure : **Zurich Rental Flatfox Agent**, **Astra Monitor GNOME Extension/Daemon** et **Pirates Bay Coding Sandbox**.

---

## 📌 1. Vue d'Ensemble de l'Architecture & Flux de Travail

### 1.1 Répertoire de Travail Dynamique (`PROJECTS_DIR="${HOME}/Projects"`)
Afin d'assurer une compatibilité totale entre machines sans dépendre d'un nom d'utilisateur codé en dur (comme `/home/HP-AMD-LocalAI/` ou `/home/thomas/`), l'ensemble de l'infrastructure s'appuie sur la variable d'environnement Bash `${HOME}` :
- **Initialisation :** `PROJECTS_DIR="${HOME}/Projects"`
- **Rôle :** Définit le point d'ancrage universel pour le clonage des dépôts Git, la création des environnements virtuels Python et l'orchestration des conteneurs Docker.

### 1.2 Isolation & Injection des Secrets via Fichiers `.env`
Les conteneurs Docker et les agents IA gèrent leurs identifiants de façon strictement isolée via des fichiers `.env` :
- **`~/.hermes/.env` :** Contient la variable `GEMINI_API_KEY` (`chmod 600`), réservée à Hermes et totalement inaccessible à Open WebUI/Docker.
- **`<projet>/.env` (ex: `zurich-rental-flatfox-agent/.env`) :** Injecté dans le conteneur via la directive Docker Compose `env_file: - .env`. Les secrets sont exclus de Git via `.gitignore` et `.dockerignore`.

```text
                               +-------------------------------------------------------+
                               |            Dépôts GitHub (ThomasK2020)                |
                               |  - zurich-rental-flatfox-agent                        |
                               |  - astra-monitor-plugin                               |
                               |  - pirates_bay_local_coding                           |
                               +---------------------------+---------------------------+
                                                           |
                                                           v [git clone / gh CLI]
+-------------------------------------------------------------------------------------------------------------------+
| Station Cible (Linux / HP Z2 Mini APU Strix Halo ou HP Z6 Server Multi-GPU)                                       |
|                                                                                                                   |
|  +-------------------------------------------------------------------------------------------------------------+  |
|  | Moteur d'Inférence IA Local (Lemonade :13305 / :13306 ou vLLM :8000)                                         |  |
|  | Modèle Modélisation Code : Qwen3-Coder-30B-A3B-Instruct-GGUF                                                   |  |
|  +-----------------------------------------------------+-------------------------------------------------------+  |
|                                                        |                                                          |
|                                                        v [OpenAI API Protocol]                                    |
|  +-------------------------------------------------------------------------------------------------------------+  |
|  | OpenCode CLI (Worker Code)  <--->  Hermes Agent (Lead Orchestrateur / Troubleshooting)                       |  |
|  | Config : ~/.config/opencode/config.json & AGENTS.md dans chaque dépôt                                          |  |
|  +-----------------------------------------------------+-------------------------------------------------------+  |
|                                                        |                                                          |
|  +-----------------------------------------------------v-------------------------------------------------------+  |
|  | Orchestration Conteneurisée (Docker Compose v5.5.0 / Docker Engine 29.7.2)                                   |  |
|  |                                                                                                             |  |
|  |  [📦 flatfox-rental-agent]             [📦 astra-monitor-daemon]           [📦 pirates-bay-sandbox]         |  |
|  |  - Playwright Python 1.40                - Python 3.11 Slim                   - Python 3.11 + Node.js 20 LTS   |  |
|  |  - Chromium Headless                    - Passthrough GPU /dev/dri           - cgroups : 4GB RAM / 2 CPUs     |  |
|  |  - Persistance Cookies                  - IPC State File /tmp/astra_state    - Volume restreint ./workspace   |  |
|  |  - Healthcheck HTTP flatfox.ch          - Healthcheck GPU metrics < 5s       - Security: no-new-privileges    |  |
|  +-------------------------------------------------------------------------------------------------------------+  |
+-------------------------------------------------------------------------------------------------------------------+
```

---

## 📂 2. Projet 1 : Agent Rental Flatfox (`zurich-rental-flatfox-agent`)

### 2.1 Anticipation des Problèmes & Pièges Techniques

1. **Piège Exécution Headless / EOFError sur `input()` :**
   - *Analyse :* Dans un conteneur Docker en arrière-plan sans TTY, l'appel à des fonctions Python interactives (`input()`) lève immédiatement une exception `EOFError`.
   - *Solution Appliquée :* Test dynamique de `sys.stdin.isatty()`. Si faux, l'agent bascule automatiquement sur la boucle de polling automatisée sans bloquer.
2. **Piège Expiration des Cookies & Anti-Bot Cloudflare :**
   - *Analyse :* Les requêtes de scraping Playwright nécessitent une session authentifiée valide (`flatfox_auth_state.json`).
   - *Solution Appliquée :* Utilisation de l'image officielle Playwright Jammy avec Chromium pré-installé, couplée au montage de volume persistant `./data:/app/data`. Si la session expire, un script hôte `login_flatfox_interactive.py` utilise Google Chrome natif avec l'option `--disable-blink-features=AutomationControlled` pour renouveler les cookies sans blocage.

### 2.2 Fichier `Dockerfile`
```dockerfile
FROM mcr.microsoft.com/playwright/python:v1.40.0-jammy

WORKDIR /app

# Empeche Python de mettre en cache les sorties stdout/stderr
ENV PYTHONUNBUFFERED=1

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Verification de l'installation des navigateurs Playwright
RUN playwright install chromium

COPY . /app/

# Repertoire de donnees persistantes pour la session
RUN mkdir -p /app/data

VOLUME ["/app/data"]

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD python /app/healthcheck.py

CMD ["python", "main.py"]
```

### 2.3 Fichier `docker-compose.yml`
```yaml
version: '3.8'

services:
  flatfox-agent:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: flatfox-rental-agent
    restart: unless-stopped
    env_file:
      - .env
    environment:
      - AUTH_STATE_FILE=/app/data/flatfox_auth_state.json
      - PYTHONUNBUFFERED=1
    volumes:
      - ./data:/app/data
      - ./flatfox_auth_state.json:/app/data/flatfox_auth_state.json:rw
    healthcheck:
      test: ["CMD", "python", "/app/healthcheck.py"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
```

### 2.4 Diagnostic Santé (`healthcheck.py`)
```python
#!/usr/bin/env python3
import sys
import os
import json
import requests

def check_flatfox_network():
    try:
        res = requests.get("https://flatfox.ch", timeout=5)
        return res.status_code in (200, 301, 302)
    except Exception:
        return False

def check_auth_state():
    path = os.getenv("AUTH_STATE_FILE", "/app/data/flatfox_auth_state.json")
    if not os.path.exists(path):
        return True
    try:
        with open(path, "r") as f:
            data = json.load(f)
            cookies = data.get("cookies", [])
            s = requests.Session()
            s.headers.update({"User-Agent": "Mozilla/5.0 (X11; Linux x86_64)", "Accept": "application/json"})
            for c in cookies:
                if "flatfox" in c.get("domain", ""):
                    s.cookies.set(c["name"], c["value"], domain=c["domain"])
            res = s.get("https://flatfox.ch/api/v1/user/", timeout=5)
            return res.status_code == 200
    except Exception:
        return False

def main():
    if check_flatfox_network() and check_auth_state():
        sys.exit(0)
    sys.exit(1)

if __name__ == "__main__":
    main()
```

### 2.5 Instructions OpenCode (`AGENTS.md`)
```markdown
# OpenCode Agent Guidelines — Flatfox Rental Agent

## Contexte & Précisions Techniques
- **Langage / Framework :** Python 3.11, Playwright (Chromium headless), Requests, SQLite/JSON.
- **Conteneurisation :** Run sous Docker via `flatfox-rental-agent`.

## Consignes Modifiabilité & Qualité :
1. **Sessions & Authentification :** Ne JAMAIS supprimer ni altérer le schéma de `flatfox_auth_state.json`.
2. **Compatibilité Daemon Non-Interactif :** S'assurer que tout script vérifie `sys.stdin.isatty()` avant tout appel interactif.
3. **Validation Obligatoire :**
   ```bash
   python3 healthcheck.py
   docker compose up -d --build
   ```
```

---

## 📂 3. Projet 2 : Daemon & Extension Astra Monitor (`astra-monitor-plugin`)

### 3.1 Anticipation des Problèmes & Pièges Techniques

1. **Piège Accès GPU AMD dans un Conteneur Docker :**
   - *Analyse :* Le daemon a besoin d'exécuter `amdgpu_top` et d'accéder aux nœuds DRM `/dev/dri/renderD128` pour lire les métriques VRAM/GPU AMD Radeon (APU Strix Halo 8060S). Sans passthrough explicit, Docker bloque l'accès aux cartes graphiques.
   - *Solution Appliquée :* Ajout de `devices: [/dev/dri:/dev/dri]` et appartenance aux groupes système `render` (gid 109/110) et `video` dans `docker-compose.yml`.
2. **Piège Communication IPC avec l'Extension GNOME Shell (GJS) :**
   - *Analyse :* GNOME Shell s'exécute sur l'hôte sous GJS (JavaScript) et ne peut pas appeler `docker exec` en boucle sans dégrader les performances du bureau.
   - *Solution Appliquée :* Le daemon conteneurisé écrit atomiquement un fichier JSON dans `/tmp/astra_state.json` (partagé via le volume monté `/tmp:/tmp`). L'extension GNOME Shell lit ce fichier localement en asynchrone toutes les 2 secondes.

### 3.2 Fichier `Dockerfile`
```dockerfile
FROM python:3.11-slim

WORKDIR /app

ENV PYTHONUNBUFFERED=1

# Installation des utilitaires GPU AMD et pciutils
RUN apt-get update && apt-get install -y --no-install-recommends \
    pciutils \
    libdrm2 \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt || true

COPY . /app/

HEALTHCHECK --interval=10s --timeout=5s --start-period=5s --retries=3 \
  CMD python3 /app/healthcheck.py

CMD ["python3", "daemon/astra_daemon.py"]
```

### 3.3 Fichier `docker-compose.yml`
```yaml
version: '3.8'

services:
  astra-monitor-daemon:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: astra-monitor-daemon
    restart: unless-stopped
    devices:
      - /dev/dri:/dev/dri
    group_add:
      - render
      - video
    volumes:
      - /tmp:/tmp
      - /sys/class/drm:/sys/class/drm:ro
    environment:
      - OUTPUT_STATE_FILE=/tmp/astra_state.json
      - PYTHONUNBUFFERED=1
    healthcheck:
      test: ["CMD", "python3", "/app/healthcheck.py"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 5s
```

### 3.4 Diagnostic Santé (`healthcheck.py`)
```python
#!/usr/bin/env python3
import sys
import os
import time
import json

def check_gpu_state():
    path = os.getenv("OUTPUT_STATE_FILE", "/tmp/astra_state.json")
    if not os.path.exists(path):
        return False
    try:
        # Verifier que le fichier a ete mis a jour il y a moins de 10s
        mtime = os.path.getmtime(path)
        if time.time() - mtime > 10:
            return False
        with open(path, "r") as f:
            data = json.load(f)
            return "gpu_usage" in data or "vram_usage" in data
    except Exception:
        return False

if __name__ == "__main__":
    if check_gpu_state():
        sys.exit(0)
    sys.exit(1)
```

### 3.5 Instructions OpenCode (`AGENTS.md`)
```markdown
# OpenCode Agent Guidelines — Astra Monitor GNOME Extension

## Contexte & Précisions Techniques
- **Daemon :** Python 3.11, lecture métriques `/dev/dri`, écriture IPC `/tmp/astra_state.json`.
- **Extension GNOME :** GJS (JavaScript GNOME 50+), syntaxe ES6 + `GObject.registerClass`.

## Consignes Modifiabilité :
1. **Accès GPU :** Toujours conserver les droits `/dev/dri` et le groupe `render`.
2. **Compatibilité GJS :** Les modifications de l'extension GNOME doivent respecter la spec GTK4/Adwaita sans imports Node.js.
3. **Validation :**
   ```bash
   python3 -m py_compile daemon/astra_daemon.py
   docker compose up -d --build
   ```
```

---

## 📂 4. Projet 3 : Pirates Bay Local Coding Sandbox (`pirates_bay_local_coding`)

### 4.1 Anticipation des Problèmes & Pièges Techniques

1. **Piège Épuisement des Ressources Système par du Code Généré par l'IA :**
   - *Analyse :* Les scripts de test ou de prototypage générés par OpenCode peuvent contenir des boucles infinies ou allouer de grandes quantités de mémoire, risquant d'impacter le système hôte.
   - *Solution Appliquée :* Bridage strict via cgroups (`mem_limit: 4g`, `cpus: 2.0`) et option `security_opt: [no-new-privileges:true]`.
2. **Piège Élévation de Privilèges & Isolation Système :**
   - *Analyse :* Le conteneur exécute du code dynamique et ne doit en aucun cas pouvoir interagir avec le démon Docker de l'hôte ou accéder à d'autres répertoires que `./workspace`.
   - *Solution Appliquée :* Isolation stricte du volume de travail `./workspace:/app/workspace` sans aucun montage de socket Docker.

### 4.2 Fichier `Dockerfile`
```dockerfile
FROM python:3.11-slim

WORKDIR /app

ENV PYTHONUNBUFFERED=1

# Installation de Node.js 20 LTS, Git, Curl et outils de build
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    build-essential \
    ca-certificates \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt || true

RUN mkdir -p /app/workspace

VOLUME ["/app/workspace"]

CMD ["tail", "-f", "/dev/null"]
```

### 4.3 Fichier `docker-compose.yml`
```yaml
version: '3.8'

services:
  pirates-bay-sandbox:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: pirates-bay-sandbox
    restart: unless-stopped
    mem_limit: 4g
    cpus: 2.0
    security_opt:
      - no-new-privileges:true
    volumes:
      - ./workspace:/app/workspace
    environment:
      - PYTHONUNBUFFERED=1
```

### 4.4 Instructions OpenCode (`AGENTS.md`)
```markdown
# OpenCode Agent Guidelines — Pirates Bay Coding Sandbox

## Contexte & Précisions Techniques
- Environnement de test et de dev sécurisé (Python 3.11, Node.js 20, Git).
- Exécution isolée dans le volume `/app/workspace`.

## Consignes :
1. Écrire le code de prototypage uniquement dans `./workspace`.
2. Ajouter des tests automatisés avec `pytest` pour valider les nouvelles fonctions.
```

---

## ⚙️ 5. Configuration Globale OpenCode CLI (`~/.config/opencode/config.json`)

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

> **Bascule Serveur Z6 (vLLM) :** Sur le serveur Z6, modifier `"baseURL"` vers `"http://localhost:8000/v1"`.

---

## 🛠️ 6. Script d'Automation & Déploiement (`setup-docker-projects.sh`)

Le script complet d'automatisation et de déploiement multi-projets Docker est maintenu dans le kit de déploiement centralisé sous la section **`9.3 Script 6 : Automation Déploiement Projets Docker`** de la note `(current) Automated Deployment Kit (Option A) - Local AI Setup.md`.

Exécution directe depuis le dépôt central :
```bash
./setup-docker-projects.sh
```

---

## 🏁 Guide d'Aide-Mémoire Commandes

| Action | Commande | Description |
| :--- | :--- | :--- |
| **Démarrer tous les projets** | `docker compose up -d` | Démarre les services en arrière-plan avec healthcheck |
| **Vérifier les healthchecks** | `docker ps` | Affiche l'état des conteneurs (`healthy`) |
| **Suivre les logs** | `docker logs -f <nom_conteneur>` | Diagnostic en temps réel |
| **Relancer OpenCode** | `opencode "votre demande"` | Déclenche l'agent de coding sur le projet courant |
