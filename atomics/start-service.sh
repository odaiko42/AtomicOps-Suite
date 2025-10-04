#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: start-service.sh
# Description: Démarre un service système avec validation
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-04
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="start-service.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
FORCE=${FORCE:-0}
WAIT_TIMEOUT=${WAIT_TIMEOUT:-30}
SERVICE_NAME=""

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
Usage: $SCRIPT_NAME [OPTIONS] <service_name>

Description:
    Démarre un service système avec validation du statut et gestion d'erreurs.
    Compatible avec systemd, SysV init et autres gestionnaires de services.

Arguments:
    <service_name>          Nom du service à démarrer (obligatoire)

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)
    -f, --force            Forcer le démarrage même si déjà actif
    -w, --wait SECONDS     Timeout d'attente de démarrage (défaut: 30s)
    
Sortie JSON:
    {
      "status": "success|error",
      "code": 0,
      "timestamp": "ISO8601",
      "script": "$SCRIPT_NAME",
      "message": "Description",
      "data": {
        "service_name": "apache2",
        "action": "start",
        "previous_status": "inactive",
        "current_status": "active",
        "startup_time_ms": 1500,
        "enabled_at_boot": true,
        "pid": 1234,
        "service_manager": "systemd"
      },
      "errors": [],
      "warnings": []
    }

Codes de sortie:
    0 - Succès (service démarré)
    1 - Erreur générale
    2 - Erreur de paramètres
    3 - Service non trouvé
    4 - Permissions insuffisantes
    5 - Échec de démarrage
    6 - Timeout de démarrage

Exemples:
    $SCRIPT_NAME apache2                           # Démarrer Apache
    $SCRIPT_NAME --force --wait 60 nginx          # Forcer avec timeout
    $SCRIPT_NAME --json-only ssh                  # JSON seulement
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
            -w|--wait)
                if [[ -n "${2:-}" && "$2" =~ ^[0-9]+$ ]]; then
                    WAIT_TIMEOUT="$2"
                    shift 2
                else
                    die "Option --wait nécessite un nombre entier en secondes" 2
                fi
                ;;
            -*)
                die "Option inconnue: $1. Utilisez -h pour l'aide." 2
                ;;
            *)
                if [[ -z "$SERVICE_NAME" ]]; then
                    SERVICE_NAME="$1"
                else
                    die "Trop d'arguments. Service déjà spécifié: $SERVICE_NAME" 2
                fi
                shift
                ;;
        esac
    done

    # Validation des paramètres obligatoires
    if [[ -z "$SERVICE_NAME" ]]; then
        die "Nom de service obligatoire manquant. Utilisez -h pour l'aide." 2
    fi
}

# =============================================================================
# Fonctions Métier
# =============================================================================

check_dependencies() {
    local missing=()
    
    # Vérifier les gestionnaires de services disponibles
    if ! command -v systemctl >/dev/null 2>&1 && 
       ! command -v service >/dev/null 2>&1 && 
       ! command -v rc-service >/dev/null 2>&1; then
        missing+=("systemctl ou service ou rc-service")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Gestionnaires de service manquants: ${missing[*]}" 3
    fi
    
    log_debug "Dépendances vérifiées avec succès"
}

detect_service_manager() {
    if command -v systemctl >/dev/null 2>&1 && systemctl --version >/dev/null 2>&1; then
        echo "systemd"
    elif command -v service >/dev/null 2>&1; then
        echo "sysv"
    elif command -v rc-service >/dev/null 2>&1; then
        echo "openrc"
    else
        echo "unknown"
    fi
}

get_service_status() {
    local service_name="$1"
    local service_manager="$2"
    
    case "$service_manager" in
        systemd)
            if systemctl is-active "$service_name" >/dev/null 2>&1; then
                echo "active"
            elif systemctl is-failed "$service_name" >/dev/null 2>&1; then
                echo "failed"
            else
                echo "inactive"
            fi
            ;;
        sysv)
            if service "$service_name" status >/dev/null 2>&1; then
                echo "active"
            else
                echo "inactive"
            fi
            ;;
        openrc)
            if rc-service "$service_name" status >/dev/null 2>&1; then
                echo "active"
            else
                echo "inactive"
            fi
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

get_service_pid() {
    local service_name="$1"
    local service_manager="$2"
    
    case "$service_manager" in
        systemd)
            systemctl show "$service_name" --property=MainPID --value 2>/dev/null || echo "0"
            ;;
        *)
            # Essayer de trouver via ps
            pgrep -f "$service_name" | head -n1 2>/dev/null || echo "0"
            ;;
    esac
}

is_service_enabled() {
    local service_name="$1"
    local service_manager="$2"
    
    case "$service_manager" in
        systemd)
            systemctl is-enabled "$service_name" >/dev/null 2>&1
            ;;
        sysv)
            # Vérifier les liens dans /etc/rc*.d/
            ls /etc/rc*.d/S*"$service_name" >/dev/null 2>&1
            ;;
        openrc)
            rc-update show | grep -q "$service_name"
            ;;
        *)
            return 1
            ;;
    esac
}

start_service_systemd() {
    local service_name="$1"
    systemctl start "$service_name" 2>/dev/null
}

start_service_sysv() {
    local service_name="$1"
    service "$service_name" start >/dev/null 2>&1
}

start_service_openrc() {
    local service_name="$1"
    rc-service "$service_name" start >/dev/null 2>&1
}

wait_for_service() {
    local service_name="$1"
    local service_manager="$2"
    local timeout="$3"
    local waited=0
    
    log_debug "Attente du démarrage du service (timeout: ${timeout}s)"
    
    while [[ $waited -lt $timeout ]]; do
        local status
        status=$(get_service_status "$service_name" "$service_manager")
        
        if [[ "$status" == "active" ]]; then
            log_debug "Service démarré après ${waited}s"
            return 0
        fi
        
        sleep 1
        ((waited++))
    done
    
    log_warn "Timeout atteint après ${timeout}s"
    return 1
}

start_service() {
    local service_name="$1"
    
    log_debug "Démarrage du service: $service_name"
    
    # Détecter le gestionnaire de services
    local service_manager
    service_manager=$(detect_service_manager)
    log_debug "Gestionnaire de services détecté: $service_manager"
    
    # Obtenir le statut initial
    local previous_status
    previous_status=$(get_service_status "$service_name" "$service_manager")
    log_debug "Statut initial: $previous_status"
    
    # Vérifier si le service est déjà actif
    if [[ "$previous_status" == "active" && $FORCE -eq 0 ]]; then
        log_warn "Service déjà actif. Utilisez --force pour forcer le redémarrage."
    fi
    
    # Vérifier si le service est activé au boot
    local enabled_at_boot
    if is_service_enabled "$service_name" "$service_manager"; then
        enabled_at_boot="true"
    else
        enabled_at_boot="false"
    fi
    
    # Démarrer le service
    local start_time start_result startup_time_ms
    start_time=$(date +%s%3N)
    start_result=0
    
    log_info "Démarrage du service $service_name..."
    
    case "$service_manager" in
        systemd)
            start_service_systemd "$service_name" || start_result=1
            ;;
        sysv)
            start_service_sysv "$service_name" || start_result=1
            ;;
        openrc)
            start_service_openrc "$service_name" || start_result=1
            ;;
        *)
            die "Gestionnaire de services non supporté: $service_manager" 3
            ;;
    esac
    
    if [[ $start_result -ne 0 ]]; then
        die "Échec du démarrage du service $service_name" 5
    fi
    
    # Attendre que le service soit actif
    if ! wait_for_service "$service_name" "$service_manager" "$WAIT_TIMEOUT"; then
        die "Timeout: le service n'a pas démarré dans les ${WAIT_TIMEOUT}s" 6
    fi
    
    # Calculer le temps de démarrage
    local end_time
    end_time=$(date +%s%3N)
    startup_time_ms=$((end_time - start_time))
    
    # Obtenir le statut final et PID
    local current_status pid
    current_status=$(get_service_status "$service_name" "$service_manager")
    pid=$(get_service_pid "$service_name" "$service_manager")
    
    log_info "Service $service_name démarré avec succès"
    log_debug "PID: $pid, Temps de démarrage: ${startup_time_ms}ms"
    
    # Échapper le nom du service pour JSON
    local service_name_escaped
    service_name_escaped=$(echo "$service_name" | sed 's/\\/\\\\/g; s/"/\\"/g')
    
    # Générer la réponse JSON
    cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Service started successfully",
  "data": {
    "service_name": "$service_name_escaped",
    "action": "start",
    "previous_status": "$previous_status",
    "current_status": "$current_status",
    "startup_time_ms": $startup_time_ms,
    "enabled_at_boot": $enabled_at_boot,
    "pid": $pid,
    "service_manager": "$service_manager",
    "wait_timeout": $WAIT_TIMEOUT,
    "forced": $([ $FORCE -eq 1 ] && echo "true" || echo "false")
  },
  "errors": [],
  "warnings": []
}
EOF
    
    log_debug "Démarrage terminé avec succès"
}

# =============================================================================
# Fonction Principale
# =============================================================================

main() {
    log_debug "Démarrage de $SCRIPT_NAME v$SCRIPT_VERSION"
    
    parse_args "$@"
    check_dependencies
    start_service "$SERVICE_NAME"
    
    log_info "Script completed successfully"
}

# =============================================================================
# Point d'Entrée
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi