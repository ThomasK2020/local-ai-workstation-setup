# Local AI Workstation Setup (HP Z2 Mini & HP Z6 Server)

Automated deployment kit and configuration files for multi-station local AI architecture.

## Features

- **Official Docker Engine & Compose Setup:** Installs Docker Engine (`download.docker.com`), configures log rotation (`/etc/docker/daemon.json`), and sets user permissions/GPU passthrough.
- **Optional Hermes Agent Setup:** Install Hermes Agent via `--with-hermes` flag for automated troubleshooting.
- **Inference Engine Choice:** Supports **Lemonade** (Vulkan / APU Strix Halo on Z2 Mini) or **vLLM** (Multi-GPU / High Throughput on Z6 Server).
- **Secure Network Exposure:** Option to bind Open WebUI locally (`127.0.0.1`) or expose to LAN (`192.168.x.x`) with UFW firewall rule and generated secret key.
- **Strict Key Isolation:** Gemini API Key is optional and strictly reserved for Hermes Agent (`~/.hermes/.env`). Open WebUI runs 100% locally and never sees or uses the Gemini API key.
- **Automated Project Restoration & Dockerization:** Restores user projects (`zurich-rental-flatfox-agent`, `astra-monitor-plugin`, `pirates_bay_local_coding`), configures OpenCode CLI (`AGENTS.md`), and launches Docker Compose services.
- **Offline USB Model Export/Import:** `backup-models.sh` enables offline model migration with auto-detection for space limits and engine target (Lemonade vs vLLM).

## Repository Structure

```text
local-ai-workstation-setup/
├── README.md                           <- Documentation
├── setup.sh                            <- Automated system & Docker installer
├── setup-user.sh                       <- User session, OpenCode & optional Gemini key setup
├── setup-projects.sh                   <- GitHub CLI auth & project restoration
├── setup-docker-projects.sh            <- Multi-project Docker Compose orchestration
├── backup-models.sh                    <- Local LLM backup, space detection & USB export/import
├── download-models.sh                  <- LLM models pre-loader
└── configs/
    ├── systemd/
    │   ├── lemonade.service            <- Systemd service for Lemonade (Z2 Mini)
    │   ├── vllm.service                <- Systemd service for vLLM (Z6 Server)
    │   └── open-webui.service          <- Systemd service for Open WebUI
    ├── docker/
    │   └── daemon.json                 <- Docker log rotation config (50m x 3 files)
    └── hermes/
        └── config.yaml                 <- Hermes Agent config (64k context, secret redaction)
```

## Quick Start / Usage

### 1. System & Docker Installation (as root / sudo)

```bash
# Standard setup
sudo ./setup.sh

# Setup with Hermes Agent pre-installed for troubleshooting
sudo ./setup.sh --with-hermes
```

### 2. User Session & OpenCode Setup (under user session)

```bash
bash setup-user.sh
```

### 3. Restore GitHub Repositories

```bash
bash setup-projects.sh
```

### 4. Deploy Dockerized Projects (`flatfox`, `astra-monitor`, `pirates-bay`)

```bash
bash setup-docker-projects.sh
```

### 5. Offline USB Model Backup & Import

```bash
# Local backup to ~/LLM-backups/
./backup-models.sh sync-local

# Export to USB (auto-selects Pack 32GB if space < 58GB)
./backup-models.sh export /run/media/$USER/writable/LLM-backups/

# Import on target machine (auto-detects Lemonade vs vLLM)
./backup-models.sh import /run/media/$USER/writable/LLM-backups/
```
