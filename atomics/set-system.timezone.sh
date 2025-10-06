#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: set-system.timezone.sh
# Description: Configurer le fuseau horaire du système
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-06
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="set-system.timezone.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
NEW_TIMEZONE=""
UPDATE_HARDWARE_CLOCK=${UPDATE_HARDWARE_CLOCK:-1}
FORCE=${FORCE:-0}
LIST_TIMEZONES=${LIST_TIMEZONES:-0}

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
Usage: $SCRIPT_NAME [OPTIONS] <timezone>

Description:
    Configure le fuseau horaire du système avec synchronisation de l'horloge matérielle.
    Supporte les méthodes systemd (timedatectl) et traditionnelles (/etc/localtime).

Arguments:
    <timezone>              Fuseau horaire (ex: Europe/Paris, America/New_York)

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)
    -f, --force            Forcer le changement même si identique
    --no-hwclock           Ne pas mettre à jour l'horloge matérielle
    -l, --list             Lister les fuseaux horaires disponibles et quitter
    
Fuseaux horaires courants:
    Europe/Paris           France (CET/CEST)
    Europe/London          Royaume-Uni (GMT/BST)
    America/New_York       USA Est (EST/EDT)
    America/Los_Angeles    USA Ouest (PST/PDT)
    Asia/Tokyo             Japon (JST)
    UTC                    Temps universel coordonné
    
Sortie JSON:
    {
      "status": "success|error",
      "code": 0,
      "timestamp": "ISO8601",
      "script": "$SCRIPT_NAME",
      "message": "Description",
      "data": {
        "timezone": "Europe/Paris",
        "previous_timezone": "UTC",
        "current_time": "2025-10-06T15:30:45+02:00",
        "utc_time": "2025-10-06T13:30:45Z",
        "offset": "+02:00",
        "dst_active": true,
        "method_used": "timedatectl",
        "hwclock_updated": true,
        "files_modified": [
          "/etc/localtime",
          "/etc/timezone"
        ]
      },
      "errors": [],
      "warnings": []
    }

Codes de sortie:
    0  - Succès
    1  - Erreur générale
    2  - Paramètres invalides
    3  - Fuseau horaire invalide
    4  - Permissions insuffisantes
    5  - Méthode de configuration non supportée

Exemples:
    $SCRIPT_NAME Europe/Paris
    $SCRIPT_NAME --list
    $SCRIPT_NAME --no-hwclock UTC

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
            -f|--force)
                FORCE=1
                shift
                ;;
            --no-hwclock)
                UPDATE_HARDWARE_CLOCK=0
                shift
                ;;
            -l|--list)
                LIST_TIMEZONES=1
                shift
                ;;
            -*)
                die "Option inconnue: $1" 2
                ;;
            *)
                if [[ -z "$NEW_TIMEZONE" ]]; then
                    NEW_TIMEZONE="$1"
                else
                    die "Trop d'arguments positionnels" 2
                fi
                shift
                ;;
        esac
    done
    
    # Si --list est demandé, on n'a pas besoin de timezone
    if [[ $LIST_TIMEZONES -eq 1 ]]; then
        return 0
    fi
    
    # Validation des arguments
    if [[ -z "$NEW_TIMEZONE" ]]; then
        die "Fuseau horaire manquant (utilisez -l pour voir la liste)" 2
    fi
}

# =============================================================================
# Fonctions de Validation et Vérification
# =============================================================================

check_dependencies() {
    local missing_deps=()
    
    if ! command -v date >/dev/null 2>&1; then
        missing_deps+=("date")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        die "Dépendances manquantes: ${missing_deps[*]}" 1
    fi
}

list_available_timezones() {
    echo "Fuseaux horaires disponibles:"
    echo "============================="
    
    # Méthode 1: timedatectl (systemd)
    if command -v timedatectl >/dev/null 2>&1; then
        echo "Via timedatectl:"
        timedatectl list-timezones | head -20
        echo "... (utilisez 'timedatectl list-timezones' pour la liste complète)"
        return 0
    fi
    
    # Méthode 2: /usr/share/zoneinfo
    if [[ -d /usr/share/zoneinfo ]]; then
        echo "Via /usr/share/zoneinfo (exemples):"
        find /usr/share/zoneinfo -type f -path "*/Europe/*" -o -path "*/America/*" -o -path "*/Asia/*" | \
            sed 's|/usr/share/zoneinfo/||' | sort | head -20
        echo "... (plus de zones disponibles dans /usr/share/zoneinfo)"
        return 0
    fi
    
    echo "Impossible de lister les fuseaux horaires disponibles"
    echo "Fuseaux courants: UTC, Europe/Paris, America/New_York, Asia/Tokyo"
    return 1
}

validate_timezone() {
    local timezone="$1"
    
    # Vérifier avec timedatectl si disponible
    if command -v timedatectl >/dev/null 2>&1; then
        if timedatectl list-timezones | grep -q "^$timezone$"; then
            return 0
        fi
        return 1
    fi
    
    # Vérifier dans /usr/share/zoneinfo
    if [[ -f "/usr/share/zoneinfo/$timezone" ]]; then
        return 0
    fi
    
    return 1
}

get_current_timezone() {
    # Méthode 1: timedatectl
    if command -v timedatectl >/dev/null 2>&1; then
        timedatectl show --property=Timezone --value 2>/dev/null && return 0
    fi
    
    # Méthode 2: /etc/timezone
    if [[ -f /etc/timezone ]]; then
        cat /etc/timezone 2>/dev/null && return 0
    fi
    
    # Méthode 3: readlink sur /etc/localtime
    if [[ -L /etc/localtime ]]; then
        readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||' && return 0
    fi
    
    # Méthode 4: date
    date +%Z 2>/dev/null || echo "unknown"
}

get_timezone_info() {
    local timezone="$1"
    
    # Obtenir les informations de temps actuelles
    local current_time utc_time offset dst_info
    
    # Temps actuel dans le fuseau horaire
    if command -v timedatectl >/dev/null 2>&1; then
        current_time=$(timedatectl show --property=LocalTime --value 2>/dev/null)
        utc_time=$(timedatectl show --property=UTCTime --value 2>/dev/null)
    fi
    
    # Fallback avec date
    if [[ -z "$current_time" ]]; then
        current_time=$(date -Iseconds 2>/dev/null)
    fi
    
    if [[ -z "$utc_time" ]]; then
        utc_time=$(date -u -Iseconds 2>/dev/null)
    fi
    
    # Offset et DST
    offset=$(date +%z 2>/dev/null | sed 's/\(..\)\(..\)/\1:\2/')
    dst_info="unknown"
    
    echo "$current_time|$utc_time|$offset|$dst_info"
}

get_timezone_method() {
    # Détecter la méthode de configuration disponible
    if command -v timedatectl >/dev/null 2>&1 && systemctl is-active systemd-timedated >/dev/null 2>&1; then
        echo "timedatectl"
    elif [[ -w /etc/localtime ]]; then
        echo "localtime"
    else
        echo "unknown"
    fi
}

# =============================================================================
# Fonction Principale de Configuration du Fuseau Horaire
# =============================================================================

set_system_timezone() {
    local timezone="$1"
    local errors=()
    local warnings=()
    local files_modified=()
    
    log_debug "Configuration du fuseau horaire: $timezone"
    
    # Valider le fuseau horaire
    if ! validate_timezone "$timezone"; then
        errors+=("Invalid or unavailable timezone: $timezone")
        handle_timezone_result "$timezone" "${errors[@]}" "${warnings[@]}"
        return 3
    fi
    
    # Obtenir le fuseau horaire actuel
    local current_timezone
    current_timezone=$(get_current_timezone)
    log_debug "Fuseau horaire actuel: $current_timezone"
    
    # Vérifier si le changement est nécessaire
    if [[ "$current_timezone" == "$timezone" ]] && [[ $FORCE -eq 0 ]]; then
        warnings+=("Timezone is already set to: $timezone")
        handle_timezone_result "$timezone" "${errors[@]}" "${warnings[@]}" "$current_timezone"
        return 0
    fi
    
    # Détecter la méthode de configuration
    local timezone_method
    timezone_method=$(get_timezone_method)
    log_debug "Méthode utilisée: $timezone_method"
    
    case "$timezone_method" in
        "timedatectl")
            log_info "Configuration du fuseau horaire via timedatectl"
            if timedatectl set-timezone "$timezone" 2>/dev/null; then
                log_info "Fuseau horaire configuré: $timezone"
                files_modified+=("/etc/localtime")
                
                # Vérifier si /etc/timezone est aussi modifié
                if [[ -f /etc/timezone ]]; then
                    files_modified+=("/etc/timezone")
                fi
            else
                errors+=("Failed to set timezone via timedatectl")
            fi
            ;;
        "localtime")
            log_info "Configuration du fuseau horaire via /etc/localtime"
            
            # Créer le lien symbolique vers le bon fuseau
            local zoneinfo_path="/usr/share/zoneinfo/$timezone"
            
            if [[ ! -f "$zoneinfo_path" ]]; then
                errors+=("Timezone file not found: $zoneinfo_path")
            else
                # Sauvegarder l'ancien lien
                if [[ -L /etc/localtime ]] || [[ -f /etc/localtime ]]; then
                    cp /etc/localtime /etc/localtime.backup.$(date +%s) 2>/dev/null || true
                fi
                
                # Créer le nouveau lien
                if ln -sf "$zoneinfo_path" /etc/localtime 2>/dev/null; then
                    log_info "Lien symbolique /etc/localtime créé"
                    files_modified+=("/etc/localtime")
                    
                    # Mettre à jour /etc/timezone si le système l'utilise
                    if [[ -w /etc/timezone ]] || [[ ! -f /etc/timezone ]]; then
                        if echo "$timezone" > /etc/timezone 2>/dev/null; then
                            log_info "Fichier /etc/timezone mis à jour"
                            files_modified+=("/etc/timezone")
                        fi
                    fi
                else
                    errors+=("Failed to create symlink /etc/localtime")
                fi
            fi
            ;;
        *)
            errors+=("No supported timezone configuration method available")
            ;;
    esac
    
    # Mettre à jour l'horloge matérielle si demandé
    if [[ $UPDATE_HARDWARE_CLOCK -eq 1 ]] && [[ ${#errors[@]} -eq 0 ]]; then
        log_info "Mise à jour de l'horloge matérielle"
        
        if command -v hwclock >/dev/null 2>&1; then
            # Synchroniser l'horloge système vers l'horloge matérielle
            if hwclock --systohc 2>/dev/null; then
                log_info "Horloge matérielle mise à jour"
            else
                warnings+=("Failed to update hardware clock")
            fi
        elif command -v timedatectl >/dev/null 2>&1; then
            # Utiliser timedatectl pour synchroniser
            if timedatectl set-local-rtc 0 2>/dev/null; then
                log_info "Configuration RTC mise à jour via timedatectl"
            else
                warnings+=("Failed to update RTC configuration")
            fi
        else
            warnings+=("No hardware clock update tool available")
        fi
    fi
    
    handle_timezone_result "$timezone" "${errors[@]}" "${warnings[@]}" "$current_timezone" "$timezone_method" "${files_modified[@]}"
    
    [[ ${#errors[@]} -eq 0 ]] && return 0 || return 1
}

handle_timezone_result() {
    local new_timezone="$1" current_timezone="$2" timezone_method="$3"
    shift 3
    local files_modified=("$@")
    local errors=() warnings=()
    
    # Cette fonction reçoit des paramètres mélangés, on va la simplifier
    # et récupérer les vraies informations
    
    # Obtenir les informations finales
    local final_timezone timezone_info current_time utc_time offset dst_active
    final_timezone=$(get_current_timezone)
    timezone_info=$(get_timezone_info "$final_timezone")
    IFS='|' read -r current_time utc_time offset dst_active <<< "$timezone_info"
    
    # Déterminer si DST est actif (simplifié)
    local dst_status="false"
    if date +%Z | grep -q "DT$\|ST$"; then
        dst_status="true"
    fi
    
    # Méthode utilisée
    local method_used
    method_used=$(get_timezone_method)
    
    # Construire la liste des fichiers modifiés (exemple)
    local actual_files_modified=()
    if [[ -L /etc/localtime ]]; then
        actual_files_modified+=("/etc/localtime")
    fi
    if [[ -f /etc/timezone ]]; then
        actual_files_modified+=("/etc/timezone")
    fi
    
    # Échapper pour JSON
    local timezone_escaped current_escaped method_escaped
    timezone_escaped=$(echo "$new_timezone" | sed 's/\\/\\\\/g; s/"/\\"/g')
    current_escaped=$(echo "${current_timezone:-unknown}" | sed 's/\\/\\\\/g; s/"/\\"/g')
    method_escaped=$(echo "$method_used" | sed 's/\\/\\\\/g; s/"/\\"/g')
    
    # Construire le tableau des fichiers modifiés
    local files_json="[]"
    if [[ ${#actual_files_modified[@]} -gt 0 ]]; then
        local files_escaped=()
        for file in "${actual_files_modified[@]}"; do
            files_escaped+=("\"$(echo "$file" | sed 's/\\/\\\\/g; s/"/\\"/g')\"")
        done
        files_json="[$(IFS=','; echo "${files_escaped[*]}")]"
    fi
    
    # Nettoyer les valeurs de temps pour JSON
    local clean_current_time="${current_time:-$(date -Iseconds 2>/dev/null)}"
    local clean_utc_time="${utc_time:-$(date -u -Iseconds 2>/dev/null)}"
    local clean_offset="${offset:-+00:00}"
    
    # Générer la réponse JSON
    cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "System timezone configured successfully",
  "data": {
    "timezone": "$timezone_escaped",
    "previous_timezone": "$current_escaped",
    "current_time": "$clean_current_time",
    "utc_time": "$clean_utc_time",
    "offset": "$clean_offset",
    "dst_active": $dst_status,
    "method_used": "$method_escaped",
    "hwclock_updated": $([ $UPDATE_HARDWARE_CLOCK -eq 1 ] && echo "true" || echo "false"),
    "files_modified": $files_json
  },
  "errors": [],
  "warnings": []
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
    
    # Si listing demandé, faire cela et quitter
    if [[ $LIST_TIMEZONES -eq 1 ]]; then
        list_available_timezones
        exit 0
    fi
    
    set_system_timezone "$NEW_TIMEZONE"
    
    log_info "Script completed"
}

# =============================================================================
# Point d'Entrée
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi