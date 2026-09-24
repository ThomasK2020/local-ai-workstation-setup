# Local AI Workstation Setup (HP Z2 Mini & HP Z6 Server)

Automated deployment kit and configuration files for multi-station local AI architecture.

## 🧩 Articulation et Rôle de Chaque Script

| Script | Rôle & Périmètre | Mode d'Exécution |
| :--- | :--- | :--- |
| **`setup.sh`** | **Infrastructure Système Root :** Moteur Docker officiel, Google Chrome Stable (SSO Flatfox), Node.js 22 LTS, Snap Lemonade/vLLM, comptes & pare-feu UFW. | `sudo ./setup.sh` |
| **`setup-user.sh`** | **Session Utilisateur Démo :** Profil `LocalAIDemoUser`, OpenCode CLI, `.env` neutre, fix du PATH. | `bash setup-user.sh` |
| **`setup-projects.sh`** | **Clonage Projets Git :** `gh auth setup-git`, `zurich-rental-flatfox-agent`, venv Python. | `bash setup-projects.sh` |
| **`setup-docker-projects.sh`** | **Lancement Conteneurs Docker :** Services `flatfox`, `astra-monitor`, `pirates-bay`. | `bash setup-docker-projects.sh` |
| **`backup-models.sh`** | **Import/Export Modèles LLM USB :** Sauvegarde et réimportation hors-ligne (Pack 32 Go vs 58 Go). | `./backup-models.sh` |
| **`setup-from-scratch.sh`** | **Chef d'Orchestre All-In-One :** Exécute la séquence complète (`setup.sh` → `backup-models.sh` → `setup-user.sh` → `setup-projects.sh` → `setup-docker-projects.sh`). | `sudo ./setup-from-scratch.sh` |

---

## 📚 Online Documentation (Accès Direct Sans Obsidian)

Access full, pre-formatted documentation directly online from any web browser or terminal:

1. 📖 **[Guide d'Installation From Scratch](documentation/3-From-Scratch-LocalAI-Setup.md)** : Pas-à-pas complet de A à Z pour nouvelle machine.
2. 📖 **[Kit de Déploiement Automatisé](documentation/1-Automated-Deployment-Kit.md)** : Spécifications complètes des scripts et services systemd.
3. 📖 **[Architecture Multi-Projets Docker & OpenCode](documentation/2-Docker-OpenCode-Multi-Projects-Setup.md)** : Configuration Docker Compose & `AGENTS.md` pour `flatfox`, `astra-monitor`, `pirates-bay`.

---

## Quick Start / Usage

### Option A: All-in-One From Scratch Deployer (Recommandé)

Sur une machine neuve, exécutez la séquence complète en une seule commande :

```bash
# Déploiement From Scratch avec Hermes Agent pré-installé + Profil Démo Vierge
sudo ./setup-from-scratch.sh --with-hermes --reset-demo --usb-import /run/media/$USER/writable/LLM-backups/
```

---

### Option B: Déploiement Modulaire Étape par Étape

#### 1. Infrastructure Système & Docker (Root / sudo)
```bash
sudo ./setup.sh --with-hermes
```

#### 2. Session Utilisateur & OpenCode CLI
```bash
bash setup-user.sh --reset-demo
```

#### 3. Restauration des Projets Git
```bash
bash setup-projects.sh
```

#### 4. Lancement des Conteneurs Docker Compose
```bash
bash setup-docker-projects.sh
```

#### 5. Import / Export Modèles LLM Hors-Ligne
```bash
# Importation depuis la clé USB
./backup-models.sh import /run/media/$USER/writable/LLM-backups/
```

---

## Repository Structure

```text
local-ai-workstation-setup/
├── README.md                           <- Documentation principale
├── documentation/                      <- Documentation Vault Markdown
│   ├── 1-Automated-Deployment-Kit.md
│   ├── 2-Docker-OpenCode-Multi-Projects-Setup.md
│   └── 3-From-Scratch-LocalAI-Setup.md
├── setup-from-scratch.sh               <- Orchestrateur All-in-One
├── setup.sh                            <- Installateur système Root & Docker
├── setup-user.sh                       <- Session utilisateur & profil LocalAIDemoUser
├── setup-projects.sh                   <- Authentification gh & restauration dépôts
├── setup-docker-projects.sh            <- Orchestration Docker Compose
├── backup-models.sh                    <- Export/import hors-ligne des modèles LLM USB
├── download-models.sh                  <- Pré-chargeur de modèles LLM
└── configs/
    ├── systemd/                        <- Fichiers d'unité systemd
    ├── docker/                         <- Configuration daemon.json
    └── hermes/                         <- Configs & skills partagés
```
