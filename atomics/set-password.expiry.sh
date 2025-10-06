#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: set-password.expiry.sh
# Description: Configurer l'expiration du mot de passe d'un utilisateur
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-06
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="set-password.expiry.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
USERNAME=""
EXPIRY_DATE=""
MAX_DAYS=""
MIN_DAYS=""
WARN_DAYS=""
INACTIVE_DAYS=""
DISABLE_EXPIRY=${DISABLE_EXPIRY:-0}

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
Usage: $SCRIPT_NAME [OPTIONS] <username> [expiry_date]

Description:
    Configure les paramètres d'expiration du mot de passe pour un utilisateur.
    Permet de définir la date d'expiration et les paramètres de vieillissement du mot de passe.

Arguments:
    <username>              Nom d'utilisateur (obligatoire)
    [expiry_date]          Date d'expiration (YYYY-MM-DD ou nombre de jours depuis epoch)

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)
    --max-days DAYS        Nombre maximum de jours avant expiration (défaut: système)
    --min-days DAYS        Nombre minimum de jours entre changements (défaut: 0)
    --warn-days DAYS       Nombre de jours d'avertissement avant expiration (défaut: 7)
    --inactive-days DAYS   Nombre de jours avant désactivation après expiration
    --disable-expiry       Désactiver l'expiration du mot de passe
    
Formats de date acceptés:
    YYYY-MM-DD             Format ISO (ex: 2025-12-31)
    +DAYS                  Nombre de jours à partir d'aujourd'hui (ex: +90)
    EPOCH                  Nombre de jours depuis le 1er janvier 1970
    never                  Aucune expiration (équivalent à --disable-expiry)
    
Sortie JSON:
    {
      "status": "success|error",
      "code": 0,
      "timestamp": "ISO8601",
      "script": "$SCRIPT_NAME",
      "message": "Description",
      "data": {
        "username": "john",
        "expiry_date": "2025-12-31",
        "expiry_epoch": 20454,
        "password_aging": {
          "max_days": 90,
          "min_days": 0,
          "warn_days": 7,
          "inactive_days": -1
        },
        "previous_settings": {
          "expiry_date": "never",
          "max_days": 99999
        },
        "expiry_disabled": false
      },
      "errors": [],
      "warnings": []
    }

Codes de sortie:
    0  - Succès
    1  - Erreur générale
    2  - Paramètres invalides
    3  - Utilisateur non trouvé
    4  - Permissions insuffisantes
    5  - Date invalide

Exemples:
    $SCRIPT_NAME john 2025-12-31
    $SCRIPT_NAME --max-days 90 --warn-days 14 alice
    $SCRIPT_NAME --disable-expiry bob
    $SCRIPT_NAME jane +90

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
            --max-days)
                if [[ -n "${2:-}" ]]; then
                    MAX_DAYS="$2"
                    shift 2
                else
                    die "Nombre de jours manquant pour --max-days" 2
                fi
                ;;
            --min-days)
                if [[ -n "${2:-}" ]]; then
                    MIN_DAYS="$2"
                    shift 2
                else
                    die "Nombre de jours manquant pour --min-days" 2
                fi
                ;;
            --warn-days)
                if [[ -n "${2:-}" ]]; then
                    WARN_DAYS="$2"
                    shift 2
                else
                    die "Nombre de jours manquant pour --warn-days" 2
                fi
                ;;
            --inactive-days)
                if [[ -n "${2:-}" ]]; then
                    INACTIVE_DAYS="$2"
                    shift 2
                else
                    die "Nombre de jours manquant pour --inactive-days" 2
                fi
                ;;
            --disable-expiry)
                DISABLE_EXPIRY=1
                shift
                ;;
            -*)
                die "Option inconnue: $1" 2
                ;;
            *)
                if [[ -z "$USERNAME" ]]; then
                    USERNAME="$1"
                elif [[ -z "$EXPIRY_DATE" ]]; then
                    EXPIRY_DATE="$1"
                else
                    die "Trop d'arguments positionnels" 2
                fi
                shift
                ;;
        esac
    done
    
    # Validation des arguments
    if [[ -z "$USERNAME" ]]; then
        die "Nom d'utilisateur manquant" 2
    fi
    
    if [[ $DISABLE_EXPIRY -eq 1 ]] && [[ -n "$EXPIRY_DATE" ]]; then
        die "Impossible de spécifier une date d'expiration avec --disable-expiry" 2
    fi
    
    # Valider les nombres de jours si spécifiés
    for days_var in MAX_DAYS MIN_DAYS WARN_DAYS INACTIVE_DAYS; do
        local days_value="${!days_var}"
        if [[ -n "$days_value" ]] && ! [[ "$days_value" =~ ^[0-9]+$ ]] && [[ "$days_value" != "-1" ]]; then
            die "Valeur invalide pour $days_var: $days_value (doit être un nombre positif ou -1)" 2
        fi
    done
}

# =============================================================================
# Fonctions de Validation et Vérification
# =============================================================================

check_dependencies() {
    local missing_deps=()
    
    if ! command -v chage >/dev/null 2>&1; then
        missing_deps+=("chage")
    fi
    
    if ! command -v passwd >/dev/null 2>&1; then
        missing_deps+=("passwd")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        die "Dépendances manquantes: ${missing_deps[*]}" 1
    fi
}

check_user_exists() {
    local user="$1"
    
    if id "$user" >/dev/null 2>&1; then
        return 0
    fi
    
    return 1
}

validate_date_format() {
    local date_input="$1"
    
    # Cas spéciaux
    if [[ "$date_input" == "never" ]] || [[ "$date_input" == "" ]]; then
        return 0
    fi
    
    # Format +DAYS (relatif)
    if [[ "$date_input" =~ ^[+]([0-9]+)$ ]]; then
        return 0
    fi
    
    # Format EPOCH (nombre de jours depuis 1970-01-01)
    if [[ "$date_input" =~ ^[0-9]+$ ]]; then
        return 0
    fi
    
    # Format YYYY-MM-DD
    if [[ "$date_input" =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2})$ ]]; then
        local year="${BASH_REMATCH[1]}"
        local month="${BASH_REMATCH[2]}"
        local day="${BASH_REMATCH[3]}"
        
        # Validation basique des ranges
        if [[ $year -lt 1970 ]] || [[ $year -gt 2099 ]]; then
            return 1
        fi
        
        if [[ $month -lt 1 ]] || [[ $month -gt 12 ]]; then
            return 1
        fi
        
        if [[ $day -lt 1 ]] || [[ $day -gt 31 ]]; then
            return 1
        fi
        
        # Vérifier que la date est valide avec la commande date
        if date -d "$date_input" >/dev/null 2>&1; then
            return 0
        fi
        
        return 1
    fi
    
    return 1
}

convert_date_to_epoch() {
    local date_input="$1"
    
    # Cas spéciaux
    if [[ "$date_input" == "never" ]] || [[ "$date_input" == "" ]]; then
        echo "-1"
        return 0
    fi
    
    # Format +DAYS (relatif à aujourd'hui)
    if [[ "$date_input" =~ ^[+]([0-9]+)$ ]]; then
        local days="${BASH_REMATCH[1]}"
        local current_epoch_days
        current_epoch_days=$(( $(date +%s) / 86400 ))
        echo $((current_epoch_days + days))
        return 0
    fi
    
    # Format EPOCH (déjà en jours depuis 1970-01-01)
    if [[ "$date_input" =~ ^[0-9]+$ ]]; then
        echo "$date_input"
        return 0
    fi
    
    # Format YYYY-MM-DD
    if [[ "$date_input" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        # Convertir en secondes depuis epoch puis en jours
        local epoch_seconds
        epoch_seconds=$(date -d "$date_input" +%s 2>/dev/null)
        if [[ -n "$epoch_seconds" ]]; then
            echo $((epoch_seconds / 86400))
            return 0
        fi
    fi
    
    return 1
}

get_current_password_aging() {
    local user="$1"
    local aging_info
    
    # Obtenir les informations de vieillissement actuelles
    aging_info=$(chage -l "$user" 2>/dev/null)
    
    if [[ -z "$aging_info" ]]; then
        echo "unknown|unknown|unknown|unknown|unknown"
        return 1
    fi
    
    # Parser les informations
    local last_change expiry_date min_days max_days warn_days inactive_days
    
    last_change=$(echo "$aging_info" | grep "Last password change" | cut -d: -f2 | xargs)
    expiry_date=$(echo "$aging_info" | grep "Password expires" | cut -d: -f2 | xargs)
    min_days=$(echo "$aging_info" | grep "Minimum number of days" | cut -d: -f2 | xargs)
    max_days=$(echo "$aging_info" | grep "Maximum number of days" | cut -d: -f2 | xargs)
    warn_days=$(echo "$aging_info" | grep "Number of days of warning" | cut -d: -f2 | xargs)
    inactive_days=$(echo "$aging_info" | grep "Password inactive" | cut -d: -f2 | xargs)
    
    echo "$expiry_date|$max_days|$min_days|$warn_days|$inactive_days"
}

# =============================================================================
# Fonction Principale de Configuration de l'Expiration
# =============================================================================

set_password_expiry() {
    local user="$1"
    local expiry="$2"
    local errors=()
    local warnings=()
    
    log_debug "Configuration expiration mot de passe pour: $user"
    log_debug "Expiration: $expiry"
    
    # Vérifier que l'utilisateur existe
    if ! check_user_exists "$user"; then
        errors+=("User not found: $user")
        handle_result "$user" "$expiry" "${errors[@]}" "${warnings[@]}"
        return 3
    fi
    
    # Obtenir les paramètres actuels
    local current_aging current_expiry current_max current_min current_warn current_inactive
    current_aging=$(get_current_password_aging "$user")
    IFS='|' read -r current_expiry current_max current_min current_warn current_inactive <<< "$current_aging"
    
    # Traitement de la date d'expiration
    local expiry_epoch_days=""
    
    if [[ $DISABLE_EXPIRY -eq 1 ]]; then
        expiry_epoch_days="-1"
        log_info "Désactivation de l'expiration du mot de passe"
    elif [[ -n "$expiry" ]]; then
        if ! validate_date_format "$expiry"; then
            errors+=("Invalid date format: $expiry")
        else
            if ! expiry_epoch_days=$(convert_date_to_epoch "$expiry"); then
                errors+=("Failed to convert date to epoch format: $expiry")
            fi
        fi
    fi
    
    if [[ ${#errors[@]} -eq 0 ]]; then
        # Construire la commande chage
        local chage_cmd="chage"
        local changes_made=()
        
        # Date d'expiration
        if [[ -n "$expiry_epoch_days" ]]; then
            if [[ "$expiry_epoch_days" == "-1" ]]; then
                chage_cmd+=" -E -1"
                changes_made+=("expiry disabled")
            else
                chage_cmd+=" -E $expiry_epoch_days"
                changes_made+=("expiry date set")
            fi
        fi
        
        # Nombre maximum de jours
        if [[ -n "$MAX_DAYS" ]]; then
            chage_cmd+=" -M $MAX_DAYS"
            changes_made+=("max days: $MAX_DAYS")
        fi
        
        # Nombre minimum de jours
        if [[ -n "$MIN_DAYS" ]]; then
            chage_cmd+=" -m $MIN_DAYS"
            changes_made+=("min days: $MIN_DAYS")
        fi
        
        # Jours d'avertissement
        if [[ -n "$WARN_DAYS" ]]; then
            chage_cmd+=" -W $WARN_DAYS"
            changes_made+=("warning days: $WARN_DAYS")
        fi
        
        # Jours d'inactivité
        if [[ -n "$INACTIVE_DAYS" ]]; then
            chage_cmd+=" -I $INACTIVE_DAYS"
            changes_made+=("inactive days: $INACTIVE_DAYS")
        fi
        
        chage_cmd+=" $user"
        
        log_debug "Commande chage: $chage_cmd"
        log_info "Modifications: ${changes_made[*]}"
        
        # Exécuter la commande
        if eval "$chage_cmd" 2>/dev/null; then
            log_info "Paramètres d'expiration modifiés avec succès"
            
            # Vérifier que les changements ont été appliqués
            local new_aging new_expiry new_max new_min new_warn new_inactive
            new_aging=$(get_current_password_aging "$user")
            IFS='|' read -r new_expiry new_max new_min new_warn new_inactive <<< "$new_aging"
            
            if [[ "$new_aging" == "$current_aging" ]] && [[ ${#changes_made[@]} -gt 0 ]]; then
                warnings+=("Password aging settings may not have changed as expected")
            fi
        else
            local exit_code=$?
            case $exit_code in
                1) errors+=("Permission denied - insufficient privileges") ;;
                2) errors+=("Invalid arguments or user") ;;
                *) errors+=("Failed to modify password aging settings (exit code: $exit_code)") ;;
            esac
        fi
    fi
    
    handle_result "$user" "$expiry" "${errors[@]}" "${warnings[@]}" "$current_aging"
    
    [[ ${#errors[@]} -eq 0 ]] && return 0 || return 1
}

handle_result() {
    local user="$1" expiry="$2" current_aging="$3"
    shift 3
    local errors=("$@")
    local warnings=()
    
    # Séparer erreurs et warnings
    local actual_errors=()
    for item in "${errors[@]}"; do
        if [[ "$item" =~ ^WARNING: ]]; then
            warnings+=("${item#WARNING: }")
        else
            actual_errors+=("$item")
        fi
    done
    
    # Obtenir les paramètres après modification
    local final_aging final_expiry final_max final_min final_warn final_inactive
    final_aging=$(get_current_password_aging "$user")
    IFS='|' read -r final_expiry final_max final_min final_warn final_inactive <<< "$final_aging"
    
    # Parser les paramètres précédents
    local current_expiry current_max current_min current_warn current_inactive
    IFS='|' read -r current_expiry current_max current_min current_warn current_inactive <<< "$current_aging"
    
    # Convertir la date d'expiration actuelle en format lisible
    local expiry_date_readable="never"
    local expiry_epoch="-1"
    
    if [[ -n "$expiry" ]] && [[ "$expiry" != "never" ]]; then
        if expiry_epoch=$(convert_date_to_epoch "$expiry" 2>/dev/null); then
            if [[ "$expiry_epoch" != "-1" ]]; then
                expiry_date_readable="$expiry"
            fi
        fi
    fi
    
    # Échapper pour JSON
    local user_escaped expiry_escaped
    user_escaped=$(echo "$user" | sed 's/\\/\\\\/g; s/"/\\"/g')
    expiry_escaped=$(echo "${expiry:-}" | sed 's/\\/\\\\/g; s/"/\\"/g')
    
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
    local message="Password expiry settings configured successfully"
    
    if [[ ${#actual_errors[@]} -gt 0 ]]; then
        status="error"
        code=1
        message="Failed to configure password expiry settings"
    fi
    
    # Nettoyer les valeurs pour JSON (remplacer "never" par des valeurs par défaut)
    local clean_final_max="${final_max:-99999}"
    local clean_final_min="${final_min:-0}"
    local clean_final_warn="${final_warn:-7}"
    local clean_final_inactive="${final_inactive:--1}"
    
    local clean_current_max="${current_max:-99999}"
    local clean_current_min="${current_min:-0}"
    local clean_current_warn="${current_warn:-7}"
    local clean_current_inactive="${current_inactive:--1}"
    
    # Générer la réponse JSON
    cat << EOF
{
  "status": "$status",
  "code": $code,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "$message",
  "data": {
    "username": "$user_escaped",
    "expiry_date": "$expiry_date_readable",
    "expiry_epoch": $expiry_epoch,
    "password_aging": {
      "max_days": $clean_final_max,
      "min_days": $clean_final_min,
      "warn_days": $clean_final_warn,
      "inactive_days": $clean_final_inactive
    },
    "previous_settings": {
      "expiry_date": "$current_expiry",
      "max_days": $clean_current_max,
      "min_days": $clean_current_min,
      "warn_days": $clean_current_warn,
      "inactive_days": $clean_current_inactive
    },
    "expiry_disabled": $([ $DISABLE_EXPIRY -eq 1 ] && echo "true" || echo "false")
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
    set_password_expiry "$USERNAME" "$EXPIRY_DATE"
    
    log_info "Script completed"
}

# =============================================================================
# Point d'Entrée
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi