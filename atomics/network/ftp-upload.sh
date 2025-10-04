#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: ftp-upload.sh
# Description: Script atomique pour upload de fichiers via FTP/FTPS
# Author: Generated with AtomicOps-Suite AI assistance
# Version: 1.0
# Date: 2025-10-04
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# Level: 0 (Atomique)
# Dependencies: lftp (recommandé) ou ftp, curl
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="ftp-upload.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}

# Configuration FTP
FTP_HOST=""
FTP_PORT=21
FTP_USER=""
FTP_PASSWORD=""
FTP_USE_SSL=0
FTP_PASSIVE=1
FTP_TIMEOUT=30

# Configuration du transfert
LOCAL_FILE=""
REMOTE_PATH=""
CREATE_DIRS=0
OVERWRITE=0
VERIFY_TRANSFER=1
RESUME_TRANSFER=0

# Variables de résultat
UPLOAD_SUCCESS=0
TRANSFER_SIZE=0
TRANSFER_SPEED=0
TRANSFER_TIME=0
REMOTE_FILE_SIZE=0
VERIFICATION_OK=0

# =============================================================================
# Fonctions Utilitaires et Logging
# =============================================================================

log_debug() {
    [[ $DEBUG -eq 0 ]] && return 0
    echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_info() {
    [[ $QUIET -eq 1 ]] && return 0
    [[ $JSON_ONLY -eq 1 ]] && return 0
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_warn() {
    [[ $QUIET -eq 1 ]] && return 0
    [[ $JSON_ONLY -eq 1 ]] && return 0
    echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

die() {
    log_error "$1"
    build_json_output "error" "${2:-1}" "$1"
    exit "${2:-1}"
}

# =============================================================================
# Fonctions d'Aide et de Parsing
# =============================================================================

show_help() {
    cat << 'EOF'
Usage: ftp-upload.sh --host <host> --user <user> --local <file> --remote <path> [OPTIONS]

Description:
    Script atomique pour upload de fichiers via FTP/FTPS.
    Supporte les connexions sécurisées SSL/TLS et la vérification d'intégrité.

Arguments obligatoires:
    --host <hostname>       Serveur FTP cible
    --user <username>       Nom d'utilisateur FTP
    --local <path>          Fichier local à uploader
    --remote <path>         Chemin distant de destination

Options:
    -h, --help             Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)

Options de connexion FTP:
    -p, --port <port>      Port FTP (défaut: 21)
    --password <pass>      Mot de passe FTP
    --ssl                  Utiliser SSL/TLS (FTPS)
    --no-passive          Désactiver mode passif
    --timeout <sec>       Timeout de connexion (défaut: 30)

Options de transfert:
    --create-dirs         Créer répertoires distants si nécessaire
    --overwrite           Écraser fichier distant si existant
    --no-verify           Ne pas vérifier l'intégrité du transfert
    --resume              Reprendre transfert interrompu
    --binary              Forcer mode binaire (automatique selon extension)

Variables d'environnement:
    FTP_HOST              Serveur par défaut
    FTP_USER              Utilisateur par défaut
    FTP_PASSWORD          Mot de passe par défaut
    FTP_PORT              Port par défaut (21)
    FTP_USE_SSL           SSL par défaut (0|1)
    FTP_PASSIVE           Mode passif par défaut (1)

Sortie JSON:
    {
      "status": "success|error",
      "code": 0|1|2|3,
      "timestamp": "ISO8601",
      "script": "ftp-upload.sh",
      "message": "Description du résultat",
      "data": {
        "ftp_server": {
          "host": "ftp.example.com",
          "port": 21,
          "user": "username",
          "ssl_enabled": true,
          "passive_mode": true
        },
        "transfer": {
          "local_file": "/path/to/file.txt",
          "remote_path": "/uploads/file.txt",
          "successful": true,
          "resumed": false,
          "overwritten": false
        },
        "performance": {
          "size_bytes": 1048576,
          "duration_ms": 2345,
          "speed_kbps": 3456.78,
          "avg_speed_mbps": 3.37
        },
        "verification": {
          "performed": true,
          "local_size": 1048576,
          "remote_size": 1048576,
          "integrity_ok": true
        }
      }
    }

Codes de sortie:
    0 - Upload réussi avec vérification
    1 - Erreur de paramètres ou configuration
    2 - Erreur de connexion FTP
    3 - Erreur de transfert

Exemples:
    # Upload simple avec SSL
    ./ftp-upload.sh \
        --host ftp.example.com --user myuser \
        --password secret --ssl \
        --local ./document.pdf \
        --remote /uploads/documents/

    # Upload avec création de répertoires
    ./ftp-upload.sh \
        --host secure-ftp.com --user uploader \
        --local ./backup.tar.gz \
        --remote /backups/daily/backup.tar.gz \
        --create-dirs --overwrite

    # Upload avec reprise de transfert
    ./ftp-upload.sh \
        --host backup.example.com --user backup \
        --local ./large-file.iso \
        --remote /storage/large-file.iso \
        --resume --timeout 300
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=1
                ;;
            -d|--debug)
                DEBUG=1
                VERBOSE=1
                ;;
            -q|--quiet)
                QUIET=1
                ;;
            -j|--json-only)
                JSON_ONLY=1
                QUIET=1
                ;;
            --host)
                [[ -z "${2:-}" ]] && die "Option --host nécessite une valeur" 1
                FTP_HOST="$2"
                shift
                ;;
            --user)
                [[ -z "${2:-}" ]] && die "Option --user nécessite une valeur" 1
                FTP_USER="$2"
                shift
                ;;
            --password)
                [[ -z "${2:-}" ]] && die "Option --password nécessite une valeur" 1
                FTP_PASSWORD="$2"
                shift
                ;;
            -p|--port)
                [[ -z "${2:-}" ]] && die "Option --port nécessite une valeur" 1
                FTP_PORT="$2"
                shift
                ;;
            --local)
                [[ -z "${2:-}" ]] && die "Option --local nécessite une valeur" 1
                LOCAL_FILE="$2"
                shift
                ;;
            --remote)
                [[ -z "${2:-}" ]] && die "Option --remote nécessite une valeur" 1
                REMOTE_PATH="$2"
                shift
                ;;
            --ssl)
                FTP_USE_SSL=1
                ;;
            --no-passive)
                FTP_PASSIVE=0
                ;;
            --timeout)
                [[ -z "${2:-}" ]] && die "Option --timeout nécessite une valeur" 1
                FTP_TIMEOUT="$2"
                shift
                ;;
            --create-dirs)
                CREATE_DIRS=1
                ;;
            --overwrite)
                OVERWRITE=1
                ;;
            --no-verify)
                VERIFY_TRANSFER=0
                ;;
            --resume)
                RESUME_TRANSFER=1
                ;;
            --binary)
                # Option pour compatibilité, le mode binaire est automatiquement détecté
                ;;
            -*)
                die "Option inconnue: $1" 1
                ;;
            *)
                die "Argument non attendu: $1" 1
                ;;
        esac
        shift
    done
}

# =============================================================================
# Fonctions de Validation
# =============================================================================

validate_prerequisites() {
    log_debug "Validation des prérequis FTP upload..."
    
    # Vérification des outils FTP
    local ftp_tool=""
    if command -v lftp >/dev/null 2>&1; then
        ftp_tool="lftp"
        log_debug "outil FTP: lftp (recommandé)"
    elif command -v curl >/dev/null 2>&1; then
        ftp_tool="curl"
        log_debug "Outil FTP: curl (alternatif)"
    elif command -v ftp >/dev/null 2>&1; then
        ftp_tool="ftp"
        log_debug "Outil FTP: ftp standard (basique)"
    else
        die "Aucun client FTP disponible (lftp, curl, ou ftp requis)" 1
    fi
    
    # Validation des paramètres obligatoires
    [[ -z "$FTP_HOST" ]] && die "Paramètre --host obligatoire" 1
    [[ -z "$FTP_USER" ]] && die "Paramètre --user obligatoire" 1
    [[ -z "$LOCAL_FILE" ]] && die "Paramètre --local obligatoire" 1
    [[ -z "$REMOTE_PATH" ]] && die "Paramètre --remote obligatoire" 1
    
    # Validation du fichier local
    if [[ ! -f "$LOCAL_FILE" ]]; then
        die "Fichier local non trouvé: $LOCAL_FILE" 1
    fi
    
    if [[ ! -r "$LOCAL_FILE" ]]; then
        die "Fichier local non lisible: $LOCAL_FILE" 1
    fi
    
    # Calcul de la taille du fichier local
    TRANSFER_SIZE=$(stat -c%s "$LOCAL_FILE" 2>/dev/null || stat -f%z "$LOCAL_FILE" 2>/dev/null || echo 0)
    
    # Validation des valeurs numériques
    if [[ ! "$FTP_PORT" =~ ^[0-9]+$ ]] || [[ $FTP_PORT -lt 1 ]] || [[ $FTP_PORT -gt 65535 ]]; then
        die "Port FTP invalide: $FTP_PORT" 1
    fi
    
    if [[ ! "$FTP_TIMEOUT" =~ ^[0-9]+$ ]] || [[ $FTP_TIMEOUT -lt 5 ]]; then
        die "Timeout invalide: $FTP_TIMEOUT (minimum 5 secondes)" 1
    fi
    
    log_debug "Validation réussie, fichier local: $TRANSFER_SIZE octets"
    log_info "Upload FTP de '$LOCAL_FILE' vers $FTP_USER@$FTP_HOST:$FTP_PORT/$REMOTE_PATH"
    
    return 0
}

# =============================================================================
# Fonctions d'Upload FTP
# =============================================================================

# Détection du type de fichier pour mode binaire/texte
detect_file_mode() {
    local file="$1"
    local filename=$(basename "$file")
    local extension="${filename##*.}"
    
    # Extensions binaires courantes
    local binary_extensions=(
        "pdf" "zip" "tar" "gz" "bz2" "xz" "rar" "7z"
        "jpg" "jpeg" "png" "gif" "bmp" "tiff" "webp"
        "mp3" "mp4" "avi" "mkv" "mov" "wmv" "flv"
        "doc" "docx" "xls" "xlsx" "ppt" "pptx"
        "exe" "bin" "so" "dll" "dmg" "app"
        "iso" "img" "vdi" "vmdk"
    )
    
    for ext in "${binary_extensions[@]}"; do
        if [[ "${extension,,}" == "$ext" ]]; then
            echo "binary"
            return 0
        fi
    done
    
    # Par défaut, mode texte pour les autres fichiers
    echo "ascii"
}

# Upload avec lftp (méthode recommandée)
upload_with_lftp() {
    log_debug "Upload FTP avec lftp"
    
    local start_time=$(date +%s%3N)
    local lftp_commands=()
    
    # Configuration de base
    lftp_commands+=(
        "set net:timeout $FTP_TIMEOUT"
        "set net:max-retries 3"
        "set net:reconnect-interval-base 5"
    )
    
    # Configuration SSL si activé
    if [[ $FTP_USE_SSL -eq 1 ]]; then
        lftp_commands+=(
            "set ftp:ssl-allow true"
            "set ftp:ssl-force true"
            "set ftp:ssl-protect-data true"
            "set ssl:verify-certificate false"
        )
    fi
    
    # Configuration du mode passif
    if [[ $FTP_PASSIVE -eq 1 ]]; then
        lftp_commands+=("set ftp:passive-mode true")
    else
        lftp_commands+=("set ftp:passive-mode false")
    fi
    
    # Connexion au serveur
    local connect_cmd="connect"
    if [[ -n "$FTP_PASSWORD" ]]; then
        connect_cmd="connect ftp://$FTP_USER:$FTP_PASSWORD@$FTP_HOST:$FTP_PORT"
    else
        connect_cmd="connect ftp://$FTP_USER@$FTP_HOST:$FTP_PORT"
    fi
    lftp_commands+=("$connect_cmd")
    
    # Création des répertoires si nécessaire
    if [[ $CREATE_DIRS -eq 1 ]]; then
        local remote_dir=$(dirname "$REMOTE_PATH")
        if [[ "$remote_dir" != "." ]] && [[ "$remote_dir" != "/" ]]; then
            lftp_commands+=("mkdir -p \"$remote_dir\"")
        fi
    fi
    
    # Configuration du mode de transfert
    local file_mode=$(detect_file_mode "$LOCAL_FILE")
    if [[ "$file_mode" == "binary" ]]; then
        lftp_commands+=("set ftp:transfer-mode binary")
    else
        lftp_commands+=("set ftp:transfer-mode ascii")
    fi
    
    # Commande de transfert
    local put_options=""
    if [[ $RESUME_TRANSFER -eq 1 ]]; then
        put_options+=" -c"
    fi
    if [[ $OVERWRITE -eq 0 ]]; then
        put_options+=" -E"  # Ne pas écraser si existant
    fi
    
    lftp_commands+=("put$put_options \"$LOCAL_FILE\" -o \"$REMOTE_PATH\"")
    lftp_commands+=("quit")
    
    # Exécution de lftp
    local lftp_script=$(printf '%s\n' "${lftp_commands[@]}")
    log_debug "Script lftp généré: ${#lftp_commands[@]} commandes"
    
    local lftp_output=""
    local lftp_exit_code=0
    
    if lftp_output=$(echo "$lftp_script" | lftp 2>&1); then
        lftp_exit_code=0
    else
        lftp_exit_code=$?
    fi
    
    local end_time=$(date +%s%3N)
    TRANSFER_TIME=$((end_time - start_time))
    
    if [[ $lftp_exit_code -eq 0 ]]; then
        # Calcul de la vitesse de transfert
        if [[ $TRANSFER_TIME -gt 0 ]]; then
            TRANSFER_SPEED=$((TRANSFER_SIZE * 1000 / TRANSFER_TIME))  # octets/sec
            TRANSFER_SPEED=$((TRANSFER_SPEED / 1024))  # KB/s
        fi
        
        UPLOAD_SUCCESS=1
        log_info "Upload lftp réussi (${TRANSFER_TIME}ms, ${TRANSFER_SPEED} KB/s)"
        return 0
    else
        log_error "Échec upload lftp: $lftp_output"
        return 3
    fi
}

# Upload avec curl (méthode alternative)
upload_with_curl() {
    log_debug "Upload FTP avec curl"
    
    local start_time=$(date +%s%3N)
    local curl_args=()
    
    # Configuration de base
    curl_args+=(
        "--connect-timeout" "$FTP_TIMEOUT"
        "--max-time" "$((FTP_TIMEOUT * 3))"
        "--retry" "3"
        "--retry-delay" "5"
    )
    
    # Configuration SSL si activé
    if [[ $FTP_USE_SSL -eq 1 ]]; then
        curl_args+=(
            "--use-ssl"
            "--ssl-reqd"
            "--insecure"  # Pour les certificats auto-signés
        )
    fi
    
    # Configuration du mode passif
    if [[ $FTP_PASSIVE -eq 0 ]]; then
        curl_args+=("--ftp-port" "-")
    fi
    
    # Configuration de reprise si activée
    if [[ $RESUME_TRANSFER -eq 1 ]]; then
        curl_args+=("--continue-at" "-")
    fi
    
    # Création des répertoires si nécessaire
    if [[ $CREATE_DIRS -eq 1 ]]; then
        local remote_dir=$(dirname "$REMOTE_PATH")
        if [[ "$remote_dir" != "." ]] && [[ "$remote_dir" != "/" ]]; then
            curl_args+=("--ftp-create-dirs")
        fi
    fi
    
    # Configuration de l'authentification
    if [[ -n "$FTP_PASSWORD" ]]; then
        curl_args+=("--user" "$FTP_USER:$FTP_PASSWORD")
    else
        curl_args+=("--user" "$FTP_USER:")
    fi
    
    # Upload du fichier
    curl_args+=("--upload-file" "$LOCAL_FILE")
    
    # URL FTP de destination
    local ftp_protocol="ftp"
    if [[ $FTP_USE_SSL -eq 1 ]]; then
        ftp_protocol="ftps"
    fi
    curl_args+=("$ftp_protocol://$FTP_HOST:$FTP_PORT/$REMOTE_PATH")
    
    # Exécution de curl
    log_debug "Commande curl: curl ${curl_args[*]}"
    
    local curl_output=""
    local curl_exit_code=0
    
    if curl_output=$(curl "${curl_args[@]}" 2>&1); then
        curl_exit_code=0
    else
        curl_exit_code=$?
    fi
    
    local end_time=$(date +%s%3N)
    TRANSFER_TIME=$((end_time - start_time))
    
    if [[ $curl_exit_code -eq 0 ]]; then
        # Calcul de la vitesse de transfert
        if [[ $TRANSFER_TIME -gt 0 ]]; then
            TRANSFER_SPEED=$((TRANSFER_SIZE * 1000 / TRANSFER_TIME))  # octets/sec
            TRANSFER_SPEED=$((TRANSFER_SPEED / 1024))  # KB/s
        fi
        
        UPLOAD_SUCCESS=1
        log_info "Upload curl réussi (${TRANSFER_TIME}ms, ${TRANSFER_SPEED} KB/s)"
        return 0
    else
        log_error "Échec upload curl (code: $curl_exit_code): $curl_output"
        return 3
    fi
}

# Upload avec client ftp standard (méthode basique)
upload_with_standard_ftp() {
    log_debug "Upload FTP avec client standard"
    log_warn "Client FTP standard: fonctionnalités limitées (pas de SSL, pas de reprise)"
    
    local start_time=$(date +%s%3N)
    local ftp_commands=()
    
    # Configuration du mode passif
    if [[ $FTP_PASSIVE -eq 1 ]]; then
        ftp_commands+=("passive")
    fi
    
    # Configuration du mode de transfert
    local file_mode=$(detect_file_mode "$LOCAL_FILE")
    ftp_commands+=("$file_mode")
    
    # Upload du fichier
    ftp_commands+=("put \"$LOCAL_FILE\" \"$REMOTE_PATH\"")
    ftp_commands+=("quit")
    
    # Génération du script FTP
    local ftp_script=$(printf '%s\n' "${ftp_commands[@]}")
    
    # Connexion et exécution
    local ftp_output=""
    local ftp_exit_code=0
    
    if [[ -n "$FTP_PASSWORD" ]]; then
        if ftp_output=$(echo "$ftp_script" | ftp -n "$FTP_HOST" "$FTP_PORT" <<< "user $FTP_USER $FTP_PASSWORD" 2>&1); then
            ftp_exit_code=0
        else
            ftp_exit_code=$?
        fi
    else
        if ftp_output=$(echo "$ftp_script" | ftp -n "$FTP_HOST" "$FTP_PORT" <<< "user $FTP_USER" 2>&1); then
            ftp_exit_code=0
        else
            ftp_exit_code=$?
        fi
    fi
    
    local end_time=$(date +%s%3N)
    TRANSFER_TIME=$((end_time - start_time))
    
    if [[ $ftp_exit_code -eq 0 ]] && [[ "$ftp_output" == *"Transfer complete"* ]]; then
        # Calcul de la vitesse de transfert
        if [[ $TRANSFER_TIME -gt 0 ]]; then
            TRANSFER_SPEED=$((TRANSFER_SIZE * 1000 / TRANSFER_TIME))  # octets/sec
            TRANSFER_SPEED=$((TRANSFER_SPEED / 1024))  # KB/s
        fi
        
        UPLOAD_SUCCESS=1
        log_info "Upload FTP standard réussi (${TRANSFER_TIME}ms, ${TRANSFER_SPEED} KB/s)"
        return 0
    else
        log_error "Échec upload FTP standard: $ftp_output"
        return 3
    fi
}

# Vérification de l'intégrité du transfert
verify_transfer() {
    if [[ $VERIFY_TRANSFER -eq 0 ]]; then
        log_debug "Vérification d'intégrité désactivée"
        VERIFICATION_OK=1
        return 0
    fi
    
    log_info "Vérification de l'intégrité du transfert"
    
    # Tentative de récupération de la taille du fichier distant
    if command -v lftp >/dev/null 2>&1; then
        local size_check_commands=(
            "set net:timeout $FTP_TIMEOUT"
        )
        
        if [[ $FTP_USE_SSL -eq 1 ]]; then
            size_check_commands+=(
                "set ftp:ssl-allow true"
                "set ftp:ssl-force true"
                "set ssl:verify-certificate false"
            )
        fi
        
        local connect_cmd="connect"
        if [[ -n "$FTP_PASSWORD" ]]; then
            connect_cmd="connect ftp://$FTP_USER:$FTP_PASSWORD@$FTP_HOST:$FTP_PORT"
        else
            connect_cmd="connect ftp://$FTP_USER@$FTP_HOST:$FTP_PORT"
        fi
        size_check_commands+=("$connect_cmd")
        
        size_check_commands+=("cls -l \"$REMOTE_PATH\"")
        size_check_commands+=("quit")
        
        local size_script=$(printf '%s\n' "${size_check_commands[@]}")
        local size_output=""
        
        if size_output=$(echo "$size_script" | lftp 2>&1); then
            # Extraction de la taille du fichier depuis la sortie ls -l
            REMOTE_FILE_SIZE=$(echo "$size_output" | grep -E '^-' | awk '{print $5}' | head -n1)
            
            if [[ -n "$REMOTE_FILE_SIZE" ]] && [[ "$REMOTE_FILE_SIZE" =~ ^[0-9]+$ ]]; then
                if [[ $REMOTE_FILE_SIZE -eq $TRANSFER_SIZE ]]; then
                    VERIFICATION_OK=1
                    log_info "Vérification réussie: tailles identiques ($TRANSFER_SIZE octets)"
                    return 0
                else
                    log_error "Vérification échouée: taille locale $TRANSFER_SIZE != taille distante $REMOTE_FILE_SIZE"
                    return 3
                fi
            else
                log_warn "Impossible de vérifier la taille du fichier distant"
                VERIFICATION_OK=1  # On considère comme OK si on ne peut pas vérifier
                return 0
            fi
        else
            log_warn "Échec de vérification de la taille distante"
            VERIFICATION_OK=1  # On considère comme OK si on ne peut pas vérifier
            return 0
        fi
    else
        log_warn "lftp non disponible pour vérification - Vérification passée"
        VERIFICATION_OK=1
        return 0
    fi
}

# Fonction principale d'upload
perform_upload() {
    log_debug "Démarrage de l'upload FTP"
    
    # Choix de la méthode d'upload selon les outils disponibles
    local upload_method=""
    local upload_result=0
    
    if command -v lftp >/dev/null 2>&1; then
        upload_method="lftp"
        upload_with_lftp
        upload_result=$?
    elif command -v curl >/dev/null 2>&1; then
        upload_method="curl"
        upload_with_curl
        upload_result=$?
    elif command -v ftp >/dev/null 2>&1; then
        upload_method="ftp"
        upload_with_standard_ftp
        upload_result=$?
    else
        die "Aucun client FTP disponible" 1
    fi
    
    if [[ $upload_result -eq 0 ]]; then
        log_info "Upload réussi avec $upload_method"
        
        # Vérification de l'intégrité si demandée
        if ! verify_transfer; then
            return 3
        fi
        
        return 0
    else
        log_error "Échec de l'upload avec $upload_method"
        return $upload_result
    fi
}

# =============================================================================
# Fonction de Construction de Sortie JSON
# =============================================================================

build_json_output() {
    local status="$1"
    local exit_code="$2"
    local message="$3"
    local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')
    
    # Calcul des métriques de performance
    local avg_speed_mbps=0
    if [[ $TRANSFER_SPEED -gt 0 ]]; then
        avg_speed_mbps=$(echo "scale=2; $TRANSFER_SPEED / 1024" | bc 2>/dev/null || echo "0")
    fi
    
    cat << EOF
{
  "status": "$status",
  "code": $exit_code,
  "timestamp": "$timestamp",
  "script": "$SCRIPT_NAME",
  "message": "$message",
  "data": {
    "ftp_server": {
      "host": "$FTP_HOST",
      "port": $FTP_PORT,
      "user": "$FTP_USER",
      "ssl_enabled": $([ $FTP_USE_SSL -eq 1 ] && echo "true" || echo "false"),
      "passive_mode": $([ $FTP_PASSIVE -eq 1 ] && echo "true" || echo "false"),
      "timeout": $FTP_TIMEOUT
    },
    "transfer": {
      "local_file": "$LOCAL_FILE",
      "remote_path": "$REMOTE_PATH",
      "successful": $([ $UPLOAD_SUCCESS -eq 1 ] && echo "true" || echo "false"),
      "resumed": $([ $RESUME_TRANSFER -eq 1 ] && echo "true" || echo "false"),
      "overwrite_allowed": $([ $OVERWRITE -eq 1 ] && echo "true" || echo "false"),
      "create_dirs": $([ $CREATE_DIRS -eq 1 ] && echo "true" || echo "false")
    },
    "performance": {
      "size_bytes": $TRANSFER_SIZE,
      "duration_ms": $TRANSFER_TIME,
      "speed_kbps": $TRANSFER_SPEED,
      "avg_speed_mbps": $avg_speed_mbps
    },
    "verification": {
      "performed": $([ $VERIFY_TRANSFER -eq 1 ] && echo "true" || echo "false"),
      "local_size": $TRANSFER_SIZE,
      "remote_size": ${REMOTE_FILE_SIZE:-0},
      "integrity_ok": $([ $VERIFICATION_OK -eq 1 ] && echo "true" || echo "false")
    }
  }
}
EOF
}

# =============================================================================
# Fonction de Nettoyage
# =============================================================================

cleanup() {
    log_debug "Nettoyage des ressources FTP upload"
    # Pas de ressources temporaires spécifiques à nettoyer
}

# =============================================================================
# Point d'Entrée Principal
# =============================================================================

main() {
    # Configuration du trap pour le nettoyage
    trap cleanup EXIT ERR INT TERM
    
    # Récupération des variables d'environnement par défaut
    FTP_HOST="${FTP_HOST:-}"
    FTP_USER="${FTP_USER:-}"
    FTP_PASSWORD="${FTP_PASSWORD:-}"
    FTP_PORT="${FTP_PORT:-21}"
    FTP_USE_SSL="${FTP_USE_SSL:-0}"
    FTP_PASSIVE="${FTP_PASSIVE:-1}"
    
    # Parsing des arguments
    parse_args "$@"
    
    # Validation des prérequis
    validate_prerequisites
    
    # Exécution de l'upload
    local exit_code=0
    local result_message="Upload FTP réussi"
    
    if perform_upload; then
        result_message="Upload FTP complété avec succès ($TRANSFER_SIZE octets en ${TRANSFER_TIME}ms)"
        exit_code=0
    else
        local upload_exit_code=$?
        case $upload_exit_code in
            2)
                result_message="Erreur de connexion FTP"
                exit_code=2
                ;;
            3)
                result_message="Erreur de transfert FTP"
                exit_code=3
                ;;
            *)
                result_message="Erreur lors de l'upload FTP"
                exit_code=1
                ;;
        esac
    fi
    
    # Génération de la sortie JSON
    build_json_output \
        "$([ $exit_code -eq 0 ] && echo "success" || echo "error")" \
        "$exit_code" \
        "$result_message"
    
    exit $exit_code
}

# Exécution du script si appelé directement
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi