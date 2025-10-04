#!/usr/bin/env bash

# ============================================================================
# Script atomique : set-password.expiry.sh
# Description : Gestion de l'expiration des mots de passe utilisateur
# Auteur : Généré automatiquement
# Version : 1.0
# Usage : ./set-password.expiry.sh [OPTIONS]
# ============================================================================

set -euo pipefail

# === CONFIGURATION ===
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# === FONCTIONS UTILITAIRES ===
show_help() {
    cat << 'EOF'
USAGE:
    set-password.expiry.sh [OPTIONS]

DESCRIPTION:
    Configure les politiques d'expiration des mots de passe pour les utilisateurs.
    Gère l'expiration, les avertissements et les blocages automatiques.

OPTIONS:
    -u, --user USERNAME     Utilisateur cible (requis)
    -d, --days DAYS         Jours avant expiration (0 = jamais, -1 = immédiate)
    -w, --warn-days DAYS    Jours d'avertissement avant expiration (défaut: 7)
    -i, --inactive DAYS     Jours d'inactivité avant blocage (défaut: -1)
    -m, --min-days DAYS     Jours minimum entre changements de mot de passe
    -M, --max-days DAYS     Jours maximum de validité du mot de passe
    -e, --expire-date DATE  Date d'expiration (YYYY-MM-DD ou timestamp)
    --disable-expiry        Désactiver l'expiration (équivalent à -d -1)
    --force-change          Forcer le changement au prochain login
    --unlock                Débloquer un compte expiré
    --show-info             Afficher les informations actuelles seulement
    -a, --all-users         Appliquer à tous les utilisateurs (avec prudence)
    --exclude-system        Exclure les utilisateurs système (UID < 1000)
    -b, --backup            Sauvegarder les configurations actuelles
    -v, --verbose           Mode verbeux
    -q, --quiet             Mode silencieux
    -h, --help              Afficher cette aide

EXAMPLES:
    # Définir expiration dans 90 jours
    set-password.expiry.sh -u john -d 90
    
    # Forcer changement au prochain login
    set-password.expiry.sh -u john --force-change
    
    # Configuration complète d'expiration
    set-password.expiry.sh -u john -M 90 -w 7 -i 30 -m 1
    
    # Désactiver l'expiration
    set-password.expiry.sh -u john --disable-expiry
    
    # Expiration à date fixe
    set-password.expiry.sh -u john -e "2024-12-31"

OUTPUT:
    JSON avec statut, politique d'expiration et informations utilisateur
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
    local deps=("chage" "passwd" "id")
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
    
    # Vérification des permissions root
    if [[ $(id -u) -ne 0 ]]; then
        log_message "ERROR" "Droits root requis pour modifier les politiques de mot de passe"
        return 1
    fi
    
    return 0
}

validate_user() {
    local username="$1"
    
    # Vérifier si l'utilisateur existe
    if ! id "$username" >/dev/null 2>&1; then
        log_message "ERROR" "Utilisateur inexistant: $username"
        return 1
    fi
    
    # Récupération des informations utilisateur
    local uid
    uid=$(id -u "$username" 2>/dev/null || echo "")
    
    if [[ -z "$uid" ]]; then
        log_message "ERROR" "Impossible de récupérer l'UID pour: $username"
        return 1
    fi
    
    # Avertissement pour les utilisateurs système
    if [[ "$uid" -lt 1000 ]]; then
        log_message "WARN" "Utilisateur système détecté: $username (UID: $uid)"
    fi
    
    log_message "DEBUG" "Utilisateur validé: $username (UID: $uid)"
    return 0
}

convert_date_to_days() {
    local date_input="$1"
    
    # Si c'est déjà un nombre (jours depuis epoch), le retourner
    if [[ "$date_input" =~ ^-?[0-9]+$ ]]; then
        echo "$date_input"
        return 0
    fi
    
    # Conversion de date YYYY-MM-DD vers jours depuis epoch
    if [[ "$date_input" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        local epoch_seconds
        epoch_seconds=$(date -d "$date_input" +%s 2>/dev/null || echo "")
        
        if [[ -n "$epoch_seconds" ]]; then
            local epoch_days=$((epoch_seconds / 86400))
            echo "$epoch_days"
            return 0
        fi
    fi
    
    log_message "ERROR" "Format de date invalide: $date_input (attendu: YYYY-MM-DD)"
    return 1
}

get_current_password_policy() {
    local username="$1"
    
    local chage_info
    chage_info=$(chage -l "$username" 2>/dev/null || echo "")
    
    if [[ -z "$chage_info" ]]; then
        echo '{"error": "unable_to_read_policy"}'
        return 1
    fi
    
    # Extraction des informations
    local last_change min_days max_days warn_days inactive_days expire_date
    last_change=$(echo "$chage_info" | grep "Last password change" | cut -d: -f2 | xargs || echo "never")
    min_days=$(echo "$chage_info" | grep "Minimum number of days" | cut -d: -f2 | xargs || echo "0")
    max_days=$(echo "$chage_info" | grep "Maximum number of days" | cut -d: -f2 | xargs || echo "99999")
    warn_days=$(echo "$chage_info" | grep "Number of days of warning" | cut -d: -f2 | xargs || echo "7")
    inactive_days=$(echo "$chage_info" | grep "Password inactive" | cut -d: -f2 | xargs || echo "-1")
    expire_date=$(echo "$chage_info" | grep "Account expires" | cut -d: -f2 | xargs || echo "never")
    
    # Conversion des valeurs spéciales
    [[ "$min_days" == "0" ]] && min_days="0"
    [[ "$max_days" == "99999" ]] && max_days="-1"
    [[ "$warn_days" == "7" ]] && warn_days="7"
    [[ "$inactive_days" == "-1" ]] && inactive_days="-1"
    
    cat << EOF
{
    "last_password_change": "$last_change",
    "minimum_days": $min_days,
    "maximum_days": $max_days,
    "warning_days": $warn_days,
    "inactive_days": $inactive_days,
    "expire_date": "$expire_date",
    "password_expires": $(echo "$chage_info" | grep -q "Password expires.*never" && echo "false" || echo "true"),
    "account_locked": $(passwd -S "$username" 2>/dev/null | grep -q " L " && echo "true" || echo "false")
}
EOF
}

backup_password_policies() {
    local users=("$@")
    local backup_file="/tmp/password_policies_backup_$(date +%s).txt"
    
    {
        echo "# Sauvegarde des politiques de mot de passe"
        echo "# Date: $(date)"
        echo "# Users: ${users[*]}"
        echo ""
        
        for user in "${users[@]}"; do
            echo "=== Utilisateur: $user ==="
            chage -l "$user" 2>/dev/null || echo "Erreur lecture politique pour $user"
            echo ""
        done
    } > "$backup_file"
    
    if [[ -f "$backup_file" ]]; then
        log_message "INFO" "Sauvegarde politiques: $backup_file"
        echo "$backup_file"
        return 0
    else
        log_message "WARN" "Impossible de sauvegarder les politiques"
        return 1
    fi
}

apply_password_expiry() {
    local username="$1"
    local min_days="${2:--1}"
    local max_days="${3:--1}"
    local warn_days="${4:--1}"
    local inactive_days="${5:--1}"
    local expire_date="${6:-}"
    
    local chage_args=()
    local changes_applied=()
    
    # Construction des arguments chage
    if [[ "$min_days" != "-1" ]]; then
        chage_args+=("-m" "$min_days")
        changes_applied+=("min_days:$min_days")
    fi
    
    if [[ "$max_days" != "-1" ]]; then
        chage_args+=("-M" "$max_days")
        changes_applied+=("max_days:$max_days")
    fi
    
    if [[ "$warn_days" != "-1" ]]; then
        chage_args+=("-W" "$warn_days")
        changes_applied+=("warn_days:$warn_days")
    fi
    
    if [[ "$inactive_days" != "-1" ]]; then
        chage_args+=("-I" "$inactive_days")
        changes_applied+=("inactive_days:$inactive_days")
    fi
    
    if [[ -n "$expire_date" ]]; then
        local days_since_epoch
        days_since_epoch=$(convert_date_to_days "$expire_date") || return 1
        chage_args+=("-E" "$days_since_epoch")
        changes_applied+=("expire_date:$expire_date")
    fi
    
    # Application des changements
    if [[ ${#chage_args[@]} -gt 0 ]]; then
        chage_args+=("$username")
        
        log_message "DEBUG" "Commande: chage ${chage_args[*]}"
        
        if chage "${chage_args[@]}" 2>/dev/null; then
            for change in "${changes_applied[@]}"; do
                log_message "INFO" "Appliqué - $change"
            done
            return 0
        else
            log_message "ERROR" "Échec modification politique pour: $username"
            return 1
        fi
    else
        log_message "WARN" "Aucune modification à appliquer"
        return 0
    fi
}

force_password_change() {
    local username="$1"
    
    # Forcer le changement au prochain login (expire immédiatement)
    if chage -d 0 "$username" 2>/dev/null; then
        log_message "INFO" "Changement de mot de passe forcé pour: $username"
        return 0
    else
        log_message "ERROR" "Échec forçage changement pour: $username"
        return 1
    fi
}

unlock_user_account() {
    local username="$1"
    
    # Déblocage du compte
    if passwd -u "$username" 2>/dev/null; then
        log_message "INFO" "Compte débloqué: $username"
        
        # Réinitialiser l'expiration si elle était à 0
        if chage -E -1 "$username" 2>/dev/null; then
            log_message "INFO" "Date d'expiration réinitialisée pour: $username"
        fi
        
        return 0
    else
        log_message "ERROR" "Échec déblocage compte: $username"
        return 1
    fi
}

get_all_regular_users() {
    local min_uid="${1:-1000}"
    local users=()
    
    # Récupération des utilisateurs avec UID >= min_uid
    while IFS=: read -r username _ uid _; do
        if [[ "$uid" -ge "$min_uid" ]]; then
            users+=("$username")
        fi
    done < /etc/passwd
    
    printf '%s\n' "${users[@]}"
}

calculate_password_status() {
    local username="$1"
    
    local status_info=()
    local current_date_days
    current_date_days=$(($(date +%s) / 86400))
    
    # Récupération des informations d'expiration
    local chage_output
    chage_output=$(chage -l "$username" 2>/dev/null || echo "")
    
    # Analyse de l'état du mot de passe
    local last_change_str max_days_str
    last_change_str=$(echo "$chage_output" | grep "Last password change" | cut -d: -f2 | xargs)
    max_days_str=$(echo "$chage_output" | grep "Maximum number of days" | cut -d: -f2 | xargs)
    
    if [[ "$last_change_str" == "never" ]]; then
        status_info+=("never_set")
    elif [[ "$max_days_str" == "99999" ]]; then
        status_info+=("no_expiration")
    else
        local last_change_days max_days
        last_change_days=$(date -d "$last_change_str" +%s 2>/dev/null || echo "0")
        last_change_days=$((last_change_days / 86400))
        max_days="$max_days_str"
        
        if [[ "$max_days" != "99999" && "$max_days" -gt 0 ]]; then
            local expiry_date=$((last_change_days + max_days))
            local days_until_expiry=$((expiry_date - current_date_days))
            
            if [[ $days_until_expiry -lt 0 ]]; then
                status_info+=("expired")
            elif [[ $days_until_expiry -le 7 ]]; then
                status_info+=("expires_soon:$days_until_expiry")
            else
                status_info+=("active:$days_until_expiry")
            fi
        else
            status_info+=("no_expiration")
        fi
    fi
    
    # Vérification du statut de blocage
    if passwd -S "$username" 2>/dev/null | grep -q " L "; then
        status_info+=("locked")
    fi
    
    printf '%s\n' "${status_info[@]}"
}

main() {
    local username=""
    local days=""
    local warn_days=""
    local inactive_days=""
    local min_days=""
    local max_days=""
    local expire_date=""
    local target_users=()
    
    # Analyse des arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -u|--user)
                username="$2"
                shift 2
                ;;
            -d|--days)
                days="$2"
                shift 2
                ;;
            -w|--warn-days)
                warn_days="$2"
                shift 2
                ;;
            -i|--inactive)
                inactive_days="$2"
                shift 2
                ;;
            -m|--min-days)
                min_days="$2"
                shift 2
                ;;
            -M|--max-days)
                max_days="$2"
                shift 2
                ;;
            -e|--expire-date)
                expire_date="$2"
                shift 2
                ;;
            --disable-expiry)
                max_days="99999"
                shift
                ;;
            --force-change)
                FORCE_CHANGE=1
                shift
                ;;
            --unlock)
                UNLOCK_ACCOUNT=1
                shift
                ;;
            --show-info)
                SHOW_INFO_ONLY=1
                shift
                ;;
            -a|--all-users)
                ALL_USERS=1
                shift
                ;;
            --exclude-system)
                EXCLUDE_SYSTEM=1
                shift
                ;;
            -b|--backup)
                BACKUP_POLICIES=1
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
    
    # Vérification des dépendances
    if ! check_dependencies; then
        echo '{"success": false, "error": "dependencies_missing", "message": "Required password tools not available"}'
        exit 1
    fi
    
    # Détermination des utilisateurs cibles
    if [[ "${ALL_USERS:-0}" == "1" ]]; then
        local min_uid=0
        [[ "${EXCLUDE_SYSTEM:-0}" == "1" ]] && min_uid=1000
        
        mapfile -t target_users < <(get_all_regular_users "$min_uid")
        log_message "INFO" "Traitement de ${#target_users[@]} utilisateurs"
    elif [[ -n "$username" ]]; then
        target_users=("$username")
    else
        log_message "ERROR" "Paramètre --user requis ou utiliser --all-users"
        show_help
        exit 1
    fi
    
    # Validation des utilisateurs
    for user in "${target_users[@]}"; do
        if ! validate_user "$user"; then
            echo '{"success": false, "error": "invalid_user", "message": "User validation failed", "user": "'$user'"}'
            exit 1
        fi
    done
    
    local start_time=$(date +%s)
    local backup_file=""
    local results=()
    
    # Sauvegarde si demandée
    if [[ "${BACKUP_POLICIES:-0}" == "1" ]]; then
        backup_file=$(backup_password_policies "${target_users[@]}") || true
    fi
    
    # Traitement de chaque utilisateur
    for user in "${target_users[@]}"; do
        local initial_policy
        initial_policy=$(get_current_password_policy "$user")
        
        # Mode information seulement
        if [[ "${SHOW_INFO_ONLY:-0}" == "1" ]]; then
            local status_info
            status_info=($(calculate_password_status "$user"))
            
            results+=("{\"user\": \"$user\", \"policy\": $initial_policy, \"status\": $(printf '%s\n' "${status_info[@]}" | jq -R . | jq -s .)}")
            continue
        fi
        
        local operation_success=true
        local operations_applied=()
        
        # Déblocage de compte si demandé
        if [[ "${UNLOCK_ACCOUNT:-0}" == "1" ]]; then
            if unlock_user_account "$user"; then
                operations_applied+=("unlocked")
            else
                operation_success=false
            fi
        fi
        
        # Forçage changement mot de passe
        if [[ "${FORCE_CHANGE:-0}" == "1" ]]; then
            if force_password_change "$user"; then
                operations_applied+=("force_change")
            else
                operation_success=false
            fi
        fi
        
        # Application de la politique d'expiration
        if [[ -n "$min_days" || -n "$max_days" || -n "$warn_days" || -n "$inactive_days" || -n "$expire_date" ]]; then
            # Utilisation des valeurs spécifiées ou des valeurs par défaut
            local final_min_days="${min_days:--1}"
            local final_max_days="${max_days:--1}"
            local final_warn_days="${warn_days:--1}"
            local final_inactive_days="${inactive_days:--1}"
            
            # Conversion des jours en max_days si spécifié via -d/--days
            if [[ -n "$days" ]]; then
                if [[ "$days" == "0" ]]; then
                    final_max_days="99999"  # Jamais
                elif [[ "$days" == "-1" ]]; then
                    final_max_days="0"      # Immédiate
                else
                    final_max_days="$days"
                fi
            fi
            
            if apply_password_expiry "$user" "$final_min_days" "$final_max_days" "$final_warn_days" "$final_inactive_days" "$expire_date"; then
                operations_applied+=("policy_updated")
            else
                operation_success=false
            fi
        fi
        
        local final_policy
        final_policy=$(get_current_password_policy "$user")
        
        local status_info
        status_info=($(calculate_password_status "$user"))
        
        results+=("{\"user\": \"$user\", \"success\": $($operation_success && echo "true" || echo "false"), \"operations\": $(printf '%s\n' "${operations_applied[@]}" | jq -R . | jq -s .), \"policy\": {\"before\": $initial_policy, \"after\": $final_policy}, \"status\": $(printf '%s\n' "${status_info[@]}" | jq -R . | jq -s .)}")
    done
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Génération du rapport JSON
    cat << EOF
{
    "success": true,
    "operation": "${SHOW_INFO_ONLY:+show_info}${FORCE_CHANGE:+force_change}${UNLOCK_ACCOUNT:+unlock}${max_days:+set_policy}",
    "users_processed": ${#target_users[@]},
    "all_users": ${ALL_USERS:-false},
    "exclude_system": ${EXCLUDE_SYSTEM:-false},
    "backup_file": "${backup_file:-null}",
    "duration_seconds": $duration,
    "results": [$(IFS=','; echo "${results[*]}")],
    "system_info": {
        "current_user": "$(id -un)",
        "is_root": $([[ $(id -u) -eq 0 ]] && echo "true" || echo "false"),
        "password_tools": {
            "chage": $(command -v chage >/dev/null && echo "true" || echo "false"),
            "passwd": $(command -v passwd >/dev/null && echo "true" || echo "false")
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