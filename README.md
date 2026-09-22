# Local AI Workstation Setup (HP Z2 Mini & HP Z6 Server)

Automated deployment kit and configuration files for multi-station local AI architecture.

## Features

- **Optional Hermes Agent Setup:** Install Hermes Agent via `--with-hermes` flag for automated troubleshooting.
- **Inference Engine Choice:** Supports **Lemonade** (Vulkan / APU Strix Halo on Z2 Mini) or **vLLM** (Multi-GPU / High Throughput on Z6 Server).
- **Secure Network Exposure:** Option to bind Open WebUI locally (`127.0.0.1`) or expose to LAN (`192.168.x.x`) with UFW firewall rule and generated secret key.
- **Strict Key Isolation:** Gemini API Key is optional and strictly reserved for Hermes Agent (`~/.hermes/.env`). Open WebUI runs 100% locally and never sees or uses the Gemini API key.
- **Automated Project Restoration:** Restores user projects (`zurich-rental-flatfox-agent`, `pirates_bay_local_coding`) and configures GitHub CLI (`gh`).

## Repository Structure

```text
local-ai-workstation-setup/
├── README.md                           <- Documentation
├── setup.sh                            <- Automated system installer
├── setup-user.sh                       <- User session & optional Gemini key setup
├── setup-projects.sh                   <- GitHub CLI auth & project restoration
├── download-models.sh                  <- LLM models pre-loader
└── configs/
    ├── systemd/
    │   ├── lemonade.service            <- Systemd service for Lemonade (Z2 Mini)
    │   ├── vllm.service                <- Systemd service for vLLM (Z6 Server)
    │   └── open-webui.service          <- Systemd service for Open WebUI
    ├── docker/
    │   └── daemon.json                 <- Docker log rotation config
    └── hermes/
        └── config.yaml                 <- Hermes Agent config (64k context, secret redaction)
```

## Usage

### 1. System Installation (as root / sudo)

```bash
# Standard setup
sudo ./setup.sh

# Setup with Hermes Agent pre-installed for troubleshooting
sudo ./setup.sh --with-hermes
```

### 2. User Session Setup (under HP-AMD-LocalAI user)

```bash
bash setup-user.sh
```

### 3. Restore Projects & GitHub Access

```bash
bash setup-projects.sh
```
