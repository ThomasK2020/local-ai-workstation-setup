# Architecture Hybride : Hermes Agent (Gemini) + OpenCode CLI (Qwen Coder Local) + Lemonade

Spécifications d'installation et de déploiement pour le schéma hybride d'assistance IA :
**Gemini** (Discussion & Brain) + **OpenCode CLI / Qwen Coder** (Génération de code local via Lemonade) + **Sandbox Docker**.

---

## 🎯 Schéma d'Architecture

```text
               ┌──────────────────────────────────────────────┐
               │    Hermes Agent (Profil: LocalAIDemo)        │
               │   Discussion & Réflexion ➔ Gemini API       │
               └──────────────────────┬───────────────────────┘
                                      │
                                (Délégation Code)
                                      ▼
               ┌──────────────────────────────────────────────┐
               │              OpenCode CLI                    │
               │    Inférence ➔ Qwen Coder (Lemonade Local)   │
               └──────────────────────┬───────────────────────┘
                                      │
                                      ▼
               ┌──────────────────────────────────────────────┐
               │     Conteneur Docker Sandbox (4 Go RAM)       │
               │       Exécution & Tests dans ./workspace     │
               └──────────────────────────────────────────────┘
```

---

## 🛠️ Spécifications & Prérequis

* **Moteur d'Inférence Local :** Lemonade (`http://localhost:13305/v1`)
* **Modèle LLM Code Local :** `Qwen3-Coder-30B-A3B-Instruct-GGUF`
* **Modèle Brain / Discussion :** `gemini-2.5-flash`
* **Agent CLI :** Hermes Agent + OpenCode CLI
* **Isolation :** Profil Hermes dédié `LocalAIDemo` + Conteneur Docker `pirates-bay-sandbox`

---

## ⚙️ Procédure d'Installation Pas à Pas

### Step 1 : Configurer OpenCode CLI pour Qwen Coder Local
Fichier de configuration hôte `~/.config/opencode/config.json` :
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

### Step 2 : Configurer le Profil Hermes `LocalAIDemo`
Créez l'arborescence du profil Hermes :
```bash
mkdir -p ~/.hermes/profiles/LocalAIDemo
```

Fichier `~/.hermes/profiles/LocalAIDemo/config.yaml` :
```yaml
model: gemini-2.5-flash
provider: gemini
```

Fichier `~/.hermes/profiles/LocalAIDemo/.env` :
```env
GEMINI_API_KEY="votre_cle_gemini_ici"
```

---

## 🚀 Utilisation en Démo

1. **Lancer la Sandbox Docker du projet :**
   ```bash
   cd PiratesBayLocalAI
   docker compose up -d
   ```

2. **Démarrer Hermes sous le profil `LocalAIDemo` :**
   ```bash
   hermes --profile LocalAIDemo
   ```

3. **Consigne de Démo :**
   Exemple de prompt utilisateur pour l'agent :
   > *"Lis `AGENTS.md`. Utilise OpenCode pour générer et tester le code de la fonctionnalité X uniquement dans `./workspace`."*
