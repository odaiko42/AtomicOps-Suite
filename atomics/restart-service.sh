#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: restart-service.sh
# Description: Redémarre un service système avec timeout et validation
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-04
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="restart-service.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
FORCE=${FORCE:-0}
WAIT_TIMEOUT=${WAIT_TIMEOUT:-45}
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
    Redémarre un service système de manière sécurisée avec arrêt puis démarrage.
    Compatible avec systemd, SysV init et autres gestionnaires de services.

Arguments:
    <service_name>          Nom du service à redémarrer (obligatoire)

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)
    -f, --force            Forcer le redémarrage sans confirmation
    -w, --wait SECONDS     Timeout total pour redémarrage (défaut: 45s)
    
Sortie JSON:
    {
      "status": "success|error",
      "code": 0,
      "timestamp": "ISO8601",
      "script": "$SCRIPT_NAME",
      "message": "Description",
      "data": {
        "service_name": "apache2",
        "action": "restart",
        "initial_status": "active",
        "stop_status": "inactive",
        "final_status": "active",
        "total_time_ms": 2500,
        "stop_time_ms": 1200,
        "start_time_ms": 1300,
        "old_pid": 1234,
        "new_pid": 1567,
        "service_manager": "systemd"
      },
      "errors": [],
      "warnings": []
    }

Codes de sortie:
    0 - Succès (service redémarré)
    1 - Erreur générale
    2 - Erreur de paramètres
    3 - Service non trouvé
    4 - Permissions insuffisantes
    5 - Échec d'arrêt
    6 - Échec de démarrage
    7 - Timeout global

Exemples:
    $SCRIPT_NAME apache2                           # Redémarrer Apache
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

restart_service_native() {
    local service_name="$1"
    local service_manager="$2"
    
    case "$service_manager" in
        systemd)
            systemctl restart "$service_name" 2>/dev/null
            ;;
        sysv)
            service "$service_name" restart >/dev/null 2>&1
            ;;
        openrc)
            rc-service "$service_name" restart >/dev/null 2>&1
            ;;
        *)
            return 1
            ;;
    esac
}

stop_service() {
    local service_name="$1"
    local service_manager="$2"
    
    case "$service_manager" in
        systemd)
            systemctl stop "$service_name" 2>/dev/null
            ;;
        sysv)
            service "$service_name" stop >/dev/null 2>&1
            ;;
        openrc)
            rc-service "$service_name" stop >/dev/null 2>&1
            ;;
        *)
            return 1
            ;;
    esac
}

start_service() {
    local service_name="$1"
    local service_manager="$2"
    
    case "$service_manager" in
        systemd)
            systemctl start "$service_name" 2>/dev/null
            ;;
        sysv)
            service "$service_name" start >/dev/null 2>&1
            ;;
        openrc)
            rc-service "$service_name" start >/dev/null 2>&1
            ;;
        *)
            return 1
            ;;
    esac
}

wait_for_status() {
    local service_name="$1"
    local service_manager="$2"
    local expected_status="$3"
    local timeout="$4"
    local waited=0
    
    log_debug "Attente du statut '$expected_status' (timeout: ${timeout}s)"
    
    while [[ $waited -lt $timeout ]]; do
        local current_status
        current_status=$(get_service_status "$service_name" "$service_manager")
        
        if [[ "$current_status" == "$expected_status" ]]; then
            log_debug "Statut '$expected_status' atteint après ${waited}s"
            return 0
        fi
        
        sleep 1
        ((waited++))
    done
    
    log_warn "Timeout atteint pour statut '$expected_status' après ${timeout}s"
    return 1
}

confirm_restart() {
    local service_name="$1"
    
    if [[ $FORCE -eq 1 || $JSON_ONLY -eq 1 ]]; then
        return 0
    fi
    
    echo "Êtes-vous sûr de vouloir redémarrer le service '$service_name' ? (o/N)"
    read -r confirmation
    
    case "$confirmation" in
        o|O|oui|OUI|y|Y|yes|YES)
            return 0
            ;;
        *)
            die "Redémarrage annulé par l'utilisateur" 7
            ;;
    esac
}

restart_service() {
    local service_name="$1"
    
    log_debug "Redémarrage du service: $service_name"
    
    # Détecter le gestionnaire de services
    local service_manager
    service_manager=$(detect_service_manager)
    log_debug "Gestionnaire de services détecté: $service_manager"
    
    # Obtenir le statut initial et PID
    local initial_status old_pid
    initial_status=$(get_service_status "$service_name" "$service_manager")
    old_pid=$(get_service_pid "$service_name" "$service_manager")
    log_debug "Statut initial: $initial_status, PID: $old_pid"
    
    # Demander confirmation
    confirm_restart "$service_name"
    
    # Variables pour le timing
    local total_start_time stop_start_time start_start_time
    local stop_time_ms start_time_ms total_time_ms
    local stop_status final_status new_pid
    
    total_start_time=$(date +%s%3N)
    
    log_info "Redémarrage du service $service_name..."
    
    # Calculer les timeouts pour arrêt et démarrage
    local stop_timeout start_timeout
    stop_timeout=$((WAIT_TIMEOUT * 2 / 3))
    start_timeout=$((WAIT_TIMEOUT - stop_timeout))
    
    # Étape 1: Arrêter le service
    stop_start_time=$(date +%s%3N)
    log_info "Arrêt du service..."
    
    if ! stop_service "$service_name" "$service_manager"; then
        die "Échec de l'arrêt du service $service_name" 5
    fi
    
    # Attendre l'arrêt complet
    if ! wait_for_status "$service_name" "$service_manager" "inactive" "$stop_timeout"; then
        die "Timeout: le service ne s'est pas arrêté dans les ${stop_timeout}s" 5
    fi
    
    stop_time_ms=$((($(date +%s%3N) - stop_start_time)))
    stop_status=$(get_service_status "$service_name" "$service_manager")
    
    # Étape 2: Démarrer le service
    start_start_time=$(date +%s%3N)
    log_info "Démarrage du service..."
    
    if ! start_service "$service_name" "$service_manager"; then
        die "Échec du démarrage du service $service_name" 6
    fi
    
    # Attendre le démarrage complet
    if ! wait_for_status "$service_name" "$service_manager" "active" "$start_timeout"; then
        die "Timeout: le service ne s'est pas démarré dans les ${start_timeout}s" 6
    fi
    
    start_time_ms=$((($(date +%s%3N) - start_start_time)))
    
    # Obtenir le statut final et nouveau PID
    final_status=$(get_service_status "$service_name" "$service_manager")
    new_pid=$(get_service_pid "$service_name" "$service_manager")
    total_time_ms=$((($(date +%s%3N) - total_start_time)))
    
    log_info "Service $service_name redémarré avec succès"
    log_debug "Temps total: ${total_time_ms}ms (arrêt: ${stop_time_ms}ms, démarrage: ${start_time_ms}ms)"
    log_debug "Ancien PID: $old_pid, Nouveau PID: $new_pid"
    
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
  "message": "Service restarted successfully",
  "data": {
    "service_name": "$service_name_escaped",
    "action": "restart",
    "initial_status": "$initial_status",
    "stop_status": "$stop_status",
    "final_status": "$final_status",
    "total_time_ms": $total_time_ms,
    "stop_time_ms": $stop_time_ms,
    "start_time_ms": $start_time_ms,
    "old_pid": $old_pid,
    "new_pid": $new_pid,
    "service_manager": "$service_manager",
    "wait_timeout": $WAIT_TIMEOUT,
    "forced": $([ $FORCE -eq 1 ] && echo "true" || echo "false")
  },
  "errors": [],
  "warnings": []
}
EOF
    
    log_debug "Redémarrage terminé avec succès"
}

# =============================================================================
# Fonction Principale
# =============================================================================

main() {
    log_debug "Démarrage de $SCRIPT_NAME v$SCRIPT_VERSION"
    
    parse_args "$@"
    check_dependencies
    restart_service "$SERVICE_NAME"
    
    log_info "Script completed successfully"
}

# =============================================================================
# Point d'Entrée
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi