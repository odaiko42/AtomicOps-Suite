#!/bin/bash
#
# Script: get-system.info.sh
# Description: Récupère les informations système complètes (hostname, OS, version, architecture, uptime, kernel)
# Usage: get-system.info.sh [OPTIONS]
#
# Options:
#   -h, --help              Affiche cette aide
#   -v, --verbose           Mode verbeux
#   -d, --debug             Mode debug
#   -j, --json-only         Sortie JSON uniquement (pas de logs)
#
# Exit codes:
#   0 - Succès
#   1 - Erreur générale
#   2 - Erreur d'utilisation
#   6 - Erreur de dépendance
#
# Examples:
#   ./get-system.info.sh
#   ./get-system.info.sh --verbose
#   ./get-system.info.sh --json-only
#

# Configuration stricte
set -euo pipefail

# Codes de sortie
EXIT_SUCCESS=0
EXIT_ERROR_GENERAL=1
EXIT_ERROR_USAGE=2
EXIT_ERROR_DEPENDENCY=6

# Variables globales
VERBOSE=0
DEBUG=0
JSON_ONLY=0

# Fonctions de logging minimal
log_info() { 
    [[ $JSON_ONLY -eq 0 ]] && echo "[INFO] $*" >&2 || true
}

log_error() { 
    echo "[ERROR] $*" >&2
}

log_debug() { 
    [[ $DEBUG -eq 1 && $JSON_ONLY -eq 0 ]] && echo "[DEBUG] $*" >&2 || true
}

# Fonction d'aide
show_help() {
    sed -n '/^# Script:/,/^$/p' "$0" | sed 's/^# \?//'
    exit 0
}

# Parsing des arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -d|--debug)
                DEBUG=1
                shift
                ;;
            -j|--json-only)
                JSON_ONLY=1
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                exit $EXIT_ERROR_USAGE
                ;;
            *)
                log_error "Unexpected argument: $1"
                exit $EXIT_ERROR_USAGE
                ;;
        esac
    done
}

# Validation des prérequis
validate_prerequisites() {
    log_debug "Validating prerequisites"
    
    # Vérification des commandes nécessaires
    local required_commands=("uname" "hostname")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Required command not found: $cmd"
            exit $EXIT_ERROR_DEPENDENCY
        fi
    done
    
    log_debug "Prerequisites validated"
}

# Fonction pour détecter la distribution Linux
detect_distribution() {
    local distrib="Unknown"
    local version="Unknown"
    
    # Essayer /etc/os-release en premier (standard)
    if [[ -f "/etc/os-release" ]]; then
        # Extraction manuelle pour éviter les problèmes avec source
        distrib=$(grep '^NAME=' /etc/os-release 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "Unknown")
        version=$(grep '^VERSION_ID=' /etc/os-release 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "Unknown")
    
    # Fallback vers lsb_release si disponible
    elif command -v lsb_release >/dev/null 2>&1; then
        distrib=$(lsb_release -si 2>/dev/null || echo "Unknown")
        version=$(lsb_release -sr 2>/dev/null || echo "Unknown")
    
    # Fallback vers les fichiers de version spécifiques
    elif [[ -f "/etc/debian_version" ]]; then
        distrib="Debian"
        version=$(cat /etc/debian_version 2>/dev/null || echo "Unknown")
    
    elif [[ -f "/etc/redhat-release" ]]; then
        distrib="RedHat/CentOS"
        version=$(cat /etc/redhat-release 2>/dev/null || echo "Unknown")
    
    elif [[ -f "/etc/alpine-release" ]]; then
        distrib="Alpine"
        version=$(cat /etc/alpine-release 2>/dev/null || echo "Unknown")
    
    # Pour WSL et autres environnements
    else
        if grep -q "Microsoft" /proc/version 2>/dev/null; then
            distrib="WSL"
            version=$(uname -r | grep -o "Microsoft" 2>/dev/null || echo "Unknown")
        fi
    fi
    
    echo "$distrib|$version"
}

# Fonction pour récupérer l'uptime formaté
get_formatted_uptime() {
    local uptime_seconds=0
    
    # Récupérer uptime en secondes depuis /proc/uptime
    if [[ -f "/proc/uptime" ]]; then
        uptime_seconds=$(cut -d' ' -f1 /proc/uptime | cut -d'.' -f1)
    else
        # Fallback pour environnements non-Linux
        uptime_seconds=0
    fi
    
    # Conversion en jours, heures, minutes
    local days=$((uptime_seconds / 86400))
    local hours=$(((uptime_seconds % 86400) / 3600))
    local minutes=$(((uptime_seconds % 3600) / 60))
    
    echo "$uptime_seconds|${days}d ${hours}h ${minutes}m"
}

# Fonction pour récupérer les informations CPU
get_cpu_info() {
    local cpu_model="Unknown"
    local cpu_cores="1"
    local cpu_threads="1"
    
    if [[ -f "/proc/cpuinfo" ]]; then
        cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | sed 's/^ *//' 2>/dev/null || echo "Unknown")
        cpu_cores=$(grep -c "^cpu cores" /proc/cpuinfo 2>/dev/null || echo "1")
        cpu_threads=$(grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo "1")
    fi
    
    echo "$cpu_model|$cpu_cores|$cpu_threads"
}

# Fonction pour récupérer les informations mémoire
get_memory_info() {
    local total_mem="0"
    local available_mem="0"
    
    if [[ -f "/proc/meminfo" ]]; then
        total_mem=$(grep "MemTotal:" /proc/meminfo | awk '{print $2}' 2>/dev/null || echo "0")
        available_mem=$(grep "MemAvailable:" /proc/meminfo | awk '{print $2}' 2>/dev/null || grep "MemFree:" /proc/meminfo | awk '{print $2}' 2>/dev/null || echo "0")
        # Conversion de KB vers MB
        total_mem=$((total_mem / 1024))
        available_mem=$((available_mem / 1024))
    fi
    
    echo "$total_mem|$available_mem"
}

# Fonction principale métier
do_main_action() {
    log_info "Collecting system information"
    
    # Récupération des informations de base
    local hostname_short=$(hostname 2>/dev/null || echo "unknown")
    local hostname_fqdn=$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo "unknown")
    local kernel_version=$(uname -r 2>/dev/null || echo "unknown")
    local architecture=$(uname -m 2>/dev/null || echo "unknown")
    
    # Récupération de la distribution
    local distrib_info
    distrib_info=$(detect_distribution)
    local distribution=$(echo "$distrib_info" | cut -d'|' -f1)
    local distrib_version=$(echo "$distrib_info" | cut -d'|' -f2)
    
    # Récupération de l'uptime
    local uptime_info
    uptime_info=$(get_formatted_uptime)
    local uptime_seconds=$(echo "$uptime_info" | cut -d'|' -f1)
    local uptime_formatted=$(echo "$uptime_info" | cut -d'|' -f2)
    
    # Récupération des infos CPU
    local cpu_info
    cpu_info=$(get_cpu_info)
    local cpu_model=$(echo "$cpu_info" | cut -d'|' -f1)
    local cpu_cores=$(echo "$cpu_info" | cut -d'|' -f2)
    local cpu_threads=$(echo "$cpu_info" | cut -d'|' -f3)
    
    # Récupération des infos mémoire
    local memory_info
    memory_info=$(get_memory_info)
    local memory_total_mb=$(echo "$memory_info" | cut -d'|' -f1)
    local memory_available_mb=$(echo "$memory_info" | cut -d'|' -f2)
    
    # Load average
    local load_avg="unknown"
    if [[ -f "/proc/loadavg" ]]; then
        load_avg=$(cat /proc/loadavg | cut -d' ' -f1-3 2>/dev/null || echo "unknown")
    fi
    
    log_info "System information collected successfully"
    
    # Construction du JSON de données
    cat <<EOF
{
  "hostname": {
    "short": "$hostname_short",
    "fqdn": "$hostname_fqdn"
  },
  "os": {
    "distribution": "$distribution",
    "version": "$distrib_version",
    "kernel": "$kernel_version",
    "architecture": "$architecture"
  },
  "uptime": {
    "seconds": $uptime_seconds,
    "formatted": "$uptime_formatted"
  },
  "cpu": {
    "model": "$cpu_model",
    "cores": $cpu_cores,
    "threads": $cpu_threads
  },
  "memory": {
    "total_mb": $memory_total_mb,
    "available_mb": $memory_available_mb
  },
  "load_average": "$load_avg",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
}

# Construction de la sortie JSON finale
build_json_output() {
    local status=$1
    local code=$2
    local message=$3
    local data=$4
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    cat <<EOF
{
  "status": "$status",
  "code": $code,
  "timestamp": "$timestamp",
  "script": "$(basename "$0")",
  "message": "$message",
  "data": $data,
  "errors": [],
  "warnings": []
}
EOF
}

# Point d'entrée principal
main() {
    # Redirection pour séparer logs et résultat JSON si pas en mode JSON-only
    if [[ $JSON_ONLY -eq 0 ]]; then
        exec 3>&1
        exec 1>&2
    fi
    
    log_info "Script started: $(basename "$0")"
    
    # Parse arguments
    parse_args "$@"
    
    # Validation
    validate_prerequisites
    
    # Exécution
    local system_data
    system_data=$(do_main_action)
    
    # Construction du JSON de sortie
    local json_output
    json_output=$(build_json_output "success" $EXIT_SUCCESS "System information retrieved successfully" "$system_data")
    
    # Sortie du résultat
    if [[ $JSON_ONLY -eq 0 ]]; then
        echo "$json_output" >&3
        log_info "Script completed successfully"
    else
        echo "$json_output"
    fi
    
    exit $EXIT_SUCCESS
}

# Exécution
main "$@"