#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: get-service.status.sh
# Description: Récupère le statut détaillé d'un service système
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-04
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="get-service.status.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
DETAILED=${DETAILED:-0}
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
    Récupère le statut détaillé d'un service système avec informations
    complètes sur l'état, configuration et historique.

Arguments:
    <service_name>          Nom du service à analyser (obligatoire)

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)
    --detailed             Informations détaillées (logs, dépendances)
    
Sortie JSON:
    {
      "status": "success|error",
      "code": 0,
      "timestamp": "ISO8601",
      "script": "$SCRIPT_NAME",
      "message": "Description",
      "data": {
        "service_name": "apache2",
        "status": "active",
        "sub_status": "running",
        "enabled": true,
        "pid": 1234,
        "memory_mb": 45,
        "cpu_percent": 2.5,
        "uptime_seconds": 3600,
        "restart_count": 0,
        "last_start_time": "2025-10-04T10:00:00Z",
        "service_manager": "systemd",
        "unit_file_state": "enabled",
        "dependencies": ["network.target"],
        "ports": [80, 443],
        "logs_recent": ["Service started successfully"]
      },
      "errors": [],
      "warnings": []
    }

Codes de sortie:
    0 - Succès
    1 - Erreur générale
    2 - Erreur de paramètres
    3 - Service non trouvé
    4 - Permissions insuffisantes

Exemples:
    $SCRIPT_NAME apache2                           # Statut de base
    $SCRIPT_NAME --detailed nginx                  # Informations complètes
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
            --detailed)
                DETAILED=1
                shift
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

get_systemd_status() {
    local service_name="$1"
    local status="unknown" sub_status="unknown" enabled="false"
    local pid=0 memory_mb=0 cpu_percent=0 uptime_seconds=0 restart_count=0
    local last_start_time="" unit_file_state="unknown"
    
    # Statut de base
    if systemctl is-active "$service_name" >/dev/null 2>&1; then
        status="active"
    elif systemctl is-failed "$service_name" >/dev/null 2>&1; then
        status="failed"
    else
        status="inactive"
    fi
    
    # État d'activation
    if systemctl is-enabled "$service_name" >/dev/null 2>&1; then
        enabled="true"
        unit_file_state="enabled"
    else
        enabled="false"
        unit_file_state=$(systemctl is-enabled "$service_name" 2>/dev/null || echo "disabled")
    fi
    
    # Informations détaillées avec systemctl show
    if command -v systemctl >/dev/null 2>&1; then
        local show_output
        show_output=$(systemctl show "$service_name" 2>/dev/null || echo "")
        
        # Extraire les informations
        pid=$(echo "$show_output" | grep "^MainPID=" | cut -d'=' -f2 | head -n1)
        sub_status=$(echo "$show_output" | grep "^SubState=" | cut -d'=' -f2 | head -n1)
        restart_count=$(echo "$show_output" | grep "^NRestarts=" | cut -d'=' -f2 | head -n1)
        
        # Temps de démarrage
        local active_enter_timestamp
        active_enter_timestamp=$(echo "$show_output" | grep "^ActiveEnterTimestamp=" | cut -d'=' -f2-)
        if [[ -n "$active_enter_timestamp" && "$active_enter_timestamp" != "0" ]]; then
            last_start_time=$(date -d "$active_enter_timestamp" -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")
            if [[ -n "$last_start_time" ]]; then
                local start_epoch
                start_epoch=$(date -d "$active_enter_timestamp" +%s 2>/dev/null || echo "0")
                uptime_seconds=$(( $(date +%s) - start_epoch ))
                [[ $uptime_seconds -lt 0 ]] && uptime_seconds=0
            fi
        fi
        
        # Utilisation mémoire et CPU
        if [[ "$pid" -gt 0 && -d "/proc/$pid" ]]; then
            # Mémoire en KB depuis /proc/pid/status
            local memory_kb
            memory_kb=$(grep "^VmRSS:" "/proc/$pid/status" 2>/dev/null | awk '{print $2}' || echo "0")
            memory_mb=$(echo "scale=1; $memory_kb / 1024" | bc 2>/dev/null || echo "0")
            
            # CPU approximatif (simpliste)
            if command -v ps >/dev/null 2>&1; then
                cpu_percent=$(ps -p "$pid" -o %cpu --no-headers 2>/dev/null | tr -d ' ' || echo "0")
            fi
        fi
    fi
    
    # Nettoyer les valeurs
    [[ -z "$pid" || "$pid" == "0" ]] && pid=0
    [[ -z "$memory_mb" ]] && memory_mb=0
    [[ -z "$cpu_percent" ]] && cpu_percent=0
    [[ -z "$uptime_seconds" ]] && uptime_seconds=0
    [[ -z "$restart_count" ]] && restart_count=0
    [[ -z "$sub_status" ]] && sub_status="unknown"
    
    echo "$status|$sub_status|$enabled|$pid|$memory_mb|$cpu_percent|$uptime_seconds|$restart_count|$last_start_time|$unit_file_state"
}

get_sysv_status() {
    local service_name="$1"
    local status="unknown" enabled="false" pid=0
    
    # Statut de base
    if service "$service_name" status >/dev/null 2>&1; then
        status="active"
        # Essayer de trouver le PID
        pid=$(pgrep -f "$service_name" | head -n1 2>/dev/null || echo "0")
    else
        status="inactive"
    fi
    
    # Vérifier si activé (liens dans /etc/rc*.d/)
    if ls /etc/rc*.d/S*"$service_name" >/dev/null 2>&1; then
        enabled="true"
    fi
    
    echo "$status|unknown|$enabled|$pid|0|0|0|0||unknown"
}

get_openrc_status() {
    local service_name="$1"
    local status="unknown" enabled="false" pid=0
    
    # Statut de base
    if rc-service "$service_name" status >/dev/null 2>&1; then
        status="active"
        pid=$(pgrep -f "$service_name" | head -n1 2>/dev/null || echo "0")
    else
        status="inactive"
    fi
    
    # Vérifier si activé
    if rc-update show | grep -q "$service_name"; then
        enabled="true"
    fi
    
    echo "$status|unknown|$enabled|$pid|0|0|0|0||unknown"
}

get_service_dependencies() {
    local service_name="$1"
    local service_manager="$2"
    
    case "$service_manager" in
        systemd)
            systemctl list-dependencies "$service_name" --plain --no-pager 2>/dev/null | \
                grep -v "^$service_name" | sed 's/^[[:space:]]*//' | head -5 | \
                tr '\n' ',' | sed 's/,$//'
            ;;
        *)
            echo ""
            ;;
    esac
}

get_service_ports() {
    local pid="$1"
    
    if [[ "$pid" -gt 0 ]] && command -v ss >/dev/null 2>&1; then
        ss -tlnp 2>/dev/null | grep "pid=$pid" | awk '{print $4}' | \
            sed 's/.*://' | sort -n | head -5 | tr '\n' ',' | sed 's/,$//'
    else
        echo ""
    fi
}

get_recent_logs() {
    local service_name="$1"
    local service_manager="$2"
    
    case "$service_manager" in
        systemd)
            if command -v journalctl >/dev/null 2>&1; then
                journalctl -u "$service_name" -n 3 --no-pager --output=cat 2>/dev/null | \
                    tr '\n' '|' | sed 's/|$//'
            else
                echo ""
            fi
            ;;
        *)
            echo ""
            ;;
    esac
}

get_service_status() {
    local service_name="$1"
    
    log_debug "Récupération du statut pour: $service_name"
    
    # Détecter le gestionnaire de services
    local service_manager
    service_manager=$(detect_service_manager)
    log_debug "Gestionnaire détecté: $service_manager"
    
    # Obtenir les informations de base selon le gestionnaire
    local status_info status sub_status enabled pid memory_mb cpu_percent
    local uptime_seconds restart_count last_start_time unit_file_state
    
    case "$service_manager" in
        systemd)
            status_info=$(get_systemd_status "$service_name")
            ;;
        sysv)
            status_info=$(get_sysv_status "$service_name")
            ;;
        openrc)
            status_info=$(get_openrc_status "$service_name")
            ;;
        *)
            die "Gestionnaire de services non supporté: $service_manager" 3
            ;;
    esac
    
    # Parser les informations
    IFS='|' read -r status sub_status enabled pid memory_mb cpu_percent uptime_seconds restart_count last_start_time unit_file_state <<< "$status_info"
    
    log_debug "Statut: $status, PID: $pid, Activé: $enabled"
    
    # Informations supplémentaires si demandées
    local dependencies="" ports="" logs_recent=""
    if [[ $DETAILED -eq 1 ]]; then
        dependencies=$(get_service_dependencies "$service_name" "$service_manager")
        ports=$(get_service_ports "$pid")
        logs_recent=$(get_recent_logs "$service_name" "$service_manager")
    fi
    
    # Échapper le nom du service pour JSON
    local service_name_escaped
    service_name_escaped=$(echo "$service_name" | sed 's/\\/\\\\/g; s/"/\\"/g')
    
    # Construire les arrays JSON pour dépendances, ports et logs
    local dependencies_json="[]" ports_json="[]" logs_json="[]"
    
    if [[ -n "$dependencies" ]]; then
        local deps_list
        deps_list=$(echo "$dependencies" | tr ',' '\n' | sed 's/^/"/; s/$/"/' | tr '\n' ',' | sed 's/,$//')
        dependencies_json="[$deps_list]"
    fi
    
    if [[ -n "$ports" ]]; then
        local ports_list
        ports_list=$(echo "$ports" | tr ',' '\n' | grep -E '^[0-9]+$' | tr '\n' ',' | sed 's/,$//')
        [[ -n "$ports_list" ]] && ports_json="[$ports_list]"
    fi
    
    if [[ -n "$logs_recent" ]]; then
        local logs_list
        logs_list=$(echo "$logs_recent" | tr '|' '\n' | head -3 | sed 's/\\/\\\\/g; s/"/\\"/g; s/^/"/; s/$/"/' | tr '\n' ',' | sed 's/,$//')
        [[ -n "$logs_list" ]] && logs_json="[$logs_list]"
    fi
    
    # Générer la réponse JSON
    cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Service status retrieved successfully",
  "data": {
    "service_name": "$service_name_escaped",
    "status": "$status",
    "sub_status": "$sub_status",
    "enabled": $enabled,
    "pid": $pid,
    "memory_mb": $memory_mb,
    "cpu_percent": $cpu_percent,
    "uptime_seconds": $uptime_seconds,
    "restart_count": $restart_count,
    "last_start_time": "$last_start_time",
    "service_manager": "$service_manager",
    "unit_file_state": "$unit_file_state",
    "dependencies": $dependencies_json,
    "ports": $ports_json,
    "logs_recent": $logs_json,
    "detailed_info": $([ $DETAILED -eq 1 ] && echo "true" || echo "false"),
    "query_time": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  },
  "errors": [],
  "warnings": []
}
EOF
    
    log_debug "Récupération du statut terminée"
}

# =============================================================================
# Fonction Principale
# =============================================================================

main() {
    log_debug "Démarrage de $SCRIPT_NAME v$SCRIPT_VERSION"
    
    parse_args "$@"
    check_dependencies
    get_service_status "$SERVICE_NAME"
    
    log_info "Script completed successfully"
}

# =============================================================================
# Point d'Entrée
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi