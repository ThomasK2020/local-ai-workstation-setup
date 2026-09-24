#!/usr/bin/env bash
# ==============================================================================
# DEPLOY-HERMES-PERSO-DATA.SH
# Synchronisation Hybride Hermes : GitHub (Configs, Mémoires, Sessions, DB)
#                                + Option Clé USB (Hors-ligne / Skills)
# ==============================================================================
set -euo pipefail

HERMES_DIR="${HOME}/.hermes"
REPO_URL="https://github.com/ThomasK2020/TK-Hermes-data.git"

usage() {
    echo "Usage: $0 [export [github|usb|all]] | [restore [github|usb]]"
    echo ""
    echo "Commandes :"
    echo "  export [github|usb|all]  Sauvegarder configs, DB, mémoires et sessions (défaut: github)"
    echo "  restore [github|usb]     Restaurer les données depuis GitHub ou clé USB (défaut: interactif)"
    exit 1
}

find_usb_data_dir() {
    echo "🔍 Recherche du support USB contenant le dossier '/Hermes-data/'..."
    
    local usb_path=""
    
    for candidate in \
        /run/media/*/*/LLM-backups/Hermes-data \
        /media/*/*/LLM-backups/Hermes-data \
        /run/media/*/*/Hermes-data \
        /media/*/*/Hermes-data \
        /run/media/*/* \
        /media/*/* \
        /mnt/LLM-backups/Hermes-data \
        /mnt/Hermes-data \
        "${HOME}/LLM-backups/Hermes-data"; do
        if [ -d "${candidate}" ] && [ "$(basename "${candidate}")" == "Hermes-data" ]; then
            usb_path="${candidate}"
            break
        elif [ -d "${candidate}/LLM-backups/Hermes-data" ]; then
            usb_path="${candidate}/LLM-backups/Hermes-data"
            break
        elif [ -d "${candidate}/Hermes-data" ]; then
            usb_path="${candidate}/Hermes-data"
            break
        fi
    done

    if [ -z "${usb_path}" ] || [ ! -d "${usb_path}" ]; then
        echo ""
        echo "⚠️ Support USB avec le dossier 'Hermes-data' non détecté automatiquement."
        read -rp "👉 Veuillez insérer votre clé USB et entrer son point de montage (ex: /media/${USER:-$LOGNAME}/USB) : " USER_INPUT_PATH
        if [ -d "${USER_INPUT_PATH}/LLM-backups/Hermes-data" ]; then
            usb_path="${USER_INPUT_PATH}/LLM-backups/Hermes-data"
        elif [ -d "${USER_INPUT_PATH}/Hermes-data" ]; then
            usb_path="${USER_INPUT_PATH}/Hermes-data"
        elif [ -d "${USER_INPUT_PATH}" ]; then
            usb_path="${USER_INPUT_PATH}/Hermes-data"
            mkdir -p "${usb_path}" 2>/dev/null || sudo mkdir -p "${usb_path}" 2>/dev/null || true
        else
            echo "❌ Erreur : Le répertoire '${USER_INPUT_PATH}' n'existe pas !"
            exit 1
        fi
    fi

    echo "✅ Répertoire USB Hermes trouvé : ${usb_path}"
    USB_HERMES_DIR="${usb_path}"
}

prepare_clean_state_db() {
    local source_db="${HERMES_DIR}/state.db"
    local output_clean_db="$1"

    echo "🔍 Vérification de l'intégrité de state.db..."
    local is_clean
    is_clean=$(python3 -c "import sqlite3; con=sqlite3.connect('${source_db}'); print('ok' if list(con.execute('PRAGMA integrity_check;')) == [('ok',)] else 'corrupt')" 2>/dev/null || echo "corrupt")

    if [ "${is_clean}" == "ok" ]; then
        echo "✅ Base state.db saine (intégrité OK)."
        cp "${source_db}" "${output_clean_db}"
    else
        echo "⚠️ Anomalie détectée dans l'index/arbre de state.db. Reconstruction automatique..."
        rm -f "${output_clean_db}" "${output_clean_db}.recovery.json"
        if hermes sessions recover --source "${source_db}" --output "${output_clean_db}" --allow-partial >/dev/null 2>&1; then
            echo "✅ Base reconstruite et assainie avec succès (intégrité parfaite) !"
        else
            echo "⚠️ La reconstruction assistée a échoué, utilisation de la copie brute..."
            cp "${source_db}" "${output_clean_db}"
        fi
    fi
}

export_to_github() {
    echo "======================================================================"
    echo "🌐 Sauvegarde des Sessions, Données et Configurations sur GitHub"
    echo "======================================================================"

    TMP_REPO=$(mktemp -d)
    echo "📥 Clonage du dépôt distant ${REPO_URL}..."
    gh repo clone ThomasK2020/TK-Hermes-data "${TMP_REPO}" 2>/dev/null || git clone "${REPO_URL}" "${TMP_REPO}"

    cd "${TMP_REPO}"
    git config user.name "Thomas Krotkine"
    git config user.email "thomas.krotkine@gmail.com"
    git checkout -b main 2>/dev/null || true

    # 1. Configurations & identifiants
    echo "📄 Sauvegarde des configurations et identifiants..."
    cp "${HERMES_DIR}/config.yaml" ./ 2>/dev/null || true
    cp "${HERMES_DIR}/.env" ./ 2>/dev/null || true
    cp "${HERMES_DIR}/SOUL.md" ./ 2>/dev/null || true

    # 2. Mémoires, automatismes et scripts
    rsync -av --delete --exclude='node_modules' --exclude='.git' "${HERMES_DIR}/memories" ./ 2>/dev/null || true
    rsync -av --delete --exclude='node_modules' --exclude='.git' "${HERMES_DIR}/cron" ./ 2>/dev/null || true
    rsync -av --delete --exclude='node_modules' --exclude='.git' "${HERMES_DIR}/plugins" ./ 2>/dev/null || true
    rsync -av --delete --exclude='node_modules' --exclude='.git' "${HERMES_DIR}/hooks" ./ 2>/dev/null || true
    rsync -av --delete --exclude='node_modules' --exclude='.git' "${HERMES_DIR}/scripts" ./ 2>/dev/null || true

    # 3. Bases de données secondaires
    cp "${HERMES_DIR}/projects.db" ./ 2>/dev/null || true
    cp "${HERMES_DIR}/shared-state.db" ./ 2>/dev/null || true
    cp "${HERMES_DIR}/kanban.db" ./ 2>/dev/null || true

    # 4. Base des conversations et sessions (state.db)
    if [ -f "${HERMES_DIR}/state.db" ]; then
        CLEAN_DB_TMP=$(mktemp --tmpdir state_clean_XXXXXX.db)
        prepare_clean_state_db "${CLEAN_DB_TMP}"

        echo "💾 Compression optimisée de state.db..."
        TMP_XZ=$(mktemp --tmpdir state_db_XXXXXX.xz)
        xz -9 -c "${CLEAN_DB_TMP}" > "${TMP_XZ}"
        rm -f "${CLEAN_DB_TMP}"

        # Nettoyage des anciens fichiers/morceaux dans le repo
        rm -f ./state.db.xz*

        local xz_size
        xz_size=$(wc -c < "${TMP_XZ}")
        if [ "${xz_size}" -le 47185920 ]; then # Moins de 45 Mo -> fichier unique
            mv "${TMP_XZ}" ./state.db.xz
            echo "✅ Archive state.db.xz générée (${xz_size} octets) !"
        else
            echo "✂️ Découpage de l'archive state.db en blocs de 40 Mo (< 50 Mo GitHub)..."
            split -b 40M -d "${TMP_XZ}" ./state.db.xz.part_
            rm -f "${TMP_XZ}"
            echo "✅ Blocs state.db.xz.part_* générés !"
        fi
    fi

    # 5. Transcripts de sessions
    if [ -d "${HERMES_DIR}/sessions" ]; then
        echo "📦 Compression du dossier sessions/..."
        tar -C "${HERMES_DIR}" -cJf ./sessions.tar.xz sessions
        echo "✅ Transcripts sessions/ archivés !"
    fi

    # Inclure le script de synchronisation à jour dans le repo
    cp "$(readlink -f "$0")" ./Deploy-Hermes-Perso-data.sh 2>/dev/null || true

    # 6. Commit et Push
    echo "🚀 Envoi vers GitHub..."
    git add .
    git commit -m "Backup automatique sessions & data Hermes (healthy DB) [$(date '+%Y-%m-%d %H:%M:%S')]" || echo "Aucune modification à commiter."
    git push origin main
    
    cd "${HOME}"
    rm -rf "${TMP_REPO}"
    echo "🎉 Données personnelles et sessions sauvegardées avec succès sur GitHub !"
}

export_to_usb() {
    echo "======================================================================"
    echo "💾 Sauvegarde des Données et Compétences sur Clé USB"
    echo "======================================================================"

    find_usb_data_dir
    mkdir -p "${USB_HERMES_DIR}"

    if [ -f "${HERMES_DIR}/state.db" ]; then
        CLEAN_DB_TMP=$(mktemp --tmpdir state_clean_usb_XXXXXX.db)
        prepare_clean_state_db "${CLEAN_DB_TMP}"

        echo "💾 Compression de state.db pour USB..."
        TMP_GZ=$(mktemp)
        gzip -c -9 "${CLEAN_DB_TMP}" > "${TMP_GZ}"
        rm -f "${CLEAN_DB_TMP}"
        
        echo "💾 Copie de state.db.gz vers USB (${USB_HERMES_DIR}/state.db.gz)..."
        cp "${TMP_GZ}" "${USB_HERMES_DIR}/state.db.gz"
        rm -f "${TMP_GZ}"
        sync
        
        if gzip -t "${USB_HERMES_DIR}/state.db.gz" 2>/dev/null; then
            echo "✅ Base state.db sauvegardée et validée sur USB !"
        else
            echo "⚠️ Avertissement : Échec du test d'archive, copie brute de secours..."
            cp "${HERMES_DIR}/state.db" "${USB_HERMES_DIR}/state.db"
            sync
        fi
    fi

    if [ -d "${HERMES_DIR}/skills" ]; then
        echo "💾 Synchronisation des skills/ vers USB (${USB_HERMES_DIR}/skills/)..."
        rsync -av --delete --exclude='node_modules' --exclude='.git' "${HERMES_DIR}/skills/" "${USB_HERMES_DIR}/skills/"
        echo "✅ Skills sauvegardés sur USB !"
    fi
}

export_data() {
    local target="${1:-github}"
    case "$target" in
        github)
            export_to_github
            ;;
        usb)
            export_to_usb
            ;;
        all)
            export_to_github
            export_to_usb
            ;;
        *)
            echo "Cible inconnue: $target. Utilisation par défaut : github"
            export_to_github
            ;;
    esac
}

restore_from_github() {
    echo "======================================================================"
    echo "🌐 Restauration Complète depuis GitHub (TK-Hermes-data)"
    echo "======================================================================"

    mkdir -p "${HERMES_DIR}"
    TMP_REPO=$(mktemp -d)

    echo "📥 Téléchargement des données depuis GitHub..."
    gh repo clone ThomasK2020/TK-Hermes-data "${TMP_REPO}" 2>/dev/null || git clone "${REPO_URL}" "${TMP_REPO}"

    # 1. Configs & Identifiants
    echo "📄 Restauration des configurations et identifiants..."
    cp "${TMP_REPO}/config.yaml" "${HERMES_DIR}/" 2>/dev/null || true
    cp "${TMP_REPO}/SOUL.md" "${HERMES_DIR}/" 2>/dev/null || true
    if [ -f "${TMP_REPO}/.env" ]; then
        cp "${TMP_REPO}/.env" "${HERMES_DIR}/"
        chmod 600 "${HERMES_DIR}/.env"
    fi

    # 2. Mémoires, automatismes et scripts
    for dir in memories cron plugins hooks scripts; do
        if [ -d "${TMP_REPO}/${dir}" ]; then
            echo "📁 Restauration de ${dir}/..."
            mkdir -p "${HERMES_DIR}/${dir}"
            rsync -av "${TMP_REPO}/${dir}/" "${HERMES_DIR}/${dir}/"
        fi
    done

    # 3. Bases secondaires
    for db in projects.db shared-state.db kanban.db; do
        if [ -f "${TMP_REPO}/${db}" ]; then
            cp "${TMP_REPO}/${db}" "${HERMES_DIR}/"
        fi
    done

    # 4. Restauration de state.db (Conversations)
    if [ -f "${TMP_REPO}/state.db.xz" ]; then
        echo "💾 Décompression de state.db.xz..."
        xz -dc "${TMP_REPO}/state.db.xz" > "${HERMES_DIR}/state.db"
        echo "✅ Base state.db restaurée !"
    elif compgen -G "${TMP_REPO}/state.db.xz.part_*" > /dev/null; then
        echo "💾 Reconstitution et décompression de la base state.db..."
        cat "${TMP_REPO}"/state.db.xz.part_* | xz -d > "${HERMES_DIR}/state.db"
        echo "✅ Base state.db reconstituée avec succès !"
    fi

    # 5. Restauration de sessions/
    if [ -f "${TMP_REPO}/sessions.tar.xz" ]; then
        echo "📂 Décompression des transcripts de sessions/..."
        mkdir -p "${HERMES_DIR}/sessions"
        tar -xJf "${TMP_REPO}/sessions.tar.xz" -C "${HERMES_DIR}/"
        echo "✅ Dossier sessions/ restauré !"
    fi

    rm -rf "${TMP_REPO}"

    echo ""
    echo "🔍 Vérification de la reprise des sessions..."
    if command -v hermes >/dev/null 2>&1; then
        local is_clean
        is_clean=$(python3 -c "import sqlite3; con=sqlite3.connect('${HERMES_DIR}/state.db'); print('ok' if list(con.execute('PRAGMA integrity_check;')) == [('ok',)] else 'corrupt')" 2>/dev/null || echo "corrupt")
        if [ "${is_clean}" != "ok" ]; then
            echo "🔧 Réparation automatique du schéma/index..."
            hermes sessions repair --no-backup 2>/dev/null || true
        fi
        hermes sessions stats || true
    fi
    echo "🎉 Restauration GitHub terminée avec succès !"
}

restore_from_usb() {
    echo "======================================================================"
    echo "💾 Restauration depuis la Clé USB"
    echo "======================================================================"

    mkdir -p "${HERMES_DIR}"
    find_usb_data_dir

    if [ -f "${USB_HERMES_DIR}/state.db.gz" ]; then
        echo "💾 Test d'intégrité de state.db.gz sur USB..."
        if gzip -t "${USB_HERMES_DIR}/state.db.gz" 2>/dev/null; then
            echo "💾 Décompression de state.db depuis USB..."
            gunzip -c "${USB_HERMES_DIR}/state.db.gz" > "${HERMES_DIR}/state.db"
            echo "✅ Base state.db restaurée avec succès !"
        else
            echo "⚠️ Avertissement : Archive corrompue, tentative de copie directe..."
            if [ -f "${USB_HERMES_DIR}/state.db" ]; then
                cp "${USB_HERMES_DIR}/state.db" "${HERMES_DIR}/state.db"
                echo "✅ Base state.db restaurée depuis la copie brute !"
            fi
        fi
    elif [ -f "${USB_HERMES_DIR}/state.db" ]; then
        echo "💾 Copie directe de state.db depuis USB..."
        cp "${USB_HERMES_DIR}/state.db" "${HERMES_DIR}/state.db"
        echo "✅ Base state.db restaurée !"
    fi

    if [ -d "${USB_HERMES_DIR}/skills" ]; then
        echo "💾 Restauration des skills/ depuis USB..."
        mkdir -p "${HERMES_DIR}/skills"
        rsync -av "${USB_HERMES_DIR}/skills/" "${HERMES_DIR}/skills/"
        echo "✅ Skills restaurés !"
    fi

    echo ""
    echo "🔍 Vérification de la reprise des sessions..."
    if command -v hermes >/dev/null 2>&1; then
        local is_clean
        is_clean=$(python3 -c "import sqlite3; con=sqlite3.connect('${HERMES_DIR}/state.db'); print('ok' if list(con.execute('PRAGMA integrity_check;')) == [('ok',)] else 'corrupt')" 2>/dev/null || echo "corrupt")
        if [ "${is_clean}" != "ok" ]; then
            echo "🔧 Réparation automatique du schéma/index..."
            hermes sessions repair --no-backup 2>/dev/null || true
        fi
        hermes sessions stats || true
    fi
    echo "🎉 Restauration USB terminée avec succès !"
}

restore_data() {
    local target="${1:-}"
    if [ -z "$target" ]; then
        echo "======================================================================"
        echo "👉 Choisissez la méthode de restauration :"
        echo "  1) GitHub (Réseau - Sessions + Configs + Mémoires + Databases) [Recommandé]"
        echo "  2) Clé USB (Hors-ligne - DB + Skills volumineux)"
        echo "======================================================================"
        read -rp "Votre choix [1/2] (défaut: 1) : " CHOICE
        case "${CHOICE:-1}" in
            2|usb)
                target="usb"
                ;;
            1|github|*)
                target="github"
                ;;
        esac
    fi

    case "$target" in
        github)
            restore_from_github
            ;;
        usb)
            restore_from_usb
            ;;
        *)
            echo "Option inconnue : $target. Annulation."
            exit 1
            ;;
    esac
}

if [[ $# -lt 1 ]]; then
    usage
fi

ACTION="$1"
shift || true
TARGET="${1:-}"

case "$ACTION" in
    export)
        export_data "${TARGET}"
        ;;
    restore)
        restore_data "${TARGET}"
        ;;
    *)
        usage
        ;;
esac
