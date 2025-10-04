#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: monitor-system.resources.sh 
# Description: Surveiller les ressources système avec seuils
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-04
# ==============================================================================

set -euo pipefail

SCRIPT_NAME="monitor-system.resources.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
CPU_THRESHOLD=${CPU_THRESHOLD:-80}
MEM_THRESHOLD=${MEM_THRESHOLD:-85}
DISK_THRESHOLD=${DISK_THRESHOLD:-90}
LOAD_THRESHOLD=${LOAD_THRESHOLD:-2.0}

show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Description:
    Surveille les ressources système (CPU, mémoire, disque, charge)
    avec seuils configurables et alertes.

Options:
    -h, --help               Afficher cette aide
    -v, --verbose           Mode verbeux
    -d, --debug             Mode debug
    -q, --quiet             Mode silencieux
    -j, --json-only         Sortie JSON uniquement
    --cpu-threshold N       Seuil CPU en % (défaut: 80)
    --mem-threshold N       Seuil mémoire en % (défaut: 85)
    --disk-threshold N      Seuil disque en % (défaut: 90)
    --load-threshold N.N    Seuil charge système (défaut: 2.0)
    
Exemples:
    $SCRIPT_NAME
    $SCRIPT_NAME --cpu-threshold 90 --mem-threshold 95
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
            --cpu-threshold) CPU_THRESHOLD="$2"; shift 2 ;;
            --mem-threshold) MEM_THRESHOLD="$2"; shift 2 ;;
            --disk-threshold) DISK_THRESHOLD="$2"; shift 2 ;;
            --load-threshold) LOAD_THRESHOLD="$2"; shift 2 ;;
            -*) echo "Option inconnue: $1" >&2; exit 2 ;;
            *) echo "Argument inattendu: $1" >&2; exit 2 ;;
        esac
    done
}

get_cpu_usage() {
    if command -v top >/dev/null 2>&1; then
        top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' || echo "0"
    else
        echo "0"
    fi
}

get_memory_info() {
    if [[ -f /proc/meminfo ]]; then
        local total used available
        total=$(grep "MemTotal:" /proc/meminfo | awk '{print $2}')
        available=$(grep "MemAvailable:" /proc/meminfo | awk '{print $2}')
        used=$((total - available))
        local usage_percent
        usage_percent=$(echo "scale=1; $used * 100 / $total" | bc 2>/dev/null || echo "0")
        echo "$usage_percent $used $total"
    else
        echo "0 0 0"
    fi
}

get_disk_usage() {
    df -h / | awk 'NR==2 {gsub(/%/, "", $5); print $5, $3, $2}' || echo "0 0 0"
}

get_load_average() {
    if [[ -f /proc/loadavg ]]; then
        cut -d' ' -f1 /proc/loadavg
    else
        echo "0.0"
    fi
}

main() {
    parse_args "$@"
    
    local alerts=() warnings=()
    
    # Collecte des métriques CPU
    local cpu_usage
    cpu_usage=$(get_cpu_usage)
    [[ $(echo "$cpu_usage > $CPU_THRESHOLD" | bc 2>/dev/null || echo "0") -eq 1 ]] && alerts+=("High CPU usage: ${cpu_usage}%")
    
    # Collecte des métriques mémoire
    local mem_info mem_usage mem_used mem_total
    read -r mem_usage mem_used mem_total <<< "$(get_memory_info)"
    [[ $(echo "$mem_usage > $MEM_THRESHOLD" | bc 2>/dev/null || echo "0") -eq 1 ]] && alerts+=("High memory usage: ${mem_usage}%")
    
    # Collecte des métriques disque
    local disk_info disk_usage disk_used disk_total
    read -r disk_usage disk_used disk_total <<< "$(get_disk_usage)"
    [[ $disk_usage -gt $DISK_THRESHOLD ]] && alerts+=("High disk usage: ${disk_usage}%")
    
    # Charge système
    local load_avg
    load_avg=$(get_load_average)
    [[ $(echo "$load_avg > $LOAD_THRESHOLD" | bc 2>/dev/null || echo "0") -eq 1 ]] && alerts+=("High system load: $load_avg")
    
    # Collecte informations processus
    local process_count
    process_count=$(ps aux | wc -l)
    
    # Uptime
    local uptime_info
    if [[ -f /proc/uptime ]]; then
        local uptime_seconds
        uptime_seconds=$(cut -d' ' -f1 /proc/uptime | cut -d'.' -f1)
        local days hours minutes
        days=$((uptime_seconds / 86400))
        hours=$(((uptime_seconds % 86400) / 3600))
        minutes=$(((uptime_seconds % 3600) / 60))
        uptime_info="${days}d ${hours}h ${minutes}m"
    else
        uptime_info="unknown"
    fi
    
    # Déterminer le statut
    local status="healthy"
    local code=0
    local message="System resources within normal limits"
    
    if [[ ${#alerts[@]} -gt 0 ]]; then
        status="alert"
        code=1
        message="System resource alerts detected"
    fi
    
    # Génération JSON
    cat << EOF
{
  "status": "$status",
  "code": $code,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "$message",
  "data": {
    "cpu": {
      "usage_percent": $cpu_usage,
      "threshold": $CPU_THRESHOLD,
      "status": "$([ $(echo "$cpu_usage > $CPU_THRESHOLD" | bc 2>/dev/null || echo "0") -eq 1 ] && echo "critical" || echo "normal")"
    },
    "memory": {
      "usage_percent": $mem_usage,
      "used_kb": $mem_used,
      "total_kb": $mem_total,
      "threshold": $MEM_THRESHOLD,
      "status": "$([ $(echo "$mem_usage > $MEM_THRESHOLD" | bc 2>/dev/null || echo "0") -eq 1 ] && echo "critical" || echo "normal")"
    },
    "disk": {
      "usage_percent": $disk_usage,
      "used": "$disk_used",
      "total": "$disk_total",
      "threshold": $DISK_THRESHOLD,
      "status": "$([ $disk_usage -gt $DISK_THRESHOLD ] && echo "critical" || echo "normal")"
    },
    "load": {
      "current": $load_avg,
      "threshold": $LOAD_THRESHOLD,
      "status": "$([ $(echo "$load_avg > $LOAD_THRESHOLD" | bc 2>/dev/null || echo "0") -eq 1 ] && echo "critical" || echo "normal")"
    },
    "system": {
      "uptime": "$uptime_info",
      "processes": $process_count,
      "hostname": "$(hostname 2>/dev/null || echo 'unknown')"
    }
  },
  "alerts": [$(printf '"%s",' "${alerts[@]}" | sed 's/,$//')],
  "warnings": [$(printf '"%s",' "${warnings[@]}" | sed 's/,$//')"]
}
EOF

    [[ ${#alerts[@]} -gt 0 ]] && exit 1 || exit 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi