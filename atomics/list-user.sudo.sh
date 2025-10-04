#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: list-user.sudo.sh
# Description: Lister les utilisateurs ayant les privilèges sudo/root
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-04
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="list-user.sudo.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
DETAILED=${DETAILED:-0}

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
Usage: $SCRIPT_NAME [OPTIONS]

Description:
    Liste et analyse les utilisateurs ayant des privilèges sudo ou root
    avec détection des permissions spécifiques et audit de sécurité.

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)
    --detailed             Informations détaillées (permissions spécifiques)
    
Sortie JSON:
    {
      "status": "success|error",
      "code": 0,
      "timestamp": "ISO8601",
      "script": "$SCRIPT_NAME",
      "message": "Description",
      "data": {
        "sudo_users": [
          {
            "username": "admin",
            "uid": 1000,
            "gid": 1000,
            "groups": ["sudo", "adm", "users"],
            "sudo_permissions": "ALL=(ALL:ALL) ALL",
            "last_login": "2025-10-04T10:30:00Z",
            "password_set": true,
            "shell": "/bin/bash",
            "home_dir": "/home/admin",
            "account_locked": false,
            "sudo_nopasswd": false
          }
        ],
        "root_account": {
          "enabled": true,
          "password_set": true,
          "last_login": "2025-10-04T09:15:00Z",
          "shell": "/bin/bash",
          "locked": false
        },
        "sudo_groups": [
          {
            "group_name": "sudo",
            "gid": 27,
            "members": ["admin", "user2"]
          }
        ],
        "summary": {
          "total_sudo_users": 3,
          "active_sudo_users": 2,
          "passwordless_sudo": 1,
          "locked_accounts": 0,
          "root_enabled": true
        }
      },
      "errors": [],
      "warnings": []
    }

Codes de sortie:
    0 - Succès
    1 - Erreur générale
    2 - Erreur de paramètres
    3 - Fichiers système non accessibles
    4 - Permissions insuffisantes

Exemples:
    $SCRIPT_NAME                                   # Liste basique
    $SCRIPT_NAME --detailed                       # Informations complètes
    $SCRIPT_NAME --json-only                     # Sortie JSON seulement
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
            --detailed)
                DETAILED=1
                shift
                ;;
            -*)
                die "Option inconnue: $1. Utilisez -h pour l'aide." 2
                ;;
            *)
                die "Argument inattendu: $1. Utilisez -h pour l'aide." 2
                ;;
        esac
    done
}

# =============================================================================
# Fonctions Métier
# =============================================================================

check_dependencies() {
    local missing=()
    
    if ! command -v getent >/dev/null 2>&1; then
        missing+=("getent")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Commandes manquantes: ${missing[*]}" 3
    fi
    
    log_debug "Dépendances vérifiées"
}

get_sudo_groups() {
    local sudo_groups=()
    
    # Groupes sudo standards
    local standard_groups=("sudo" "wheel" "admin")
    
    for group in "${standard_groups[@]}"; do
        if getent group "$group" >/dev/null 2>&1; then
            sudo_groups+=("$group")
        fi
    done
    
    printf "%s\n" "${sudo_groups[@]}"
}

get_group_members() {
    local group_name="$1"
    
    local group_info
    group_info=$(getent group "$group_name" 2>/dev/null || echo "")
    
    if [[ -n "$group_info" ]]; then
        # Format: group_name:x:gid:member1,member2,member3
        echo "$group_info" | cut -d':' -f4 | tr ',' ' '
    fi
}

get_user_groups() {
    local username="$1"
    
    if command -v groups >/dev/null 2>&1; then
        groups "$username" 2>/dev/null | cut -d':' -f2 | xargs
    else
        id -Gn "$username" 2>/dev/null || echo ""
    fi
}

get_user_details() {
    local username="$1"
    
    local user_info
    user_info=$(getent passwd "$username" 2>/dev/null || echo "")
    
    if [[ -z "$user_info" ]]; then
        echo "|||||||"
        return
    fi
    
    # Format: username:x:uid:gid:comment:home:shell
    local uid gid comment home shell
    IFS=':' read -r _ _ uid gid comment home shell <<< "$user_info"
    
    # Vérifier si le compte est verrouillé
    local locked=false
    if command -v passwd >/dev/null 2>&1; then
        if passwd -S "$username" 2>/dev/null | grep -q " L "; then
            locked=true
        fi
    fi
    
    # Vérifier si le mot de passe est défini
    local password_set=false
    if [[ -r /etc/shadow ]]; then
        local shadow_entry
        shadow_entry=$(grep "^$username:" /etc/shadow 2>/dev/null || echo "")
        if [[ -n "$shadow_entry" ]]; then
            local password_hash
            password_hash=$(echo "$shadow_entry" | cut -d':' -f2)
            if [[ -n "$password_hash" && "$password_hash" != "*" && "$password_hash" != "!" ]]; then
                password_set=true
            fi
        fi
    fi
    
    # Dernière connexion
    local last_login=""
    if command -v lastlog >/dev/null 2>&1; then
        last_login=$(lastlog -u "$username" 2>/dev/null | tail -n1 | awk '{for(i=4;i<=NF;i++) printf "%s ", $i; print ""}' | xargs || echo "")
    fi
    
    echo "$uid|$gid|$home|$shell|$locked|$password_set|$last_login"
}

check_sudo_permissions() {
    local username="$1"
    
    # Vérifier sudoers
    local sudo_perms=""
    local nopasswd=false
    
    if command -v sudo >/dev/null 2>&1; then
        # Essayer de lister les privilèges sudo
        local sudo_list
        sudo_list=$(sudo -l -U "$username" 2>/dev/null || echo "")
        
        if [[ -n "$sudo_list" ]]; then
            # Chercher les permissions ALL
            if echo "$sudo_list" | grep -q "ALL"; then
                sudo_perms="ALL=(ALL:ALL) ALL"
            else
                sudo_perms="Limited permissions"
            fi
            
            # Vérifier NOPASSWD
            if echo "$sudo_list" | grep -q "NOPASSWD"; then
                nopasswd=true
            fi
        fi
    fi
    
    echo "$sudo_perms|$nopasswd"
}

get_root_account_info() {
    local root_details
    root_details=$(get_user_details "root")
    
    local uid gid home shell locked password_set last_login
    IFS='|' read -r uid gid home shell locked password_set last_login <<< "$root_details"
    
    local enabled=true
    if [[ "$locked" == "true" ]] || [[ "$shell" == "/usr/sbin/nologin" ]] || [[ "$shell" == "/bin/false" ]]; then
        enabled=false
    fi
    
    echo "$enabled|$password_set|$last_login|$shell|$locked"
}

build_sudo_users_json() {
    local sudo_groups_list=()
    local all_sudo_users=()
    
    # Obtenir les groupes sudo
    while IFS= read -r group; do
        [[ -z "$group" ]] && continue
        sudo_groups_list+=("$group")
        
        # Obtenir les membres de ce groupe
        local members
        members=$(get_group_members "$group")
        
        if [[ -n "$members" ]]; then
            for member in $members; do
                # Éviter les doublons
                if [[ ! " ${all_sudo_users[*]} " =~ " ${member} " ]]; then
                    all_sudo_users+=("$member")
                fi
            done
        fi
    done <<< "$(get_sudo_groups)"
    
    # Construire le JSON des utilisateurs sudo
    local sudo_users_json="[]"
    if [[ ${#all_sudo_users[@]} -gt 0 ]]; then
        local users_list=""
        
        for username in "${all_sudo_users[@]}"; do
            # Détails utilisateur
            local user_details
            user_details=$(get_user_details "$username")
            local uid gid home shell locked password_set last_login
            IFS='|' read -r uid gid home shell locked password_set last_login <<< "$user_details"
            
            # Groupes de l'utilisateur
            local user_groups
            user_groups=$(get_user_groups "$username")
            local groups_json="[]"
            if [[ -n "$user_groups" ]]; then
                local groups_list=""
                for group in $user_groups; do
                    groups_list+="\"$group\","
                done
                groups_list=${groups_list%,}
                groups_json="[$groups_list]"
            fi
            
            # Permissions sudo
            local sudo_info
            sudo_info=$(check_sudo_permissions "$username")
            local sudo_perms nopasswd
            IFS='|' read -r sudo_perms nopasswd <<< "$sudo_info"
            
            # Échapper pour JSON
            username=$(echo "$username" | sed 's/\\/\\\\/g; s/"/\\"/g')
            home=$(echo "$home" | sed 's/\\/\\\\/g; s/"/\\"/g')
            shell=$(echo "$shell" | sed 's/\\/\\\\/g; s/"/\\"/g')
            sudo_perms=$(echo "$sudo_perms" | sed 's/\\/\\\\/g; s/"/\\"/g')
            last_login=$(echo "$last_login" | sed 's/\\/\\\\/g; s/"/\\"/g')
            
            # Convertir last_login en ISO si possible
            if [[ -n "$last_login" && "$last_login" != "Never logged in" ]]; then
                last_login=$(date -d "$last_login" -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "$last_login")
            fi
            
            local user_json="{\"username\":\"$username\",\"uid\":$uid,\"gid\":$gid,\"groups\":$groups_json,\"sudo_permissions\":\"$sudo_perms\",\"last_login\":\"$last_login\",\"password_set\":$password_set,\"shell\":\"$shell\",\"home_dir\":\"$home\",\"account_locked\":$locked,\"sudo_nopasswd\":$nopasswd}"
            users_list+="$user_json,"
        done
        
        users_list=${users_list%,}
        [[ -n "$users_list" ]] && sudo_users_json="[$users_list]"
    fi
    
    echo "$sudo_users_json"
}

build_sudo_groups_json() {
    local groups_json="[]"
    local groups_list=""
    
    while IFS= read -r group; do
        [[ -z "$group" ]] && continue
        
        local group_info
        group_info=$(getent group "$group" 2>/dev/null || echo "")
        
        if [[ -n "$group_info" ]]; then
            local gid members_raw
            gid=$(echo "$group_info" | cut -d':' -f3)
            members_raw=$(echo "$group_info" | cut -d':' -f4)
            
            # Construire le JSON des membres
            local members_json="[]"
            if [[ -n "$members_raw" ]]; then
                local member_list=""
                IFS=',' read -ra MEMBERS <<< "$members_raw"
                for member in "${MEMBERS[@]}"; do
                    [[ -n "$member" ]] && member_list+="\"$member\","
                done
                member_list=${member_list%,}
                [[ -n "$member_list" ]] && members_json="[$member_list]"
            fi
            
            local group_json="{\"group_name\":\"$group\",\"gid\":$gid,\"members\":$members_json}"
            groups_list+="$group_json,"
        fi
    done <<< "$(get_sudo_groups)"
    
    groups_list=${groups_list%,}
    [[ -n "$groups_list" ]] && groups_json="[$groups_list]"
    
    echo "$groups_json"
}

# =============================================================================
# Fonction Principale
# =============================================================================

main() {
    log_debug "Démarrage de $SCRIPT_NAME v$SCRIPT_VERSION"
    
    parse_args "$@"
    check_dependencies
    
    log_info "Analyse des utilisateurs avec privilèges sudo/root"
    
    # Construire les données JSON
    local sudo_users_json
    sudo_users_json=$(build_sudo_users_json)
    
    local sudo_groups_json
    sudo_groups_json=$(build_sudo_groups_json)
    
    # Informations sur le compte root
    local root_info
    root_info=$(get_root_account_info)
    local root_enabled root_password_set root_last_login root_shell root_locked
    IFS='|' read -r root_enabled root_password_set root_last_login root_shell root_locked <<< "$root_info"
    
    # Échapper pour JSON
    root_last_login=$(echo "$root_last_login" | sed 's/\\/\\\\/g; s/"/\\"/g')
    root_shell=$(echo "$root_shell" | sed 's/\\/\\\\/g; s/"/\\"/g')
    
    # Statistiques
    local total_sudo_users
    total_sudo_users=$(echo "$sudo_users_json" | jq 'length' 2>/dev/null || echo "0")
    
    local active_sudo_users passwordless_sudo locked_accounts
    active_sudo_users=$(echo "$sudo_users_json" | jq '[.[] | select(.account_locked == false)] | length' 2>/dev/null || echo "0")
    passwordless_sudo=$(echo "$sudo_users_json" | jq '[.[] | select(.sudo_nopasswd == true)] | length' 2>/dev/null || echo "0")
    locked_accounts=$(echo "$sudo_users_json" | jq '[.[] | select(.account_locked == true)] | length' 2>/dev/null || echo "0")
    
    # Générer la réponse JSON
    cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Sudo users analysis completed successfully",
  "data": {
    "sudo_users": $sudo_users_json,
    "root_account": {
      "enabled": $root_enabled,
      "password_set": $root_password_set,
      "last_login": "$root_last_login",
      "shell": "$root_shell",
      "locked": $root_locked
    },
    "sudo_groups": $sudo_groups_json,
    "summary": {
      "total_sudo_users": $total_sudo_users,
      "active_sudo_users": $active_sudo_users,
      "passwordless_sudo": $passwordless_sudo,
      "locked_accounts": $locked_accounts,
      "root_enabled": $root_enabled
    },
    "detailed_analysis": $([ $DETAILED -eq 1 ] && echo "true" || echo "false")
  },
  "errors": [],
  "warnings": []
}
EOF
    
    log_info "Analyse terminée: $total_sudo_users utilisateurs sudo trouvés"
}

# =============================================================================
# Point d'Entrée
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi