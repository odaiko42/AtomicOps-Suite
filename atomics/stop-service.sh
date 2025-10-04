#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: stop-service.sh
# Description: Arrête un service système avec confirmation de sécurité
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-04
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="stop-service.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
FORCE=${FORCE:-0}
KILL_FORCE=${KILL_FORCE:-0}
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
    Arrête un service système avec confirmation et gestion de l'arrêt forcé.
    Compatible avec systemd, SysV init et autres gestionnaires de services.

Arguments:
    <service_name>          Nom du service à arrêter (obligatoire)

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)
    -f, --force            Forcer l'arrêt sans confirmation
    -k, --kill             Utiliser kill -9 si arrêt normal échoue
    -w, --wait SECONDS     Timeout d'attente d'arrêt (défaut: 30s)
    
Sortie JSON:
    {
      "status": "success|error",
      "code": 0,
      "timestamp": "ISO8601",
      "script": "$SCRIPT_NAME",
      "message": "Description",
      "data": {
        "service_name": "apache2",
        "action": "stop",
        "previous_status": "active",
        "current_status": "inactive",
        "shutdown_time_ms": 1200,
        "method_used": "graceful",
        "pid_terminated": 1234,
        "service_manager": "systemd"
      },
      "errors": [],
      "warnings": []
    }

Codes de sortie:
    0 - Succès (service arrêté)
    1 - Erreur générale
    2 - Erreur de paramètres
    3 - Service non trouvé
    4 - Permissions insuffisantes
    5 - Échec d'arrêt
    6 - Timeout d'arrêt

Exemples:
    $SCRIPT_NAME apache2                           # Arrêter Apache
    $SCRIPT_NAME --force --kill nginx             # Forcer avec kill
    $SCRIPT_NAME --json-only --wait 60 ssh       # JSON avec timeout
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
            -k|--kill)
                KILL_FORCE=1
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
# Fonctions Métier (réutilisées de start-service.sh)
# =============================================================================

check_dependencies() {
    local missing=()
    
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
            pgrep -f "$service_name" | head -n1 2>/dev/null || echo "0"
            ;;
    esac
}

stop_service_systemd() {
    local service_name="$1"
    systemctl stop "$service_name" 2>/dev/null
}

stop_service_sysv() {
    local service_name="$1"
    service "$service_name" stop >/dev/null 2>&1
}

stop_service_openrc() {
    local service_name="$1"
    rc-service "$service_name" stop >/dev/null 2>&1
}

kill_service_by_pid() {
    local pid="$1"
    local signal="${2:-TERM}"
    
    if [[ "$pid" != "0" ]] && kill -0 "$pid" 2>/dev/null; then
        log_debug "Envoi du signal $signal au PID $pid"
        kill -"$signal" "$pid" 2>/dev/null || return 1
        return 0
    fi
    return 1
}

wait_for_service_stop() {
    local service_name="$1"
    local service_manager="$2"
    local timeout="$3"
    local waited=0
    
    log_debug "Attente de l'arrêt du service (timeout: ${timeout}s)"
    
    while [[ $waited -lt $timeout ]]; do
        local status
        status=$(get_service_status "$service_name" "$service_manager")
        
        if [[ "$status" == "inactive" ]]; then
            log_debug "Service arrêté après ${waited}s"
            return 0
        fi
        
        sleep 1
        ((waited++))
    done
    
    log_warn "Timeout atteint après ${timeout}s"
    return 1
}

confirm_stop() {
    local service_name="$1"
    
    if [[ $FORCE -eq 1 || $JSON_ONLY -eq 1 ]]; then
        return 0
    fi
    
    echo "Êtes-vous sûr de vouloir arrêter le service '$service_name' ? (o/N)"
    read -r confirmation
    
    case "$confirmation" in
        o|O|oui|OUI|y|Y|yes|YES)
            return 0
            ;;
        *)
            die "Arrêt annulé par l'utilisateur" 6
            ;;
    esac
}

stop_service() {
    local service_name="$1"
    
    log_debug "Arrêt du service: $service_name"
    
    # Détecter le gestionnaire de services
    local service_manager
    service_manager=$(detect_service_manager)
    log_debug "Gestionnaire de services détecté: $service_manager"
    
    # Obtenir le statut initial et PID
    local previous_status initial_pid
    previous_status=$(get_service_status "$service_name" "$service_manager")
    initial_pid=$(get_service_pid "$service_name" "$service_manager")
    log_debug "Statut initial: $previous_status, PID: $initial_pid"
    
    # Vérifier si le service est déjà inactif
    if [[ "$previous_status" == "inactive" ]]; then
        log_warn "Service déjà inactif"
    else
        # Demander confirmation
        confirm_stop "$service_name"
    fi
    
    # Arrêter le service
    local stop_time stop_result shutdown_time_ms method_used
    stop_time=$(date +%s%3N)
    stop_result=0
    method_used="graceful"
    
    log_info "Arrêt du service $service_name..."
    
    # Tentative d'arrêt normal
    case "$service_manager" in
        systemd)
            stop_service_systemd "$service_name" || stop_result=1
            ;;
        sysv)
            stop_service_sysv "$service_name" || stop_result=1
            ;;
        openrc)
            stop_service_openrc "$service_name" || stop_result=1
            ;;
        *)
            die "Gestionnaire de services non supporté: $service_manager" 3
            ;;
    esac
    
    # Attendre que le service s'arrête
    if ! wait_for_service_stop "$service_name" "$service_manager" "$WAIT_TIMEOUT"; then
        if [[ $KILL_FORCE -eq 1 && "$initial_pid" != "0" ]]; then
            log_warn "Arrêt gracieux échoué, utilisation de kill -TERM"
            method_used="force_term"
            
            if kill_service_by_pid "$initial_pid" "TERM"; then
                sleep 5
                if ! wait_for_service_stop "$service_name" "$service_manager" 10; then
                    log_warn "TERM échoué, utilisation de kill -KILL"
                    method_used="force_kill"
                    kill_service_by_pid "$initial_pid" "KILL" || true
                    sleep 2
                fi
            fi
        else
            die "Timeout: le service ne s'est pas arrêté dans les ${WAIT_TIMEOUT}s" 6
        fi
    fi
    
    # Calculer le temps d'arrêt
    local end_time
    end_time=$(date +%s%3N)
    shutdown_time_ms=$((end_time - stop_time))
    
    # Obtenir le statut final
    local current_status
    current_status=$(get_service_status "$service_name" "$service_manager")
    
    if [[ "$current_status" != "inactive" ]]; then
        die "Échec de l'arrêt du service $service_name" 5
    fi
    
    log_info "Service $service_name arrêté avec succès"
    log_debug "Méthode: $method_used, Temps d'arrêt: ${shutdown_time_ms}ms"
    
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
  "message": "Service stopped successfully",
  "data": {
    "service_name": "$service_name_escaped",
    "action": "stop",
    "previous_status": "$previous_status",
    "current_status": "$current_status",
    "shutdown_time_ms": $shutdown_time_ms,
    "method_used": "$method_used",
    "pid_terminated": $initial_pid,
    "service_manager": "$service_manager",
    "wait_timeout": $WAIT_TIMEOUT,
    "forced": $([ $FORCE -eq 1 ] && echo "true" || echo "false"),
    "kill_used": $([ $KILL_FORCE -eq 1 ] && echo "true" || echo "false")
  },
  "errors": [],
  "warnings": []
}
EOF
    
    log_debug "Arrêt terminé avec succès"
}

# =============================================================================
# Fonction Principale
# =============================================================================

main() {
    log_debug "Démarrage de $SCRIPT_NAME v$SCRIPT_VERSION"
    
    parse_args "$@"
    check_dependencies
    stop_service "$SERVICE_NAME"
    
    log_info "Script completed successfully"
}

# =============================================================================
# Point d'Entrée
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi