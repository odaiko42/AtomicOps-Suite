#!/usr/bin/env bash

# ===================================================================
# Script: get-memory.available.sh
# Description: Récupère la mémoire disponible
# Author: AtomicOps-Suite
# Version: 1.0
# Niveau: atomic
# Catégorie: performance
# ===================================================================

set -euo pipefail

# === CONFIGURATION ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "$0")"
LIB_DIR="$(realpath "$SCRIPT_DIR/../../../lib")"

# Source des librairies communes
if [[ -f "$LIB_DIR/lib-atomics-common.sh" ]]; then
    source "$LIB_DIR/lib-atomics-common.sh"
fi

# === VARIABLES GLOBALES ===
OUTPUT_FORMAT="json"
VERBOSE=false
QUIET=false
UNIT="MB"
WATCH_MODE=false
INTERVAL=1

# === FONCTIONS ===

show_help() {
    cat << 'EOF'
get-memory.available.sh - Récupère la mémoire disponible

SYNOPSIS:
    get-memory.available.sh [OPTIONS]

DESCRIPTION:
    Collecte les informations de mémoire disponible :
    - Mémoire libre, disponible, cache
    - Buffers et cache système
    - Pourcentages d'utilisation
    - Mode surveillance en continu
    
OPTIONS:
    -f, --format FORMAT    Format de sortie (json|text|csv) [défaut: json]
    -u, --unit UNIT        Unité (B|KB|MB|GB) [défaut: MB]
    -w, --watch            Mode surveillance continue
    -i, --interval SEC     Intervalle en secondes [défaut: 1]
    -v, --verbose          Mode verbeux
    -q, --quiet            Mode silencieux
    -h, --help             Affiche cette aide

CODES DE RETOUR:
    0    Succès
    1    Erreur générale
    2    Dépendance manquante
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--format) OUTPUT_FORMAT="$2"; shift 2 ;;
            -u|--unit) UNIT="$2"; shift 2 ;;
            -w|--watch) WATCH_MODE=true; shift ;;
            -i|--interval) INTERVAL="$2"; shift 2 ;;
            -v|--verbose) VERBOSE=true; shift ;;
            -q|--quiet) QUIET=true; shift ;;
            -h|--help) show_help; exit 0 ;;
            *) atomic_error "Option inconnue: $1"; return 1 ;;
        esac
    done
}

convert_bytes() {
    local bytes="$1"
    case "$UNIT" in
        B) echo "$bytes" ;;
        KB) echo $((bytes / 1024)) ;;
        MB) echo $((bytes / 1024 / 1024)) ;;
        GB) echo "scale=2; $bytes / 1024 / 1024 / 1024" | bc -l ;;
        *) echo "$bytes" ;;
    esac
}

get_memory_stats() {
    local meminfo
    meminfo=$(cat /proc/meminfo 2>/dev/null) || return 1
    
    MEM_TOTAL=$(echo "$meminfo" | awk '/MemTotal/ {print $2 * 1024}')
    MEM_FREE=$(echo "$meminfo" | awk '/MemFree/ {print $2 * 1024}')
    MEM_AVAILABLE=$(echo "$meminfo" | awk '/MemAvailable/ {print $2 * 1024}')
    MEM_BUFFERS=$(echo "$meminfo" | awk '/Buffers/ {print $2 * 1024}')
    MEM_CACHED=$(echo "$meminfo" | awk '/^Cached/ {print $2 * 1024}')
    
    MEM_USED=$((MEM_TOTAL - MEM_FREE - MEM_BUFFERS - MEM_CACHED))
    MEM_USED_PERCENT=$(echo "scale=1; ($MEM_USED * 100) / $MEM_TOTAL" | bc -l)
    MEM_AVAILABLE_PERCENT=$(echo "scale=1; ($MEM_AVAILABLE * 100) / $MEM_TOTAL" | bc -l)
}

output_stats() {
    case "$OUTPUT_FORMAT" in
        json)
            cat << EOF
{
  "timestamp": "$(date -Iseconds)",
  "unit": "$UNIT",
  "memory": {
    "total_${UNIT,,}": $(convert_bytes "$MEM_TOTAL"),
    "used_${UNIT,,}": $(convert_bytes "$MEM_USED"),
    "free_${UNIT,,}": $(convert_bytes "$MEM_FREE"),
    "available_${UNIT,,}": $(convert_bytes "$MEM_AVAILABLE"),
    "buffers_${UNIT,,}": $(convert_bytes "$MEM_BUFFERS"),
    "cached_${UNIT,,}": $(convert_bytes "$MEM_CACHED"),
    "used_percent": $MEM_USED_PERCENT,
    "available_percent": $MEM_AVAILABLE_PERCENT
  }
}
EOF
            ;;
        text)
            echo "=== Mémoire Disponible ==="
            echo "Total: $(convert_bytes "$MEM_TOTAL") $UNIT"
            echo "Utilisé: $(convert_bytes "$MEM_USED") $UNIT ($MEM_USED_PERCENT%)"
            echo "Libre: $(convert_bytes "$MEM_FREE") $UNIT"
            echo "Disponible: $(convert_bytes "$MEM_AVAILABLE") $UNIT ($MEM_AVAILABLE_PERCENT%)"
            echo "Buffers: $(convert_bytes "$MEM_BUFFERS") $UNIT"
            echo "Cache: $(convert_bytes "$MEM_CACHED") $UNIT"
            ;;
        csv)
            echo "timestamp,total_${UNIT,,},used_${UNIT,,},free_${UNIT,,},available_${UNIT,,},used_percent,available_percent"
            echo "$(date -Iseconds),$(convert_bytes "$MEM_TOTAL"),$(convert_bytes "$MEM_USED"),$(convert_bytes "$MEM_FREE"),$(convert_bytes "$MEM_AVAILABLE"),$MEM_USED_PERCENT,$MEM_AVAILABLE_PERCENT"
            ;;
    esac
}

main() {
    atomic_init_logging "$SCRIPT_NAME" "$QUIET"
    
    if ! command -v bc >/dev/null 2>&1; then
        atomic_error "bc requis pour les calculs"
        return 2
    fi
    
    parse_args "$@" || { show_help >&2; return 1; }
    
    if $VERBOSE; then
        atomic_info "Démarrage de $SCRIPT_NAME (format: $OUTPUT_FORMAT, unité: $UNIT)"
    fi
    
    if $WATCH_MODE; then
        while true; do
            get_memory_stats || return 1
            clear
            output_stats
            sleep "$INTERVAL"
        done
    else
        get_memory_stats || return 1
        output_stats
    fi
    
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi