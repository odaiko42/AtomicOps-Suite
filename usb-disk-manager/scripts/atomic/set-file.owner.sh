#!/usr/bin/env bash

# ============================================================================
# Script atomique : set-file.owner.sh
# Description : Gestion de la propriété (ownership) des fichiers et répertoires
# Auteur : Généré automatiquement
# Version : 1.0
# Usage : ./set-file.owner.sh [OPTIONS]
# ============================================================================

set -euo pipefail

# === CONFIGURATION ===
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# === FONCTIONS UTILITAIRES ===
show_help() {
    cat << 'EOF'
USAGE:
    set-file.owner.sh [OPTIONS]

DESCRIPTION:
    Modifie la propriété (owner/group) des fichiers et répertoires.
    Supporte les changements de propriétaire et groupe avec validation complète.

OPTIONS:
    -t, --target PATH       Chemin du fichier/répertoire cible (requis)
    -o, --owner USER        Nouvel utilisateur propriétaire
    -g, --group GROUP       Nouveau groupe propriétaire
    -u, --user-group USER   Définir utilisateur et son groupe principal
    -r, --recursive         Application récursive pour répertoires
    -H, --dereference       Suivre les liens symboliques
    -L, --no-dereference    Ne pas suivre les liens symboliques
    -P, --preserve-root     Protection contre changement sur /
    -b, --backup           Sauvegarder les permissions actuelles
    -f, --force            Forcer les changements (ignore certains avertissements)
    -v, --verbose          Mode verbeux
    -q, --quiet            Mode silencieux
    -h, --help             Afficher cette aide

EXAMPLES:
    # Changer le propriétaire d'un fichier
    set-file.owner.sh -t /path/to/file -o "newuser"
    
    # Changer propriétaire et groupe
    set-file.owner.sh -t /path/to/file -o "user" -g "group"
    
    # Récursif sur un répertoire
    set-file.owner.sh -t /path/to/dir -o "user:group" --recursive
    
    # Utilisateur avec son groupe principal
    set-file.owner.sh -t /path/to/file --user-group "username"

OUTPUT:
    JSON avec statut, détails de propriété et statistiques
EOF
}

log_message() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ "${QUIET:-0}" != "1" ]]; then
        case "$level" in
            "ERROR") echo "[$timestamp] ERROR: $message" >&2 ;;
            "WARN")  echo "[$timestamp] WARN: $message" >&2 ;;
            "INFO")  echo "[$timestamp] INFO: $message" >&2 ;;
            "DEBUG") [[ "${VERBOSE:-0}" == "1" ]] && echo "[$timestamp] DEBUG: $message" >&2 ;;
        esac
    fi
}

check_dependencies() {
    local deps=("chown" "stat" "id")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_message "ERROR" "Dépendances manquantes: ${missing[*]}"
        return 1
    fi
    
    return 0
}

validate_target() {
    local target="$1"
    
    if [[ ! -e "$target" ]]; then
        log_message "ERROR" "Cible inexistante: $target"
        return 1
    fi
    
    # Protection contre la racine si demandée
    if [[ "${PRESERVE_ROOT:-0}" == "1" && "$target" == "/" ]]; then
        log_message "ERROR" "Changement sur / interdit (--preserve-root)"
        return 1
    fi
    
    # Vérification des permissions d'écriture sur le répertoire parent
    local parent_dir
    parent_dir=$(dirname "$target")
    
    if [[ ! -w "$parent_dir" ]] && [[ "${FORCE:-0}" != "1" ]]; then
        log_message "WARN" "Pas de permissions d'écriture sur: $parent_dir"
        log_message "INFO" "Utilisez --force pour ignorer cette vérification"
        return 1
    fi
    
    return 0
}

validate_user() {
    local user="$1"
    
    # Vérification si l'utilisateur existe
    if ! id "$user" >/dev/null 2>&1; then
        log_message "ERROR" "Utilisateur inexistant: $user"
        return 1
    fi
    
    # Récupération des informations utilisateur
    local uid
    uid=$(id -u "$user" 2>/dev/null || echo "")
    
    if [[ -z "$uid" ]]; then
        log_message "ERROR" "Impossible de récupérer l'UID pour: $user"
        return 1
    fi
    
    log_message "DEBUG" "Utilisateur validé: $user (UID: $uid)"
    return 0
}

validate_group() {
    local group="$1"
    
    # Vérification si le groupe existe
    if ! getent group "$group" >/dev/null 2>&1; then
        log_message "ERROR" "Groupe inexistant: $group"
        return 1
    fi
    
    # Récupération des informations groupe
    local gid
    gid=$(getent group "$group" | cut -d: -f3)
    
    if [[ -z "$gid" ]]; then
        log_message "ERROR" "Impossible de récupérer le GID pour: $group"
        return 1
    fi
    
    log_message "DEBUG" "Groupe validé: $group (GID: $gid)"
    return 0
}

get_user_primary_group() {
    local user="$1"
    
    if ! validate_user "$user"; then
        return 1
    fi
    
    local primary_group
    primary_group=$(id -gn "$user" 2>/dev/null)
    
    if [[ -z "$primary_group" ]]; then
        log_message "ERROR" "Impossible de récupérer le groupe principal de: $user"
        return 1
    fi
    
    echo "$primary_group"
    return 0
}

parse_ownership_spec() {
    local spec="$1"
    local owner=""
    local group=""
    
    # Formats supportés: user, user:group, :group, user:
    if [[ "$spec" == *":"* ]]; then
        owner="${spec%:*}"
        group="${spec#*:}"
    else
        owner="$spec"
    fi
    
    # Validation des composants
    if [[ -n "$owner" ]] && ! validate_user "$owner"; then
        return 1
    fi
    
    if [[ -n "$group" ]] && ! validate_group "$group"; then
        return 1
    fi
    
    echo "${owner}:${group}"
    return 0
}

backup_ownership() {
    local target="$1"
    local backup_file="/tmp/ownership_backup_$(basename "$target")_$(date +%s).info"
    
    {
        echo "# Sauvegarde propriété pour: $target"
        echo "# Date: $(date)"
        echo "TARGET=$target"
        echo "OWNER=$(stat -c %U "$target" 2>/dev/null || echo "unknown")"
        echo "GROUP=$(stat -c %G "$target" 2>/dev/null || echo "unknown")"
        echo "UID=$(stat -c %u "$target" 2>/dev/null || echo "0")"
        echo "GID=$(stat -c %g "$target" 2>/dev/null || echo "0")"
        echo "MODE=$(stat -c %a "$target" 2>/dev/null || echo "000")"
    } > "$backup_file"
    
    if [[ -f "$backup_file" ]]; then
        log_message "INFO" "Sauvegarde propriété: $backup_file"
        echo "$backup_file"
        return 0
    else
        log_message "WARN" "Impossible de sauvegarder la propriété"
        return 1
    fi
}

get_current_ownership() {
    local target="$1"
    
    local owner group uid gid
    owner=$(stat -c %U "$target" 2>/dev/null || echo "unknown")
    group=$(stat -c %G "$target" 2>/dev/null || echo "unknown")
    uid=$(stat -c %u "$target" 2>/dev/null || echo "0")
    gid=$(stat -c %g "$target" 2>/dev/null || echo "0")
    
    cat << EOF
{
    "owner": "$owner",
    "group": "$group",
    "uid": $uid,
    "gid": $gid
}
EOF
}

count_files_affected() {
    local target="$1"
    local recursive="${2:-0}"
    
    if [[ "$recursive" == "1" && -d "$target" ]]; then
        find "$target" -type f -o -type d | wc -l
    else
        echo "1"
    fi
}

apply_ownership() {
    local target="$1"
    local owner="$2"
    local group="$3"
    
    local chown_args=()
    local ownership_spec=""
    
    # Construction de la spécification propriété
    if [[ -n "$owner" && -n "$group" ]]; then
        ownership_spec="${owner}:${group}"
    elif [[ -n "$owner" ]]; then
        ownership_spec="$owner"
    elif [[ -n "$group" ]]; then
        ownership_spec=":${group}"
    else
        log_message "ERROR" "Aucune spécification de propriété fournie"
        return 1
    fi
    
    # Options chown
    [[ "${RECURSIVE:-0}" == "1" ]] && chown_args+=("-R")
    [[ "${DEREFERENCE:-0}" == "1" ]] && chown_args+=("-H")
    [[ "${NO_DEREFERENCE:-0}" == "1" ]] && chown_args+=("-h")
    [[ "${PRESERVE_ROOT:-0}" == "1" ]] && chown_args+=("--preserve-root")
    [[ "${VERBOSE:-0}" == "1" ]] && chown_args+=("-v")
    
    chown_args+=("$ownership_spec" "$target")
    
    log_message "DEBUG" "Commande: chown ${chown_args[*]}"
    
    if chown "${chown_args[@]}" 2>/dev/null; then
        log_message "INFO" "Propriété modifiée avec succès: $ownership_spec"
        return 0
    else
        local exit_code=$?
        log_message "ERROR" "Échec changement propriété (code: $exit_code)"
        return 1
    fi
}

check_permissions() {
    local target="$1"
    
    # Vérification si on a les droits pour changer la propriété
    local current_uid
    current_uid=$(id -u)
    
    if [[ "$current_uid" != "0" ]]; then
        local file_uid
        file_uid=$(stat -c %u "$target" 2>/dev/null || echo "0")
        
        if [[ "$current_uid" != "$file_uid" ]]; then
            log_message "WARN" "Droits insuffisants pour changer la propriété"
            log_message "INFO" "Utilisateur actuel: $(id -un) (UID: $current_uid)"
            log_message "INFO" "Propriétaire fichier: $(stat -c %U "$target") (UID: $file_uid)"
            
            if [[ "${FORCE:-0}" != "1" ]]; then
                return 1
            fi
        fi
    fi
    
    return 0
}

main() {
    local target=""
    local owner=""
    local group=""
    local user_group=""
    
    # Analyse des arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -t|--target)
                target="$2"
                shift 2
                ;;
            -o|--owner)
                owner="$2"
                shift 2
                ;;
            -g|--group)
                group="$2"
                shift 2
                ;;
            -u|--user-group)
                user_group="$2"
                shift 2
                ;;
            -r|--recursive)
                RECURSIVE=1
                shift
                ;;
            -H|--dereference)
                DEREFERENCE=1
                shift
                ;;
            -L|--no-dereference)
                NO_DEREFERENCE=1
                shift
                ;;
            -P|--preserve-root)
                PRESERVE_ROOT=1
                shift
                ;;
            -b|--backup)
                BACKUP_OWNERSHIP=1
                shift
                ;;
            -f|--force)
                FORCE=1
                shift
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -q|--quiet)
                QUIET=1
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_message "ERROR" "Option inconnue: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Validation des paramètres obligatoires
    if [[ -z "$target" ]]; then
        log_message "ERROR" "Paramètre --target requis"
        show_help
        exit 1
    fi
    
    # Traitement du format user:group dans owner
    if [[ -n "$owner" && "$owner" == *":"* ]]; then
        local parsed_spec
        parsed_spec=$(parse_ownership_spec "$owner") || {
            echo '{"success": false, "error": "invalid_ownership_spec", "message": "Ownership specification parsing failed"}'
            exit 1
        }
        owner="${parsed_spec%:*}"
        [[ -z "$group" ]] && group="${parsed_spec#*:}"
    fi
    
    # Gestion user-group (utilisateur + son groupe principal)
    if [[ -n "$user_group" ]]; then
        owner="$user_group"
        group=$(get_user_primary_group "$user_group") || {
            echo '{"success": false, "error": "user_group_resolution", "message": "Unable to resolve primary group"}'
            exit 1
        }
    fi
    
    # Validation qu'au moins owner ou group est spécifié
    if [[ -z "$owner" && -z "$group" ]]; then
        log_message "ERROR" "Au moins --owner ou --group doit être spécifié"
        show_help
        exit 1
    fi
    
    # Vérification des dépendances
    if ! check_dependencies; then
        echo '{"success": false, "error": "dependencies_missing", "message": "Required tools not available"}'
        exit 1
    fi
    
    # Validation de la cible
    if ! validate_target "$target"; then
        echo '{"success": false, "error": "invalid_target", "message": "Target validation failed"}'
        exit 1
    fi
    
    # Vérification des permissions
    if ! check_permissions "$target"; then
        echo '{"success": false, "error": "insufficient_permissions", "message": "Insufficient permissions for ownership change"}'
        exit 1
    fi
    
    local start_time=$(date +%s)
    local backup_file=""
    local initial_ownership
    initial_ownership=$(get_current_ownership "$target")
    
    # Sauvegarde si demandée
    if [[ "${BACKUP_OWNERSHIP:-0}" == "1" ]]; then
        backup_file=$(backup_ownership "$target") || true
    fi
    
    # Comptage des fichiers affectés
    local files_count
    files_count=$(count_files_affected "$target" "${RECURSIVE:-0}")
    
    # Application des changements
    local operation_success=true
    
    if ! apply_ownership "$target" "$owner" "$group"; then
        operation_success=false
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local final_ownership
    final_ownership=$(get_current_ownership "$target")
    
    # Génération du rapport JSON
    cat << EOF
{
    "success": $($operation_success && echo "true" || echo "false"),
    "target": "$target",
    "operation": "change_ownership",
    "recursive": ${RECURSIVE:-false},
    "preserve_root": ${PRESERVE_ROOT:-false},
    "backup_file": "${backup_file:-null}",
    "duration_seconds": $duration,
    "files_affected": $files_count,
    "ownership": {
        "before": $initial_ownership,
        "after": $final_ownership,
        "requested": {
            "owner": "${owner:-null}",
            "group": "${group:-null}"
        }
    },
    "target_info": {
        "type": "$([[ -d "$target" ]] && echo "directory" || echo "file")",
        "size_bytes": $(stat -c %s "$target" 2>/dev/null || echo 0),
        "mode": "$(stat -c %a "$target" 2>/dev/null || echo "000")",
        "is_symlink": $([[ -L "$target" ]] && echo "true" || echo "false")
    },
    "system_info": {
        "current_user": "$(id -un)",
        "current_uid": $(id -u),
        "is_root": $([[ $(id -u) -eq 0 ]] && echo "true" || echo "false")
    },
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "script": "$SCRIPT_NAME"
}
EOF
}

# Point d'entrée principal
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi