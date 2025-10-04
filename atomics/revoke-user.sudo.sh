#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: revoke-user.sudo.sh 
# Description: Révoquer les privilèges sudo d'un utilisateur
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-04
# ==============================================================================

set -euo pipefail

SCRIPT_NAME="revoke-user.sudo.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
USERNAME=""
REMOVE_FROM_GROUPS=${REMOVE_FROM_GROUPS:-1}
BACKUP_SUDOERS=${BACKUP_SUDOERS:-1}
FORCE=${FORCE:-0}

show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] <username>

Description:
    Révoque les privilèges sudo d'un utilisateur en le supprimant
    des groupes sudo et en nettoyant les entrées sudoers.

Arguments:
    <username>       Nom de l'utilisateur à révoquer

Options:
    -h, --help       Afficher cette aide
    -v, --verbose    Mode verbeux
    -d, --debug      Mode debug
    -q, --quiet      Mode silencieux
    -j, --json-only  Sortie JSON uniquement
    -f, --force      Forcer la révocation sans confirmation
    --keep-groups    Ne pas supprimer des groupes sudo
    --no-backup      Ne pas sauvegarder sudoers
    
Exemples:
    $SCRIPT_NAME john
    $SCRIPT_NAME -f --keep-groups admin_user
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help) show_help; exit 0 ;;
            -v|--verbose) VERBOSE=1; shift ;;
            -d|--debug) DEBUG=1; VERBOSE=1; shift ;;
            -q|--quiet) QUIET=1; shift ;;
            -j|--json-only) JSON_ONLY=1; QUIET=1; shift ;;
            -f|--force) FORCE=1; shift ;;
            --keep-groups) REMOVE_FROM_GROUPS=0; shift ;;
            --no-backup) BACKUP_SUDOERS=0; shift ;;
            -*) echo "Option inconnue: $1" >&2; exit 2 ;;
            *) 
                [[ -z "$USERNAME" ]] && USERNAME="$1" || { echo "Trop d'arguments" >&2; exit 2; }
                shift ;;
        esac
    done

    [[ -z "$USERNAME" ]] && { echo "Nom d'utilisateur manquant" >&2; exit 2; }
}

user_exists() {
    local username="$1"
    id "$username" >/dev/null 2>&1
}

get_user_groups() {
    local username="$1"
    groups "$username" 2>/dev/null | cut -d: -f2 | tr ' ' '\n' | grep -v "^$" || echo ""
}

is_in_sudo_group() {
    local username="$1"
    local sudo_groups=("sudo" "wheel" "admin")
    
    for group in "${sudo_groups[@]}"; do
        if groups "$username" 2>/dev/null | grep -q "\b$group\b"; then
            return 0
        fi
    done
    return 1
}

get_sudoers_entries() {
    local username="$1"
    local entries=()
    
    # Vérifier /etc/sudoers
    if [[ -f /etc/sudoers ]]; then
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*$username[[:space:]] ]]; then
                entries+=("$line")
            fi
        done < /etc/sudoers
    fi
    
    # Vérifier /etc/sudoers.d/
    if [[ -d /etc/sudoers.d ]]; then
        while IFS= read -r file; do
            [[ -f "$file" ]] || continue
            while IFS= read -r line; do
                if [[ "$line" =~ ^[[:space:]]*$username[[:space:]] ]]; then
                    entries+=("$file:$line")
                fi
            done < "$file"
        done < <(find /etc/sudoers.d -type f 2>/dev/null)
    fi
    
    printf '%s\n' "${entries[@]}"
}

backup_sudoers() {
    local backup_dir="/etc/sudoers.backup.$(date +%Y%m%d_%H%M%S)"
    
    mkdir -p "$backup_dir" || return 1
    cp /etc/sudoers "$backup_dir/" 2>/dev/null || return 1
    
    if [[ -d /etc/sudoers.d ]]; then
        cp -r /etc/sudoers.d "$backup_dir/" 2>/dev/null || true
    fi
    
    echo "$backup_dir"
}

remove_from_sudo_groups() {
    local username="$1"
    local removed_groups=()
    local sudo_groups=("sudo" "wheel" "admin")
    
    for group in "${sudo_groups[@]}"; do
        if getent group "$group" >/dev/null 2>&1; then
            if groups "$username" 2>/dev/null | grep -q "\b$group\b"; then
                if gpasswd -d "$username" "$group" >/dev/null 2>&1; then
                    removed_groups+=("$group")
                fi
            fi
        fi
    done
    
    printf '%s\n' "${removed_groups[@]}"
}

remove_sudoers_entries() {
    local username="$1"
    local removed_entries=()
    
    # Créer un fichier temporaire pour les modifications
    local temp_sudoers
    temp_sudoers=$(mktemp)
    
    # Traiter /etc/sudoers
    if [[ -f /etc/sudoers ]]; then
        while IFS= read -r line; do
            if [[ ! "$line" =~ ^[[:space:]]*$username[[:space:]] ]]; then
                echo "$line" >> "$temp_sudoers"
            else
                removed_entries+=("/etc/sudoers:$line")
            fi
        done < /etc/sudoers
        
        # Vérifier la syntaxe avec visudo
        if visudo -c -f "$temp_sudoers" >/dev/null 2>&1; then
            cp "$temp_sudoers" /etc/sudoers
        fi
    fi
    rm -f "$temp_sudoers"
    
    # Traiter les fichiers dans /etc/sudoers.d/
    if [[ -d /etc/sudoers.d ]]; then
        while IFS= read -r file; do
            [[ -f "$file" ]] || continue
            local temp_file
            temp_file=$(mktemp)
            local modified=false
            
            while IFS= read -r line; do
                if [[ ! "$line" =~ ^[[:space:]]*$username[[:space:]] ]]; then
                    echo "$line" >> "$temp_file"
                else
                    removed_entries+=("$file:$line")
                    modified=true
                fi
            done < "$file"
            
            if [[ $modified == true ]]; then
                if visudo -c -f "$temp_file" >/dev/null 2>&1; then
                    cp "$temp_file" "$file"
                fi
            fi
            rm -f "$temp_file"
        done < <(find /etc/sudoers.d -type f 2>/dev/null)
    fi
    
    printf '%s\n' "${removed_entries[@]}"
}

main() {
    parse_args "$@"
    
    local errors=() warnings=()
    
    # Vérifier que l'utilisateur existe
    if ! user_exists "$USERNAME"; then
        errors+=("User does not exist: $USERNAME")
    fi
    
    # Vérifier les permissions root
    if [[ $EUID -ne 0 ]]; then
        errors+=("Root privileges required")
    fi
    
    # Vérifier si l'utilisateur a des privilèges sudo
    local has_sudo_privileges=false
    if [[ ${#errors[@]} -eq 0 ]]; then
        if is_in_sudo_group "$USERNAME"; then
            has_sudo_privileges=true
        fi
        
        local sudoers_entries
        readarray -t sudoers_entries < <(get_sudoers_entries "$USERNAME")
        if [[ ${#sudoers_entries[@]} -gt 0 ]]; then
            has_sudo_privileges=true
        fi
        
        if [[ $has_sudo_privileges == false ]]; then
            warnings+=("User has no sudo privileges to revoke")
        fi
    fi
    
    if [[ ${#errors[@]} -eq 0 ]] && [[ $has_sudo_privileges == true ]]; then
        local backup_dir="" removed_groups=() removed_entries=()
        
        # Sauvegarder sudoers si demandé
        if [[ $BACKUP_SUDOERS -eq 1 ]]; then
            backup_dir=$(backup_sudoers)
            if [[ -z "$backup_dir" ]]; then
                warnings+=("Failed to backup sudoers files")
            fi
        fi
        
        # Supprimer des groupes sudo
        if [[ $REMOVE_FROM_GROUPS -eq 1 ]]; then
            readarray -t removed_groups < <(remove_from_sudo_groups "$USERNAME")
        fi
        
        # Supprimer les entrées sudoers
        readarray -t removed_entries < <(remove_sudoers_entries "$USERNAME")
        
        # Vérifier le statut final
        local still_has_privileges=false
        if is_in_sudo_group "$USERNAME"; then
            still_has_privileges=true
            warnings+=("User still in some sudo groups")
        fi
        
        local final_entries
        readarray -t final_entries < <(get_sudoers_entries "$USERNAME")
        if [[ ${#final_entries[@]} -gt 0 ]]; then
            still_has_privileges=true
            warnings+=("Some sudoers entries may remain")
        fi
        
        cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Sudo privileges revocation completed",
  "data": {
    "username": "$USERNAME",
    "had_privileges": true,
    "revocation_complete": $([ $still_has_privileges == false ] && echo "true" || echo "false"),
    "removed_from_groups": [$(printf '"%s",' "${removed_groups[@]}" | sed 's/,$//')],
    "removed_sudoers_entries": [$(printf '"%s",' "${removed_entries[@]}" | sed 's/,$//')],
    "backup_created": $([ -n "$backup_dir" ] && echo "true" || echo "false"),
    "backup_location": "$backup_dir",
    "groups_processed": $REMOVE_FROM_GROUPS,
    "sudoers_backup": $BACKUP_SUDOERS
  },
  "errors": [],
  "warnings": [$(printf '"%s",' "${warnings[@]}" | sed 's/,$//')"]
}
EOF
    elif [[ ${#errors[@]} -eq 0 ]]; then
        cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "No sudo privileges to revoke",
  "data": {
    "username": "$USERNAME",
    "had_privileges": false,
    "revocation_complete": true
  },
  "errors": [],
  "warnings": [$(printf '"%s",' "${warnings[@]}" | sed 's/,$//')"]
}
EOF
    else
        cat << EOF
{
  "status": "error",
  "code": 1,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Sudo privilege revocation failed",
  "data": {},
  "errors": [$(printf '"%s",' "${errors[@]}" | sed 's/,$//')],
  "warnings": [$(printf '"%s",' "${warnings[@]}" | sed 's/,$//')"]
}
EOF
        exit 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi