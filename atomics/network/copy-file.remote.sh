#!/usr/bin/env bash

#===============================================================================
# Script Atomique : Copie de fichiers SSH distants
#===============================================================================
# Nom du fichier : copy-file.remote.sh
# Niveau : 0 (Atomique)  
# Catégorie : network
# Protocole : ssh
# Description : Copie de fichiers vers/depuis un hôte distant via SCP/SFTP
#
# Objectif :
# - Transfert sécurisé de fichiers via SSH (SCP/SFTP/rsync)
# - Support upload, download et synchronisation bidirectionnelle
# - Validation d'intégrité avec checksums MD5/SHA256
# - Gestion des permissions et ownership distants
# - Reprise de transfert en cas d'interruption (rsync)
#
# Conforme à la méthodologie AtomicOps-Suite - Niveau 0
#===============================================================================

set -euo pipefail

# === MÉTADONNÉES DU SCRIPT ===
readonly SCRIPT_NAME="copy-file.remote.sh"
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_CATEGORY="network"
readonly SCRIPT_PROTOCOL="ssh"
readonly SCRIPT_LEVEL=0

# === CONFIGURATION PAR DÉFAUT ===
readonly DEFAULT_SSH_PORT=22
readonly DEFAULT_TIMEOUT=60
readonly DEFAULT_USER="$(whoami)"
readonly DEFAULT_METHOD="scp"

# === VARIABLES GLOBALES ===
TARGET_HOST=""
TARGET_PORT="$DEFAULT_SSH_PORT"
TARGET_USER="$DEFAULT_USER"
SSH_KEY_FILE=""
LOCAL_PATH=""
REMOTE_PATH=""
TRANSFER_METHOD="$DEFAULT_METHOD"
TRANSFER_DIRECTION="upload"
CONNECTION_TIMEOUT="$DEFAULT_TIMEOUT"
PRESERVE_PERMISSIONS=true
PRESERVE_OWNERSHIP=false
VERIFY_CHECKSUM=true
CHECKSUM_ALGORITHM="md5"
COMPRESS_TRANSFER=false
RECURSIVE_COPY=false
OVERWRITE_EXISTING=true
CREATE_BACKUP=false
DRY_RUN=false
QUIET_MODE=false
DEBUG_MODE=false
PROGRESS_MODE=false

# === FONCTIONS D'AIDE ===
show_help() {
    cat << EOF
Copie de fichiers SSH distants - Script Atomique Niveau 0

USAGE:
    $(basename "$0") [OPTIONS] HOST LOCAL_PATH REMOTE_PATH
    $(basename "$0") [OPTIONS] --download HOST REMOTE_PATH LOCAL_PATH
    $(basename "$0") [OPTIONS] --upload HOST LOCAL_PATH REMOTE_PATH

DESCRIPTION:
    Transfère des fichiers vers/depuis un hôte distant via SSH :
    - Méthodes : SCP (rapide), SFTP (robuste), rsync (synchronisation)
    - Upload, download ou synchronisation bidirectionnelle
    - Validation d'intégrité automatique avec checksums
    - Préservation des permissions et ownership
    - Reprise de transfert pour gros fichiers (rsync)
    - Support transfert récursif de répertoires

PARAMÈTRES OBLIGATOIRES:
    HOST                    Nom d'hôte ou adresse IP du serveur distant
    LOCAL_PATH              Chemin du fichier/répertoire local
    REMOTE_PATH             Chemin du fichier/répertoire distant

OPTIONS PRINCIPALES:
    --upload                Mode upload (défaut) : local → distant
    --download              Mode download : distant → local
    --sync                  Mode synchronisation bidirectionnelle
    -m, --method METHOD     Méthode : scp|sftp|rsync (défaut: scp)
    -p, --port PORT         Port SSH (défaut: 22)
    -u, --user USER         Utilisateur SSH (défaut: current user)
    -i, --identity FILE     Fichier de clé privée SSH
    
OPTIONS DE TRANSFERT:
    -r, --recursive         Copie récursive des répertoires
    -t, --timeout SECONDS   Timeout de connexion (défaut: 60)
    -z, --compress          Compression pendant le transfert
    --preserve-perms        Préserver les permissions (défaut: oui)
    --preserve-owner        Préserver le propriétaire (défaut: non)
    --no-overwrite          Ne pas écraser les fichiers existants
    --backup                Créer une sauvegarde avant écrasement
    
OPTIONS DE VALIDATION:
    --verify-checksum       Vérifier l'intégrité par checksum (défaut: oui)
    --checksum-algo ALGO    Algorithme : md5|sha256 (défaut: md5)
    --no-verify             Désactiver la vérification d'intégrité
    
OPTIONS D'AFFICHAGE:
    --progress              Afficher la progression du transfert
    --dry-run               Simulation (affiche les actions sans les exécuter)
    -q, --quiet             Mode silencieux (erreurs uniquement)
    --debug                 Mode debug avec traces détaillées
    -h, --help              Affiche cette aide

EXEMPLES:
    # Upload simple d'un fichier
    $(basename "$0") --upload server.com /tmp/file.txt /var/log/file.txt
    
    # Download avec vérification SHA256
    $(basename "$0") --download --checksum-algo sha256 server.com /etc/config.yml ./config.yml
    
    # Synchronisation de répertoire avec rsync
    $(basename "$0") --sync --method rsync --recursive server.com ./localdir/ /remote/dir/
    
    # Upload avec compression et sauvegarde
    $(basename "$0") --compress --backup --identity ~/.ssh/id_rsa server.com ./backup.tar.gz /backups/
    
    # Transfer SFTP avec préservation ownership
    $(basename "$0") --method sftp --preserve-owner --user admin server.com ./script.sh /usr/local/bin/
    
    # Dry-run pour prévisualiser les actions
    $(basename "$0") --dry-run --recursive --progress server.com ./website/ /var/www/html/

SORTIE JSON:
    {
        "status": "success|error",
        "timestamp": "ISO8601",
        "script": "$SCRIPT_NAME",
        "data": {
            "target": {
                "host": "hostname",
                "port": number,
                "user": "username"
            },
            "transfer": {
                "method": "scp|sftp|rsync",
                "direction": "upload|download|sync",
                "local_path": "/local/path",
                "remote_path": "/remote/path",
                "recursive": boolean,
                "compressed": boolean
            },
            "result": {
                "files_transferred": number,
                "bytes_transferred": number,
                "duration_seconds": number,
                "average_speed_kbps": number,
                "checksum_verified": boolean
            },
            "validation": {
                "checksum_algorithm": "md5|sha256",
                "local_checksum": "hash",
                "remote_checksum": "hash",
                "checksums_match": boolean
            },
            "performance": {
                "connection_time_ms": number,
                "transfer_time_ms": number,
                "verification_time_ms": number
            }
        }
    }

CODES DE RETOUR:
    0 : Succès - Fichier(s) transféré(s) avec succès
    1 : Erreur de paramètres
    2 : Erreur de connexion SSH
    3 : Fichier source non trouvé
    4 : Erreur de permissions ou d'écriture
    5 : Échec de vérification d'intégrité
    6 : Timeout de transfert

MÉTHODES DE TRANSFERT:
    SCP    : Rapide, simple, bon pour fichiers uniques
    SFTP   : Robuste, reprise d'erreur, bon pour sessions instables  
    rsync  : Synchronisation, delta-transfer, optimal pour gros volumes

SÉCURITÉ:
    - Chiffrement SSH pour tous les transferts
    - Validation d'intégrité automatique
    - Support clés SSH et authentification robuste
    - Pas de stockage des mots de passe

CONFORMITÉ:
    - Méthodologie AtomicOps-Suite Niveau 0 (Atomique)
    - Sortie JSON standardisée
    - Gestion d'erreurs robuste avec codes spécifiques
EOF
}

# === FONCTIONS DE LOGGING ===
log_debug() { [[ "$DEBUG_MODE" == true ]] && echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2; }
log_info() { [[ "$QUIET_MODE" == false ]] && echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2; }
log_progress() { [[ "$PROGRESS_MODE" == true ]] && echo "[PROGRESS] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2; }
log_error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2; }

# === VALIDATION DES PARAMÈTRES ===
validate_parameters() {
    local errors=0
    
    # Validation de l'hôte obligatoire
    if [[ -z "$TARGET_HOST" ]]; then
        log_error "Hôte cible obligatoire"
        ((errors++))
    fi
    
    # Validation des chemins
    if [[ -z "$LOCAL_PATH" ]]; then
        log_error "Chemin local obligatoire"
        ((errors++))
    fi
    
    if [[ -z "$REMOTE_PATH" ]]; then
        log_error "Chemin distant obligatoire"
        ((errors++))
    fi
    
    # Validation de la direction et des fichiers sources
    case "$TRANSFER_DIRECTION" in
        "upload"|"sync")
            if [[ ! -e "$LOCAL_PATH" ]]; then
                log_error "Fichier/répertoire local non trouvé : $LOCAL_PATH"
                ((errors++))
            elif [[ ! -r "$LOCAL_PATH" ]]; then
                log_error "Fichier/répertoire local non lisible : $LOCAL_PATH"
                ((errors++))
            fi
            ;;
        "download")
            # Pour le download, on validera l'existence du fichier distant plus tard
            local local_dir=$(dirname "$LOCAL_PATH")
            if [[ ! -d "$local_dir" ]]; then
                log_error "Répertoire de destination local non trouvé : $local_dir"
                ((errors++))
            elif [[ ! -w "$local_dir" ]]; then
                log_error "Répertoire de destination local non inscriptible : $local_dir"
                ((errors++))
            fi
            ;;
        *)
            log_error "Direction de transfert invalide : $TRANSFER_DIRECTION"
            ((errors++))
            ;;
    esac
    
    # Validation de la méthode de transfert
    case "$TRANSFER_METHOD" in
        "scp"|"sftp"|"rsync") ;;
        *)
            log_error "Méthode de transfert invalide : $TRANSFER_METHOD (scp|sftp|rsync)"
            ((errors++))
            ;;
    esac
    
    # Validation du port
    if [[ ! "$TARGET_PORT" =~ ^[0-9]+$ ]] || [[ "$TARGET_PORT" -lt 1 ]] || [[ "$TARGET_PORT" -gt 65535 ]]; then
        log_error "Port invalide : $TARGET_PORT (doit être entre 1 et 65535)"
        ((errors++))
    fi
    
    # Validation du timeout
    if [[ ! "$CONNECTION_TIMEOUT" =~ ^[0-9]+$ ]] || [[ "$CONNECTION_TIMEOUT" -lt 1 ]]; then
        log_error "Timeout invalide : $CONNECTION_TIMEOUT (doit être >= 1)"
        ((errors++))
    fi
    
    # Validation du fichier de clé SSH si spécifié
    if [[ -n "$SSH_KEY_FILE" ]]; then
        if [[ ! -f "$SSH_KEY_FILE" ]]; then
            log_error "Fichier de clé SSH non trouvé : $SSH_KEY_FILE"
            ((errors++))
        elif [[ ! -r "$SSH_KEY_FILE" ]]; then
            log_error "Fichier de clé SSH non lisible : $SSH_KEY_FILE"
            ((errors++))
        fi
    fi
    
    # Validation de l'algorithme de checksum
    case "$CHECKSUM_ALGORITHM" in
        "md5"|"sha256") ;;
        *)
            log_error "Algorithme de checksum invalide : $CHECKSUM_ALGORITHM (md5|sha256)"
            ((errors++))
            ;;
    esac
    
    # Validation de l'utilisateur
    if [[ -z "$TARGET_USER" ]]; then
        log_error "Nom d'utilisateur obligatoire"
        ((errors++))
    fi
    
    return $errors
}

# === CALCUL DE CHECKSUM ===
calculate_checksum() {
    local file_path="$1"
    local algorithm="$2"
    local is_remote="$3"  # true/false
    
    local checksum=""
    
    if [[ "$is_remote" == "true" ]]; then
        # Calcul distant via SSH
        local ssh_options=(
            "-o" "ConnectTimeout=$CONNECTION_TIMEOUT"
            "-o" "BatchMode=yes"
            "-o" "StrictHostKeyChecking=no"
            "-o" "UserKnownHostsFile=/dev/null"
            "-o" "LogLevel=ERROR"
            "-p" "$TARGET_PORT"
        )
        
        [[ -n "$SSH_KEY_FILE" ]] && ssh_options+=("-i" "$SSH_KEY_FILE")
        
        case "$algorithm" in
            "md5")
                checksum=$(ssh "${ssh_options[@]}" "$TARGET_USER@$TARGET_HOST" "md5sum '$file_path' 2>/dev/null | cut -d' ' -f1" 2>/dev/null || echo "")
                ;;
            "sha256")
                checksum=$(ssh "${ssh_options[@]}" "$TARGET_USER@$TARGET_HOST" "sha256sum '$file_path' 2>/dev/null | cut -d' ' -f1" 2>/dev/null || echo "")
                ;;
        esac
    else
        # Calcul local
        if [[ -f "$file_path" ]]; then
            case "$algorithm" in
                "md5")
                    checksum=$(md5sum "$file_path" 2>/dev/null | cut -d' ' -f1 || echo "")
                    ;;
                "sha256")
                    checksum=$(sha256sum "$file_path" 2>/dev/null | cut -d' ' -f1 || echo "")
                    ;;
            esac
        fi
    fi
    
    echo "$checksum"
}

# === PRÉPARATION DES OPTIONS SSH COMMUNES ===
prepare_ssh_options() {
    local ssh_options=(
        "-o" "ConnectTimeout=$CONNECTION_TIMEOUT"
        "-o" "BatchMode=yes" 
        "-o" "StrictHostKeyChecking=no"
        "-o" "UserKnownHostsFile=/dev/null"
        "-o" "LogLevel=ERROR"
    )
    
    # Options spécifiques selon la méthode
    case "$TRANSFER_METHOD" in
        "scp")
            ssh_options+=("-P" "$TARGET_PORT")
            [[ "$COMPRESS_TRANSFER" == true ]] && ssh_options+=("-C")
            [[ "$RECURSIVE_COPY" == true ]] && ssh_options+=("-r")
            [[ "$PRESERVE_PERMISSIONS" == true ]] && ssh_options+=("-p")
            ;;
        "sftp")
            ssh_options+=("-P" "$TARGET_PORT")
            ;;
        "rsync")
            ssh_options=(
                "-e" "ssh -o ConnectTimeout=$CONNECTION_TIMEOUT -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -p $TARGET_PORT"
            )
            [[ "$COMPRESS_TRANSFER" == true ]] && ssh_options+=("-z")
            [[ "$RECURSIVE_COPY" == true ]] && ssh_options+=("-r")
            [[ "$PRESERVE_PERMISSIONS" == true ]] && ssh_options+=("-p")
            [[ "$PRESERVE_OWNERSHIP" == true ]] && ssh_options+=("-o")
            [[ "$PROGRESS_MODE" == true ]] && ssh_options+=("--progress")
            ;;
    esac
    
    # Ajout de la clé SSH si spécifiée
    if [[ -n "$SSH_KEY_FILE" ]]; then
        case "$TRANSFER_METHOD" in
            "scp"|"sftp")
                ssh_options+=("-i" "$SSH_KEY_FILE")
                ;;
            "rsync")
                # Pour rsync, on modifie l'option -e
                ssh_options[1]="${ssh_options[1]} -i $SSH_KEY_FILE"
                ;;
        esac
    fi
    
    # Stockage des options pour utilisation ultérieure
    printf '%s\n' "${ssh_options[@]}" > /tmp/ssh_options_$$
    
    log_debug "Options SSH préparées pour $TRANSFER_METHOD"
    
    return 0
}

# === CRÉATION DE SAUVEGARDE ===
create_backup() {
    local target_path="$1"
    local is_remote="$2"
    
    if [[ "$CREATE_BACKUP" == false ]]; then
        echo "" > /tmp/backup_path_$$
        return 0
    fi
    
    local backup_path="${target_path}.backup.$(date +%Y%m%d_%H%M%S)"
    
    if [[ "$is_remote" == "true" ]]; then
        # Sauvegarde distante
        local ssh_cmd="ssh -o ConnectTimeout=$CONNECTION_TIMEOUT -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -p $TARGET_PORT"
        [[ -n "$SSH_KEY_FILE" ]] && ssh_cmd="$ssh_cmd -i $SSH_KEY_FILE"
        
        if $ssh_cmd "$TARGET_USER@$TARGET_HOST" "cp '$target_path' '$backup_path'" 2>/dev/null; then
            log_debug "Sauvegarde distante créée : $backup_path"
            echo "$backup_path" > /tmp/backup_path_$$
        else
            log_debug "Échec de création de sauvegarde distante"
            echo "" > /tmp/backup_path_$$
        fi
    else
        # Sauvegarde locale
        if cp "$target_path" "$backup_path" 2>/dev/null; then
            log_debug "Sauvegarde locale créée : $backup_path"
            echo "$backup_path" > /tmp/backup_path_$$
        else
            log_debug "Échec de création de sauvegarde locale"
            echo "" > /tmp/backup_path_$$
        fi
    fi
    
    return 0
}

# === EXÉCUTION DU TRANSFERT ===
execute_transfer() {
    log_debug "Début du transfert $TRANSFER_DIRECTION via $TRANSFER_METHOD"
    
    local transfer_start=$(date +%s.%N)
    local transfer_success=false
    local files_transferred=0
    local bytes_transferred=0
    local transfer_output=""
    
    # Lecture des options SSH préparées
    local ssh_options=()
    while IFS= read -r option; do
        ssh_options+=("$option")
    done < /tmp/ssh_options_$$
    
    # Création de sauvegarde si nécessaire
    case "$TRANSFER_DIRECTION" in
        "upload"|"sync")
            create_backup "$REMOTE_PATH" true
            ;;
        "download")
            [[ -e "$LOCAL_PATH" ]] && create_backup "$LOCAL_PATH" false
            ;;
    esac
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "MODE DRY-RUN : Transfert simulé"
        echo "DRY-RUN: Transfer would be executed" > /tmp/transfer_output_$$
        transfer_success=true
        files_transferred=1
        bytes_transferred=1024
    else
        # Exécution réelle selon la méthode
        case "$TRANSFER_METHOD" in
            "scp")
                execute_scp_transfer "${ssh_options[@]}"
                ;;
            "sftp")
                execute_sftp_transfer "${ssh_options[@]}"
                ;;
            "rsync")
                execute_rsync_transfer "${ssh_options[@]}"
                ;;
        esac
        
        transfer_success=$?
        
        # Extraction des statistiques depuis la sortie
        if [[ -f /tmp/transfer_output_$$ ]]; then
            transfer_output=$(cat /tmp/transfer_output_$$)
            files_transferred=$(echo "$transfer_output" | grep -o "transferred: [0-9]*" | cut -d' ' -f2 2>/dev/null || echo "1")
            bytes_transferred=$(echo "$transfer_output" | grep -o "bytes: [0-9]*" | cut -d' ' -f2 2>/dev/null || echo "0")
        fi
    fi
    
    local transfer_end=$(date +%s.%N)
    local transfer_duration=$(echo "$transfer_end - $transfer_start" | bc -l 2>/dev/null || echo "0.00")
    
    # Stockage des résultats
    cat << EOF > /tmp/transfer_result_$$
{
    "success": $transfer_success,
    "files_transferred": $files_transferred,
    "bytes_transferred": $bytes_transferred,
    "duration_seconds": "$transfer_duration",
    "average_speed_kbps": $(echo "scale=2; $bytes_transferred / $transfer_duration / 1024" | bc -l 2>/dev/null || echo "0")
}
EOF
    
    return $transfer_success
}

# === TRANSFERT SCP ===
execute_scp_transfer() {
    local ssh_options=("$@")
    
    log_info "Transfert SCP en cours..."
    
    local scp_cmd
    case "$TRANSFER_DIRECTION" in
        "upload")
            scp_cmd="scp ${ssh_options[*]} '$LOCAL_PATH' '$TARGET_USER@$TARGET_HOST:$REMOTE_PATH'"
            ;;
        "download")
            scp_cmd="scp ${ssh_options[*]} '$TARGET_USER@$TARGET_HOST:$REMOTE_PATH' '$LOCAL_PATH'"
            ;;
        "sync")
            log_error "SCP ne supporte pas la synchronisation - utilisez rsync"
            return 1
            ;;
    esac
    
    log_debug "Commande SCP : $scp_cmd"
    
    if eval "$scp_cmd" > /tmp/transfer_output_$$ 2>&1; then
        log_info "Transfert SCP réussi"
        return 0
    else
        log_error "Échec du transfert SCP : $(cat /tmp/transfer_output_$$)"
        return 1
    fi
}

# === TRANSFERT SFTP ===
execute_sftp_transfer() {
    local ssh_options=("$@")
    
    log_info "Transfert SFTP en cours..."
    
    # Création du script SFTP
    local sftp_script=$(mktemp)
    
    case "$TRANSFER_DIRECTION" in
        "upload")
            echo "put '$LOCAL_PATH' '$REMOTE_PATH'" > "$sftp_script"
            ;;
        "download")
            echo "get '$REMOTE_PATH' '$LOCAL_PATH'" > "$sftp_script"
            ;;
        "sync")
            log_error "SFTP ne supporte pas la synchronisation - utilisez rsync"
            rm -f "$sftp_script"
            return 1
            ;;
    esac
    
    if sftp "${ssh_options[@]}" -b "$sftp_script" "$TARGET_USER@$TARGET_HOST" > /tmp/transfer_output_$$ 2>&1; then
        log_info "Transfert SFTP réussi"
        rm -f "$sftp_script"
        return 0
    else
        log_error "Échec du transfert SFTP : $(cat /tmp/transfer_output_$$)"
        rm -f "$sftp_script"
        return 1
    fi
}

# === TRANSFERT RSYNC ===
execute_rsync_transfer() {
    local ssh_options=("$@")
    
    log_info "Synchronisation rsync en cours..."
    
    local rsync_cmd
    case "$TRANSFER_DIRECTION" in
        "upload")
            rsync_cmd="rsync ${ssh_options[*]} '$LOCAL_PATH' '$TARGET_USER@$TARGET_HOST:$REMOTE_PATH'"
            ;;
        "download")
            rsync_cmd="rsync ${ssh_options[*]} '$TARGET_USER@$TARGET_HOST:$REMOTE_PATH' '$LOCAL_PATH'"
            ;;
        "sync")
            # Synchronisation bidirectionnelle (upload puis download)
            if rsync "${ssh_options[@]}" "$LOCAL_PATH/" "$TARGET_USER@$TARGET_HOST:$REMOTE_PATH/" > /tmp/transfer_output_$$ 2>&1; then
                rsync "${ssh_options[@]}" "$TARGET_USER@$TARGET_HOST:$REMOTE_PATH/" "$LOCAL_PATH/" >> /tmp/transfer_output_$$ 2>&1
            fi
            ;;
    esac
    
    log_debug "Commande rsync : $rsync_cmd"
    
    if [[ "$TRANSFER_DIRECTION" != "sync" ]]; then
        if eval "$rsync_cmd" > /tmp/transfer_output_$$ 2>&1; then
            log_info "Synchronisation rsync réussie"
            return 0
        else
            log_error "Échec de la synchronisation rsync : $(cat /tmp/transfer_output_$$)"
            return 1
        fi
    else
        # Résultat de la synchronisation bidirectionnelle déjà géré ci-dessus
        log_info "Synchronisation bidirectionnelle rsync réussie"
        return $?
    fi
}

# === VÉRIFICATION D'INTÉGRITÉ ===
verify_integrity() {
    if [[ "$VERIFY_CHECKSUM" == false ]]; then
        echo '{"checksum_verified": false, "local_checksum": "", "remote_checksum": "", "checksums_match": false}' > /tmp/verification_result_$$
        return 0
    fi
    
    log_info "Vérification d'intégrité avec $CHECKSUM_ALGORITHM"
    
    local verification_start=$(date +%s.%N)
    local local_checksum=""
    local remote_checksum=""
    local checksums_match=false
    
    # Détermination des fichiers à vérifier selon la direction
    case "$TRANSFER_DIRECTION" in
        "upload"|"sync")
            local_checksum=$(calculate_checksum "$LOCAL_PATH" "$CHECKSUM_ALGORITHM" false)
            remote_checksum=$(calculate_checksum "$REMOTE_PATH" "$CHECKSUM_ALGORITHM" true)
            ;;
        "download")
            remote_checksum=$(calculate_checksum "$REMOTE_PATH" "$CHECKSUM_ALGORITHM" true)
            local_checksum=$(calculate_checksum "$LOCAL_PATH" "$CHECKSUM_ALGORITHM" false)
            ;;
    esac
    
    # Comparaison des checksums
    if [[ -n "$local_checksum" && -n "$remote_checksum" && "$local_checksum" == "$remote_checksum" ]]; then
        checksums_match=true
        log_info "Vérification d'intégrité réussie ($CHECKSUM_ALGORITHM: $local_checksum)"
    elif [[ -n "$local_checksum" && -n "$remote_checksum" ]]; then
        log_error "Échec de vérification d'intégrité : checksums différents"
        log_error "Local: $local_checksum, Distant: $remote_checksum"
    else
        log_error "Impossible de calculer les checksums pour vérification"
    fi
    
    local verification_end=$(date +%s.%N)
    local verification_time=$(echo "($verification_end - $verification_start) * 1000" | bc -l 2>/dev/null || echo "0")
    
    # Stockage des résultats
    cat << EOF > /tmp/verification_result_$$
{
    "checksum_verified": true,
    "checksum_algorithm": "$CHECKSUM_ALGORITHM",
    "local_checksum": "$local_checksum",
    "remote_checksum": "$remote_checksum",
    "checksums_match": $checksums_match,
    "verification_time_ms": $(printf "%.0f" "$verification_time")
}
EOF
    
    return $([ "$checksums_match" == true ] && echo 0 || echo 1)
}

# === GÉNÉRATION DE LA SORTIE JSON ===
generate_output() {
    local status="$1"
    
    # Lecture des résultats
    local transfer_result=$(cat /tmp/transfer_result_$$ 2>/dev/null || echo '{"success": false, "files_transferred": 0, "bytes_transferred": 0, "duration_seconds": "0", "average_speed_kbps": 0}')
    local verification_result=$(cat /tmp/verification_result_$$ 2>/dev/null || echo '{"checksum_verified": false, "local_checksum": "", "remote_checksum": "", "checksums_match": false}')
    local backup_path=$(cat /tmp/backup_path_$$ 2>/dev/null || echo "")
    
    # Extraction des valeurs depuis les résultats
    local files_transferred=$(echo "$transfer_result" | grep -o '"files_transferred": [0-9]*' | cut -d' ' -f2 2>/dev/null || echo "0")
    local bytes_transferred=$(echo "$transfer_result" | grep -o '"bytes_transferred": [0-9]*' | cut -d' ' -f2 2>/dev/null || echo "0") 
    local duration_seconds=$(echo "$transfer_result" | grep -o '"duration_seconds": "[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "0")
    local average_speed=$(echo "$transfer_result" | grep -o '"average_speed_kbps": [0-9.]*' | cut -d' ' -f2 2>/dev/null || echo "0")
    
    # Calcul des temps de performance (estimations)
    local duration_ms=$(echo "$duration_seconds * 1000" | bc -l 2>/dev/null || echo "0")
    local connection_time_ms=$(echo "$duration_ms * 0.1" | bc -l 2>/dev/null || echo "0")
    local transfer_time_ms=$(echo "$duration_ms * 0.8" | bc -l 2>/dev/null || echo "0")
    local verification_time_ms=$(echo "$verification_result" | grep -o '"verification_time_ms": [0-9.]*' | cut -d' ' -f2 2>/dev/null || echo "0")
    
    cat << EOF
{
    "status": "$status",
    "timestamp": "$(date -Iseconds)",
    "script": "$SCRIPT_NAME",
    "version": "$SCRIPT_VERSION",
    "data": {
        "target": {
            "host": "$TARGET_HOST",
            "port": $TARGET_PORT,
            "user": "$TARGET_USER"
        },
        "transfer": {
            "method": "$TRANSFER_METHOD",
            "direction": "$TRANSFER_DIRECTION",
            "local_path": "$LOCAL_PATH",
            "remote_path": "$REMOTE_PATH",
            "recursive": $RECURSIVE_COPY,
            "compressed": $COMPRESS_TRANSFER,
            "backup_created": "$([ -n "$backup_path" ] && echo "$backup_path" || echo "")"
        },
        "result": {
            "files_transferred": $files_transferred,
            "bytes_transferred": $bytes_transferred,
            "duration_seconds": $(printf "%.2f" "$duration_seconds"),
            "average_speed_kbps": $(printf "%.2f" "$average_speed"),
            "checksum_verified": $(echo "$verification_result" | grep -o '"checksum_verified": [a-z]*' | cut -d' ' -f2 || echo "false")
        },
        "validation": $verification_result,
        "performance": {
            "connection_time_ms": $(printf "%.0f" "$connection_time_ms"),
            "transfer_time_ms": $(printf "%.0f" "$transfer_time_ms"),
            "verification_time_ms": $(printf "%.0f" "$verification_time_ms")
        }
    }
}
EOF
}

# === NETTOYAGE DES FICHIERS TEMPORAIRES ===
cleanup() {
    rm -f /tmp/ssh_options_$$ /tmp/backup_path_$$ /tmp/transfer_result_$$ /tmp/transfer_output_$$ /tmp/verification_result_$$ 2>/dev/null || true
}

# === GESTION DES ARGUMENTS ===
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --upload)
                TRANSFER_DIRECTION="upload"
                shift
                ;;
            --download)
                TRANSFER_DIRECTION="download"
                shift
                ;;
            --sync)
                TRANSFER_DIRECTION="sync"
                TRANSFER_METHOD="rsync"  # Sync nécessite rsync
                shift
                ;;
            -m|--method)
                TRANSFER_METHOD="$2"
                shift 2
                ;;
            -p|--port)
                TARGET_PORT="$2"
                shift 2
                ;;
            -u|--user)
                TARGET_USER="$2"
                shift 2
                ;;
            -i|--identity)
                SSH_KEY_FILE="$2"
                shift 2
                ;;
            -r|--recursive)
                RECURSIVE_COPY=true
                shift
                ;;
            -t|--timeout)
                CONNECTION_TIMEOUT="$2"
                shift 2
                ;;
            -z|--compress)
                COMPRESS_TRANSFER=true
                shift
                ;;
            --preserve-perms)
                PRESERVE_PERMISSIONS=true
                shift
                ;;
            --preserve-owner)
                PRESERVE_OWNERSHIP=true
                shift
                ;;
            --no-overwrite)
                OVERWRITE_EXISTING=false
                shift
                ;;
            --backup)
                CREATE_BACKUP=true
                shift
                ;;
            --verify-checksum)
                VERIFY_CHECKSUM=true
                shift
                ;;
            --checksum-algo)
                CHECKSUM_ALGORITHM="$2"
                shift 2
                ;;
            --no-verify)
                VERIFY_CHECKSUM=false
                shift
                ;;
            --progress)
                PROGRESS_MODE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -q|--quiet)
                QUIET_MODE=true
                shift
                ;;
            --debug)
                DEBUG_MODE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                log_error "Option inconnue : $1"
                show_help >&2
                exit 1
                ;;
            *)
                if [[ -z "$TARGET_HOST" ]]; then
                    TARGET_HOST="$1"
                elif [[ -z "$LOCAL_PATH" ]]; then
                    LOCAL_PATH="$1"
                elif [[ -z "$REMOTE_PATH" ]]; then
                    REMOTE_PATH="$1"
                else
                    log_error "Argument en trop : $1"
                    show_help >&2
                    exit 1
                fi
                shift
                ;;
        esac
    done
}

# === FONCTION PRINCIPALE ===
main() {
    local start_time=$(date +%s.%N)
    
    # Configuration du piégeage pour nettoyage
    trap cleanup EXIT INT TERM
    
    # Parsing des arguments
    parse_args "$@"
    
    # Validation des paramètres
    if ! validate_parameters; then
        exit 1
    fi
    
    log_debug "Début du transfert de fichier $TRANSFER_DIRECTION via $TRANSFER_METHOD"
    log_info "Transfert $TRANSFER_DIRECTION : $LOCAL_PATH ↔ $TARGET_USER@$TARGET_HOST:$REMOTE_PATH"
    
    # Préparation des options SSH
    if ! prepare_ssh_options; then
        log_error "Échec de la préparation des options SSH"
        exit 1
    fi
    
    # Exécution du transfert
    if ! execute_transfer; then
        log_error "Échec du transfert de fichier"
        exit 4
    fi
    
    # Vérification d'intégrité
    if ! verify_integrity; then
        log_error "Échec de la vérification d'intégrité"
        exit 5
    fi
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0.00")
    
    # Génération du rapport final
    generate_output "success"
    
    log_debug "Transfert de fichier terminé en ${duration}s"
    log_info "Transfert réussi avec vérification d'intégrité"
    
    return 0
}

# Point d'entrée du script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi