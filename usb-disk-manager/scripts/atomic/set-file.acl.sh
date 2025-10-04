#!/usr/bin/env bash

# ============================================================================
# Script atomique : set-file.acl.sh
# Description : Gestion des ACL (Access Control Lists) pour fichiers et répertoires
# Auteur : Généré automatiquement
# Version : 1.0
# Usage : ./set-file.acl.sh [OPTIONS]
# ============================================================================

set -euo pipefail

# === CONFIGURATION ===
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# === FONCTIONS UTILITAIRES ===
show_help() {
    cat << 'EOF'
USAGE:
    set-file.acl.sh [OPTIONS]

DESCRIPTION:
    Configure les ACL (Access Control Lists) pour les fichiers et répertoires.
    Supporte les ACL POSIX étendues avec gestion des permissions détaillées.

OPTIONS:
    -t, --target PATH        Chemin du fichier/répertoire cible
    -u, --user USER         Utilisateur pour l'ACL (user:permissions)
    -g, --group GROUP       Groupe pour l'ACL (group:permissions)
    -o, --other OTHER       Autres pour l'ACL (other:permissions)
    -p, --permissions PERM  Permissions (r/w/x ou octales)
    -r, --recursive         Application récursive pour répertoires
    -d, --default          Définir comme ACL par défaut
    -m, --mask MASK        Définir le masque ACL
    -c, --clear            Supprimer toutes les ACL étendues
    -b, --backup           Sauvegarder les ACL existantes
    -v, --verbose          Mode verbeux
    -q, --quiet            Mode silencieux
    -h, --help             Afficher cette aide

EXAMPLES:
    # Donner accès lecture/écriture à un utilisateur
    set-file.acl.sh -t /path/to/file -u "john:rw-"
    
    # Configurer ACL de groupe avec récursion
    set-file.acl.sh -t /path/to/dir -g "developers:rwx" --recursive
    
    # Supprimer toutes les ACL étendues
    set-file.acl.sh -t /path/to/file --clear
    
    # ACL par défaut pour nouveau contenu
    set-file.acl.sh -t /path/to/dir -u "user:rwx" --default --recursive

OUTPUT:
    JSON avec statut, détails des ACL et statistiques
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
    local deps=("getfacl" "setfacl")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_message "ERROR" "Dépendances manquantes: ${missing[*]}"
        log_message "INFO" "Installation requise: sudo apt-get install acl"
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
    
    # Vérifier si le système de fichiers supporte les ACL
    local fs_type
    fs_type=$(stat -f -c %T "$target" 2>/dev/null || echo "unknown")
    
    case "$fs_type" in
        ext[234]|xfs|btrfs|zfs)
            log_message "DEBUG" "Système de fichiers compatible ACL: $fs_type"
            ;;
        vfat|ntfs|tmpfs)
            log_message "WARN" "Système de fichiers avec support ACL limité: $fs_type"
            ;;
        *)
            log_message "WARN" "Support ACL non vérifié pour: $fs_type"
            ;;
    esac
    
    return 0
}

parse_permissions() {
    local perm="$1"
    local result=""
    
    # Conversion permissions symboliques vers format ACL
    case "$perm" in
        r--) result="r--" ;;
        -w-) result="-w-" ;;
        --x) result="--x" ;;
        rw-) result="rw-" ;;
        r-x) result="r-x" ;;
        -wx) result="-wx" ;;
        rwx) result="rwx" ;;
        ---) result="---" ;;
        [0-7])
            # Conversion octale vers symbolique
            local octal="$perm"
            result=""
            [[ $((octal & 4)) -ne 0 ]] && result+="r" || result+="-"
            [[ $((octal & 2)) -ne 0 ]] && result+="w" || result+="-"
            [[ $((octal & 1)) -ne 0 ]] && result+="x" || result+="-"
            ;;
        *)
            if [[ "$perm" =~ ^[rwx-]{3}$ ]]; then
                result="$perm"
            else
                log_message "ERROR" "Format de permissions invalide: $perm"
                return 1
            fi
            ;;
    esac
    
    echo "$result"
    return 0
}

backup_acl() {
    local target="$1"
    local backup_file="/tmp/acl_backup_$(basename "$target")_$(date +%s).acl"
    
    if getfacl "$target" > "$backup_file" 2>/dev/null; then
        log_message "INFO" "Sauvegarde ACL: $backup_file"
        echo "$backup_file"
        return 0
    else
        log_message "WARN" "Impossible de sauvegarder les ACL"
        return 1
    fi
}

get_current_acl() {
    local target="$1"
    local acl_info=()
    
    if command -v getfacl >/dev/null 2>&1; then
        while IFS= read -r line; do
            [[ "$line" =~ ^#.*$ ]] && continue  # Ignorer commentaires
            [[ -n "$line" ]] && acl_info+=("$line")
        done < <(getfacl --omit-header "$target" 2>/dev/null || echo "")
    fi
    
    printf '%s\n' "${acl_info[@]}"
}

apply_acl() {
    local target="$1"
    local acl_entries=()
    local success=0
    local failed=0
    
    # Collecte des entrées ACL à appliquer
    [[ -n "${USER_ACL:-}" ]] && acl_entries+=("u:${USER_ACL}")
    [[ -n "${GROUP_ACL:-}" ]] && acl_entries+=("g:${GROUP_ACL}")
    [[ -n "${OTHER_ACL:-}" ]] && acl_entries+=("o:${OTHER_ACL}")
    [[ -n "${MASK_ACL:-}" ]] && acl_entries+=("m:${MASK_ACL}")
    
    if [[ ${#acl_entries[@]} -eq 0 ]]; then
        log_message "ERROR" "Aucune entrée ACL à appliquer"
        return 1
    fi
    
    # Application des ACL
    for entry in "${acl_entries[@]}"; do
        local cmd_args=("-m" "$entry")
        
        # Ajout des options
        [[ "${RECURSIVE:-0}" == "1" ]] && cmd_args+=("-R")
        [[ "${DEFAULT_ACL:-0}" == "1" ]] && cmd_args+=("-d")
        
        cmd_args+=("$target")
        
        log_message "DEBUG" "Application ACL: setfacl ${cmd_args[*]}"
        
        if setfacl "${cmd_args[@]}" 2>/dev/null; then
            ((success++))
            log_message "INFO" "ACL appliquée avec succès: $entry"
        else
            ((failed++))
            log_message "ERROR" "Échec application ACL: $entry"
        fi
    done
    
    if [[ $failed -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

clear_extended_acl() {
    local target="$1"
    local cmd_args=("-b")
    
    [[ "${RECURSIVE:-0}" == "1" ]] && cmd_args+=("-R")
    cmd_args+=("$target")
    
    log_message "DEBUG" "Suppression ACL étendues: setfacl ${cmd_args[*]}"
    
    if setfacl "${cmd_args[@]}" 2>/dev/null; then
        log_message "INFO" "ACL étendues supprimées avec succès"
        return 0
    else
        log_message "ERROR" "Échec suppression ACL étendues"
        return 1
    fi
}

main() {
    local target=""
    local user_spec=""
    local group_spec=""
    local other_spec=""
    local mask_spec=""
    local permissions=""
    
    # Analyse des arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -t|--target)
                target="$2"
                shift 2
                ;;
            -u|--user)
                user_spec="$2"
                shift 2
                ;;
            -g|--group)
                group_spec="$2"
                shift 2
                ;;
            -o|--other)
                other_spec="$2"
                shift 2
                ;;
            -p|--permissions)
                permissions="$2"
                shift 2
                ;;
            -m|--mask)
                mask_spec="$2"
                shift 2
                ;;
            -r|--recursive)
                RECURSIVE=1
                shift
                ;;
            -d|--default)
                DEFAULT_ACL=1
                shift
                ;;
            -c|--clear)
                CLEAR_ACL=1
                shift
                ;;
            -b|--backup)
                BACKUP_ACL=1
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
    
    # Vérification des dépendances
    if ! check_dependencies; then
        echo '{"success": false, "error": "dependencies_missing", "message": "ACL tools not available"}'
        exit 1
    fi
    
    # Validation de la cible
    if ! validate_target "$target"; then
        echo '{"success": false, "error": "invalid_target", "message": "Target validation failed"}'
        exit 1
    fi
    
    local start_time=$(date +%s)
    local backup_file=""
    local initial_acl
    initial_acl=$(get_current_acl "$target")
    
    # Sauvegarde si demandée
    if [[ "${BACKUP_ACL:-0}" == "1" ]]; then
        backup_file=$(backup_acl "$target") || true
    fi
    
    # Préparation des ACL
    if [[ -n "$user_spec" ]]; then
        if [[ "$user_spec" == *":"* ]]; then
            USER_ACL="$user_spec"
        else
            local parsed_perm
            parsed_perm=$(parse_permissions "${permissions:-rwx}") || {
                echo '{"success": false, "error": "invalid_permissions", "message": "Permission parsing failed"}'
                exit 1
            }
            USER_ACL="${user_spec}:${parsed_perm}"
        fi
    fi
    
    if [[ -n "$group_spec" ]]; then
        if [[ "$group_spec" == *":"* ]]; then
            GROUP_ACL="$group_spec"
        else
            local parsed_perm
            parsed_perm=$(parse_permissions "${permissions:-rwx}") || {
                echo '{"success": false, "error": "invalid_permissions", "message": "Permission parsing failed"}'
                exit 1
            }
            GROUP_ACL="${group_spec}:${parsed_perm}"
        fi
    fi
    
    if [[ -n "$other_spec" ]]; then
        local parsed_perm
        parsed_perm=$(parse_permissions "${other_spec}") || {
            echo '{"success": false, "error": "invalid_permissions", "message": "Permission parsing failed"}'
            exit 1
        }
        OTHER_ACL=":${parsed_perm}"
    fi
    
    if [[ -n "$mask_spec" ]]; then
        local parsed_perm
        parsed_perm=$(parse_permissions "$mask_spec") || {
            echo '{"success": false, "error": "invalid_permissions", "message": "Mask parsing failed"}'
            exit 1
        }
        MASK_ACL="$parsed_perm"
    fi
    
    # Application des modifications
    local operation_success=true
    
    if [[ "${CLEAR_ACL:-0}" == "1" ]]; then
        if ! clear_extended_acl "$target"; then
            operation_success=false
        fi
    else
        if ! apply_acl "$target"; then
            operation_success=false
        fi
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local final_acl
    final_acl=$(get_current_acl "$target")
    
    # Génération du rapport JSON
    cat << EOF
{
    "success": $($operation_success && echo "true" || echo "false"),
    "target": "$target",
    "operation": "${CLEAR_ACL:+clear}${USER_ACL:+set_user}${GROUP_ACL:+set_group}${OTHER_ACL:+set_other}${MASK_ACL:+set_mask}",
    "recursive": ${RECURSIVE:-false},
    "default_acl": ${DEFAULT_ACL:-false},
    "backup_file": "${backup_file:-null}",
    "duration_seconds": $duration,
    "acl": {
        "before": $(echo "$initial_acl" | jq -R . | jq -s .),
        "after": $(echo "$final_acl" | jq -R . | jq -s .),
        "entries_applied": {
            "user": "${USER_ACL:-null}",
            "group": "${GROUP_ACL:-null}",
            "other": "${OTHER_ACL:-null}",
            "mask": "${MASK_ACL:-null}"
        }
    },
    "target_info": {
        "type": "$([[ -d "$target" ]] && echo "directory" || echo "file")",
        "size_bytes": $(stat -c %s "$target" 2>/dev/null || echo 0),
        "owner": "$(stat -c %U "$target" 2>/dev/null || echo "unknown")",
        "group": "$(stat -c %G "$target" 2>/dev/null || echo "unknown")",
        "mode": "$(stat -c %a "$target" 2>/dev/null || echo "000")"
    },
    "system_info": {
        "filesystem": "$(stat -f -c %T "$target" 2>/dev/null || echo "unknown")",
        "acl_support": $(getfacl "$target" >/dev/null 2>&1 && echo "true" || echo "false"),
        "tools_available": {
            "getfacl": $(command -v getfacl >/dev/null && echo "true" || echo "false"),
            "setfacl": $(command -v setfacl >/dev/null && echo "true" || echo "false")
        }
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