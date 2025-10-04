#!/bin/bash
#
# Script: list-user.all.sh
# Description: Liste tous les utilisateurs système avec leurs informations (username, UID, GID, home, shell)
# Usage: list-user.all.sh [OPTIONS]
#
# Options:
#   -h, --help              Affiche cette aide
#   -v, --verbose           Mode verbeux
#   -d, --debug             Mode debug
#   -j, --json-only         Sortie JSON uniquement (pas de logs)
#   -H, --human-only        Afficher uniquement les utilisateurs humains (UID >= 1000)
#
# Exit codes:
#   0 - Succès
#   1 - Erreur générale
#   2 - Erreur d'utilisation
#   4 - Ressource non trouvée
#
# Examples:
#   ./list-user.all.sh
#   ./list-user.all.sh --human-only
#   ./list-user.all.sh --json-only
#

# Configuration stricte
set -euo pipefail

# Codes de sortie
EXIT_SUCCESS=0
EXIT_ERROR_GENERAL=1
EXIT_ERROR_USAGE=2
EXIT_ERROR_NOT_FOUND=4

# Variables globales
VERBOSE=0
DEBUG=0
JSON_ONLY=0
HUMAN_ONLY=0

# Fonctions de logging minimal
log_info() { 
    [[ $JSON_ONLY -eq 0 ]] && echo "[INFO] $*" >&2 || true
}

log_error() { 
    echo "[ERROR] $*" >&2
}

log_debug() { 
    [[ $DEBUG -eq 1 && $JSON_ONLY -eq 0 ]] && echo "[DEBUG] $*" >&2 || true
}

# Fonction d'aide
show_help() {
    sed -n '/^# Script:/,/^$/p' "$0" | sed 's/^# \?//'
    exit 0
}

# Parsing des arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -d|--debug)
                DEBUG=1
                shift
                ;;
            -j|--json-only)
                JSON_ONLY=1
                shift
                ;;
            -H|--human-only)
                HUMAN_ONLY=1
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                exit $EXIT_ERROR_USAGE
                ;;
            *)
                log_error "Unexpected argument: $1"
                exit $EXIT_ERROR_USAGE
                ;;
        esac
    done
}

# Validation des prérequis
validate_prerequisites() {
    log_debug "Validating prerequisites"
    
    # Vérification de l'existence du fichier /etc/passwd
    if [[ ! -f "/etc/passwd" ]]; then
        log_error "/etc/passwd not found"
        exit $EXIT_ERROR_NOT_FOUND
    fi
    
    # Vérification de la lisibilité du fichier
    if [[ ! -r "/etc/passwd" ]]; then
        log_error "/etc/passwd is not readable"
        exit $EXIT_ERROR_NOT_FOUND
    fi
    
    log_debug "Prerequisites validated"
}

# Fonction pour parser une ligne de /etc/passwd
parse_passwd_line() {
    local line="$1"
    local username=$(echo "$line" | cut -d':' -f1)
    local uid=$(echo "$line" | cut -d':' -f3)
    local gid=$(echo "$line" | cut -d':' -f4)
    local gecos=$(echo "$line" | cut -d':' -f5)
    local home=$(echo "$line" | cut -d':' -f6)
    local shell=$(echo "$line" | cut -d':' -f7)
    
    # Si mode human-only, filtrer les UID < 1000 (sauf root)
    if [[ $HUMAN_ONLY -eq 1 ]]; then
        if [[ $uid -lt 1000 && $uid -ne 0 ]]; then
            return 1
        fi
    fi
    
    # Déterminer le type d'utilisateur
    local user_type="system"
    if [[ $uid -eq 0 ]]; then
        user_type="root"
    elif [[ $uid -ge 1000 ]]; then
        user_type="human"
    fi
    
    # Nettoyer le champ GECOS (enlever les virgules et descriptions)
    local real_name=$(echo "$gecos" | cut -d',' -f1)
    [[ -z "$real_name" ]] && real_name="$username"
    
    # Déterminer si l'utilisateur peut se connecter
    local can_login="false"
    if [[ "$shell" != "/usr/sbin/nologin" && "$shell" != "/bin/false" && "$shell" != "/sbin/nologin" ]]; then
        can_login="true"
    fi
    
    # Construction du JSON pour cet utilisateur
    cat <<EOF
{
  "username": "$username",
  "uid": $uid,
  "gid": $gid,
  "real_name": "$real_name",
  "home_directory": "$home",
  "shell": "$shell",
  "user_type": "$user_type",
  "can_login": $can_login
}
EOF
}

# Fonction principale métier
do_main_action() {
    log_info "Reading user information from /etc/passwd"
    
    local user_count=0
    local users_json=""
    local first_user=true
    
    # Lecture ligne par ligne du fichier /etc/passwd
    while IFS= read -r line; do
        # Ignorer les lignes vides ou qui commencent par #
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Parser la ligne et récupérer le JSON de l'utilisateur
        if user_json=$(parse_passwd_line "$line"); then
            # Ajouter une virgule avant chaque utilisateur sauf le premier
            if [[ $first_user == true ]]; then
                users_json="$user_json"
                first_user=false
            else
                users_json="$users_json,$user_json"
            fi
            ((user_count++))
        fi
    done < /etc/passwd
    
    log_info "Found $user_count users"
    
    # Construction du JSON de données
    cat <<EOF
{
  "users": [
    $users_json
  ],
  "count": $user_count,
  "source": "/etc/passwd",
  "filter": "$([ $HUMAN_ONLY -eq 1 ] && echo "human_only" || echo "all")",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
}

# Construction de la sortie JSON finale
build_json_output() {
    local status=$1
    local code=$2
    local message=$3
    local data=$4
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    cat <<EOF
{
  "status": "$status",
  "code": $code,
  "timestamp": "$timestamp",
  "script": "$(basename "$0")",
  "message": "$message",
  "data": $data,
  "errors": [],
  "warnings": []
}
EOF
}

# Point d'entrée principal
main() {
    # Redirection pour séparer logs et résultat JSON si pas en mode JSON-only
    if [[ $JSON_ONLY -eq 0 ]]; then
        exec 3>&1
        exec 1>&2
    fi
    
    log_info "Script started: $(basename "$0")"
    
    # Parse arguments
    parse_args "$@"
    
    # Validation
    validate_prerequisites
    
    # Exécution
    local users_data
    users_data=$(do_main_action)
    
    # Construction du JSON de sortie
    local json_output
    json_output=$(build_json_output "success" $EXIT_SUCCESS "User list retrieved successfully" "$users_data")
    
    # Sortie du résultat
    if [[ $JSON_ONLY -eq 0 ]]; then
        echo "$json_output" >&3
        log_info "Script completed successfully"
    else
        echo "$json_output"
    fi
    
    exit $EXIT_SUCCESS
}

# Exécution
main "$@"