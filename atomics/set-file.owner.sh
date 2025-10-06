#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: set-file.owner.sh
# Description: Modifier le propriétaire (user:group) d'un fichier ou répertoire
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-06
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="set-file.owner.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
TARGET_PATH=""
NEW_OWNER=""
RECURSIVE=${RECURSIVE:-0}
PRESERVE_ROOT=${PRESERVE_ROOT:-1}

# =============================================================================
# Fonctions Utilitaires et Logging
# =============================================================================

log_debug() {
    [[ $DEBUG -eq 0 ]] && return 0
    echo "[DEBUG] $*" >&2
}

log_info() {
    [[ $QUIET -eq 1 ]] && return 0
    [[ $JSON_ONLY -eq 1 ]] && return 0
    echo "[INFO] $*" >&2
}

log_warn() {
    [[ $QUIET -eq 1 ]] && return 0
    [[ $JSON_ONLY -eq 1 ]] && return 0
    echo "[WARN] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

die() {
    log_error "$1"
    exit "${2:-1}"
}

# =============================================================================
# Fonctions d'Aide et de Parsing
# =============================================================================

show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] <path> <owner[:group]>

Description:
    Modifie le propriétaire et/ou le groupe d'un fichier ou répertoire.
    Équivalent sécurisé de la commande chown avec validations et reporting.

Arguments:
    <path>                  Chemin du fichier ou répertoire (obligatoire)
    <owner[:group]>         Nouveau propriétaire (ex: user, user:group, :group)

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)
    -r, --recursive        Appliquer récursivement aux sous-répertoires
    --no-preserve-root     Autoriser les modifications sur / (dangereux)
    
Formats d'owner acceptés:
    user                   Changer seulement le propriétaire
    user:group             Changer propriétaire et groupe
    :group                 Changer seulement le groupe
    1000                   Utiliser l'UID numérique
    1000:1000              Utiliser UID:GID numériques
    
Sortie JSON:
    {
      "status": "success|error",
      "code": 0,
      "timestamp": "ISO8601",
      "script": "$SCRIPT_NAME",
      "message": "Description",
      "data": {
        "path": "/path/to/file",
        "requested_owner": "user:group",
        "previous_owner": {
          "user": "olduser",
          "group": "oldgroup",
          "uid": 1001,
          "gid": 1001
        },
        "current_owner": {
          "user": "newuser",
          "group": "newgroup", 
          "uid": 1000,
          "gid": 1000
        },
        "applied_recursive": false,
        "files_affected": 1
      },
      "errors": [],
      "warnings": []
    }

Codes de sortie:
    0  - Succès
    1  - Erreur générale
    2  - Paramètres invalides
    3  - Fichier/répertoire non trouvé
    4  - Permissions insuffisantes
    5  - Utilisateur/groupe non trouvé

Exemples:
    $SCRIPT_NAME /home/user/file.txt john
    $SCRIPT_NAME -r /var/www www-data:www-data
    $SCRIPT_NAME /tmp/file :staff

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
                shift
                ;;
            -d|--debug)
                DEBUG=1
                VERBOSE=1
                shift
                ;;
            -q|--quiet)
                QUIET=1
                shift
                ;;
            -j|--json-only)
                JSON_ONLY=1
                QUIET=1
                shift
                ;;
            -r|--recursive)
                RECURSIVE=1
                shift
                ;;
            --no-preserve-root)
                PRESERVE_ROOT=0
                shift
                ;;
            -*)
                die "Option inconnue: $1" 2
                ;;
            *)
                if [[ -z "$TARGET_PATH" ]]; then
                    TARGET_PATH="$1"
                elif [[ -z "$NEW_OWNER" ]]; then
                    NEW_OWNER="$1"
                else
                    die "Trop d'arguments positionnels" 2
                fi
                shift
                ;;
        esac
    done
    
    # Validation des arguments
    if [[ -z "$TARGET_PATH" ]]; then
        die "Chemin du fichier/répertoire manquant" 2
    fi
    
    if [[ -z "$NEW_OWNER" ]]; then
        die "Propriétaire manquant (format: user, user:group, ou :group)" 2
    fi
    
    if [[ ! -e "$TARGET_PATH" ]]; then
        die "Fichier ou répertoire non trouvé: $TARGET_PATH" 3
    fi
    
    # Protection contre les modifications dangereuses de /
    if [[ $PRESERVE_ROOT -eq 1 ]] && [[ "$TARGET_PATH" == "/" ]]; then
        die "Modification du propriétaire de / refusée (utilisez --no-preserve-root pour forcer)" 2
    fi
}

# =============================================================================
# Fonctions de Validation et Vérification
# =============================================================================

check_dependencies() {
    local missing_deps=()
    
    if ! command -v chown >/dev/null 2>&1; then
        missing_deps+=("chown")
    fi
    
    if ! command -v stat >/dev/null 2>&1; then
        missing_deps+=("stat")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        die "Dépendances manquantes: ${missing_deps[*]}" 1
    fi
}

validate_owner_format() {
    local owner="$1"
    
    # Formats valides:
    # user, :group, user:group, 1000, :1000, 1000:1000
    if [[ "$owner" =~ ^[a-zA-Z_][a-zA-Z0-9_-]*$ ]]; then
        return 0  # user seulement
    elif [[ "$owner" =~ ^[0-9]+$ ]]; then
        return 0  # uid seulement
    elif [[ "$owner" =~ ^:[a-zA-Z_][a-zA-Z0-9_-]*$ ]]; then
        return 0  # :group seulement
    elif [[ "$owner" =~ ^:[0-9]+$ ]]; then
        return 0  # :gid seulement
    elif [[ "$owner" =~ ^[a-zA-Z_][a-zA-Z0-9_-]*:[a-zA-Z_][a-zA-Z0-9_-]*$ ]]; then
        return 0  # user:group
    elif [[ "$owner" =~ ^[0-9]+:[0-9]+$ ]]; then
        return 0  # uid:gid
    elif [[ "$owner" =~ ^[a-zA-Z_][a-zA-Z0-9_-]*:[0-9]+$ ]]; then
        return 0  # user:gid
    elif [[ "$owner" =~ ^[0-9]+:[a-zA-Z_][a-zA-Z0-9_-]*$ ]]; then
        return 0  # uid:group
    fi
    
    return 1
}

check_user_exists() {
    local user="$1"
    
    # Vérifier si c'est un UID numérique
    if [[ "$user" =~ ^[0-9]+$ ]]; then
        # Vérifier si l'UID existe
        if id "$user" >/dev/null 2>&1; then
            return 0
        fi
        return 1
    fi
    
    # Vérifier si l'utilisateur existe par nom
    if id "$user" >/dev/null 2>&1; then
        return 0
    fi
    
    return 1
}

check_group_exists() {
    local group="$1"
    
    # Vérifier si c'est un GID numérique
    if [[ "$group" =~ ^[0-9]+$ ]]; then
        # Vérifier si le GID existe dans /etc/group
        if getent group "$group" >/dev/null 2>&1; then
            return 0
        fi
        return 1
    fi
    
    # Vérifier si le groupe existe par nom
    if getent group "$group" >/dev/null 2>&1; then
        return 0
    fi
    
    return 1
}

get_file_owner_info() {
    local path="$1"
    local stat_format
    
    # Format stat différent selon l'OS
    if stat -c "%U:%G:%u:%g" "$path" >/dev/null 2>&1; then
        # Linux
        stat_format="-c %U:%G:%u:%g"
    else
        # BSD/macOS - utiliser format différent
        stat_format="-f %Su:%Sg:%u:%g"
    fi
    
    stat $stat_format "$path" 2>/dev/null || echo "unknown:unknown:0:0"
}

count_affected_files() {
    local path="$1"
    local recursive="$2"
    
    if [[ -f "$path" ]]; then
        echo "1"
    elif [[ -d "$path" ]]; then
        if [[ $recursive -eq 1 ]]; then
            find "$path" -type f -o -type d | wc -l
        else
            echo "1"
        fi
    else
        echo "0"
    fi
}

# =============================================================================
# Fonction Principale de Modification du Propriétaire
# =============================================================================

set_file_owner() {
    local path="$1"
    local owner="$2"
    local errors=()
    local warnings=()
    
    log_debug "Modification du propriétaire pour: $path"
    log_debug "Nouveau propriétaire: $owner"
    
    # Valider le format du propriétaire
    if ! validate_owner_format "$owner"; then
        errors+=("Invalid owner format: $owner")
        handle_result "$path" "$owner" "${errors[@]}" "${warnings[@]}"
        return 2
    fi
    
    # Obtenir les informations actuelles du fichier
    local current_info previous_info
    previous_info=$(get_file_owner_info "$path")
    
    # Séparer user et group de la spécification
    local new_user new_group
    if [[ "$owner" =~ ^([^:]+):(.+)$ ]]; then
        new_user="${BASH_REMATCH[1]}"
        new_group="${BASH_REMATCH[2]}"
    elif [[ "$owner" =~ ^:(.+)$ ]]; then
        new_user=""
        new_group="${BASH_REMATCH[1]}"
    else
        new_user="$owner"
        new_group=""
    fi
    
    # Vérifier l'existence du user si spécifié
    if [[ -n "$new_user" ]] && ! check_user_exists "$new_user"; then
        errors+=("User does not exist: $new_user")
    fi
    
    # Vérifier l'existence du group si spécifié
    if [[ -n "$new_group" ]] && ! check_group_exists "$new_group"; then
        errors+=("Group does not exist: $new_group")
    fi
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        handle_result "$path" "$owner" "${errors[@]}" "${warnings[@]}"
        return 5
    fi
    
    # Compter les fichiers qui seront affectés
    local files_affected
    files_affected=$(count_affected_files "$path" "$RECURSIVE")
    
    log_info "Fichiers à modifier: $files_affected"
    
    # Construire et exécuter la commande chown
    local chown_cmd="chown"
    
    if [[ $RECURSIVE -eq 1 ]] && [[ -d "$path" ]]; then
        chown_cmd+=" --recursive"
    fi
    
    chown_cmd+=" \"$owner\" \"$path\""
    
    log_debug "Commande chown: $chown_cmd"
    
    # Vérifier les permissions avant d'essayer
    if [[ ! -w "$path" ]] && [[ $(id -u) -ne 0 ]]; then
        warnings+=("May require root privileges to change ownership")
    fi
    
    # Exécuter la commande
    if eval "$chown_cmd" 2>/dev/null; then
        log_info "Propriétaire modifié avec succès"
        
        # Vérifier que le changement a bien eu lieu
        current_info=$(get_file_owner_info "$path")
        if [[ "$current_info" == "$previous_info" ]]; then
            warnings+=("Ownership change may have had no effect")
        fi
    else
        local exit_code=$?
        case $exit_code in
            1) errors+=("Permission denied - insufficient privileges") ;;
            2) errors+=("Invalid owner specification") ;;
            *) errors+=("Failed to change ownership (exit code: $exit_code)") ;;
        esac
    fi
    
    handle_result "$path" "$owner" "${errors[@]}" "${warnings[@]}" "$previous_info" "$files_affected"
    
    [[ ${#errors[@]} -eq 0 ]] && return 0 || return 1
}

handle_result() {
    local path="$1"
    local owner="$2"
    local previous_info="$3"
    local files_affected="$4"
    shift 4
    local errors=("$@")
    local warnings=()
    
    # Séparer les erreurs des warnings
    local actual_errors=()
    for item in "${errors[@]}"; do
        if [[ "$item" =~ ^WARNING: ]]; then
            warnings+=("${item#WARNING: }")
        else
            actual_errors+=("$item")
        fi
    done
    
    # Obtenir les informations actuelles
    local current_info
    current_info=$(get_file_owner_info "$path")
    
    # Parser les informations précédentes et actuelles
    local prev_user prev_group prev_uid prev_gid
    local curr_user curr_group curr_uid curr_gid
    
    IFS=':' read -r prev_user prev_group prev_uid prev_gid <<< "$previous_info"
    IFS=':' read -r curr_user curr_group curr_uid curr_gid <<< "$current_info"
    
    # Échapper les caractères pour JSON
    local path_escaped owner_escaped
    path_escaped=$(echo "$path" | sed 's/\\/\\\\/g; s/"/\\"/g')
    owner_escaped=$(echo "$owner" | sed 's/\\/\\\\/g; s/"/\\"/g')
    
    # Construire les tableaux JSON
    local errors_json="[]" warnings_json="[]"
    if [[ ${#actual_errors[@]} -gt 0 ]]; then
        local errors_escaped=()
        for error in "${actual_errors[@]}"; do
            errors_escaped+=("\"$(echo "$error" | sed 's/\\/\\\\/g; s/"/\\"/g')\"")
        done
        errors_json="[$(IFS=','; echo "${errors_escaped[*]}")]"
    fi
    
    if [[ ${#warnings[@]} -gt 0 ]]; then
        local warnings_escaped=()
        for warning in "${warnings[@]}"; do
            warnings_escaped+=("\"$(echo "$warning" | sed 's/\\/\\\\/g; s/"/\\"/g')\"")
        done
        warnings_json="[$(IFS=','; echo "${warnings_escaped[*]}")]"
    fi
    
    # Déterminer le statut
    local status="success"
    local code=0
    local message="File ownership changed successfully"
    
    if [[ ${#actual_errors[@]} -gt 0 ]]; then
        status="error"
        code=1
        message="Failed to change file ownership"
    fi
    
    # Générer la réponse JSON
    cat << EOF
{
  "status": "$status",
  "code": $code,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "$message",
  "data": {
    "path": "$path_escaped",
    "requested_owner": "$owner_escaped",
    "previous_owner": {
      "user": "$prev_user",
      "group": "$prev_group",
      "uid": $prev_uid,
      "gid": $prev_gid
    },
    "current_owner": {
      "user": "$curr_user",
      "group": "$curr_group",
      "uid": $curr_uid,
      "gid": $curr_gid
    },
    "applied_recursive": $([ $RECURSIVE -eq 1 ] && echo "true" || echo "false"),
    "files_affected": $files_affected
  },
  "errors": $errors_json,
  "warnings": $warnings_json
}
EOF
}

# =============================================================================
# Fonction Principale
# =============================================================================

main() {
    log_debug "Démarrage de $SCRIPT_NAME v$SCRIPT_VERSION"
    
    parse_args "$@"
    check_dependencies
    set_file_owner "$TARGET_PATH" "$NEW_OWNER"
    
    log_info "Script completed"
}

# =============================================================================
# Point d'Entrée
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi