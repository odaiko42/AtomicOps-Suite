#!/usr/bin/env bash

# ===================================================================
# Script: check-memory.oom.sh
# Description: Vérifie les événements OOM (Out of Memory)
# Author: AtomicOps-Suite
# Version: 1.0
# Niveau: atomic
# Catégorie: performance
# ===================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "$0")"
LIB_DIR="$(realpath "$SCRIPT_DIR/../../../lib")"

if [[ -f "$LIB_DIR/lib-atomics-common.sh" ]]; then
    source "$LIB_DIR/lib-atomics-common.sh"
fi

OUTPUT_FORMAT="json"
VERBOSE=false
QUIET=false
HOURS_BACK=24

show_help() {
    cat << 'EOF'
check-memory.oom.sh - Vérifie les événements OOM (Out of Memory)

SYNOPSIS:
    check-memory.oom.sh [OPTIONS]

DESCRIPTION:
    Analyse les événements OOM dans les logs :
    - Processus tués par le kernel
    - Détails des événements OOM
    - Analyse des causes
    
OPTIONS:
    -f, --format FORMAT    Format (json|text|csv) [défaut: json]
    -t, --time HOURS       Heures à analyser [défaut: 24]
    -v, --verbose          Mode verbeux
    -q, --quiet            Mode silencieux
    -h, --help             Affiche cette aide
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--format) OUTPUT_FORMAT="$2"; shift 2 ;;
            -t|--time) HOURS_BACK="$2"; shift 2 ;;
            -v|--verbose) VERBOSE=true; shift ;;
            -q|--quiet) QUIET=true; shift ;;
            -h|--help) show_help; exit 0 ;;
            *) atomic_error "Option inconnue: $1"; return 1 ;;
        esac
    done
}

check_oom_events() {
    OOM_EVENTS=()
    local since_date
    since_date=$(date -d "${HOURS_BACK} hours ago" '+%Y-%m-%d %H:%M:%S')
    
    # Recherche dans journalctl si disponible
    if command -v journalctl >/dev/null 2>&1; then
        local journal_output
        if journal_output=$(journalctl --since "$since_date" -k 2>/dev/null | grep -i "killed process\|out of memory\|oom"); then
            while IFS= read -r line; do
                if [[ "$line" =~ killed\ process\ ([0-9]+)\ \(([^)]+)\) ]]; then
                    local pid="${BASH_REMATCH[1]}"
                    local process="${BASH_REMATCH[2]}"
                    local timestamp=$(echo "$line" | awk '{print $1" "$2" "$3}')
                    OOM_EVENTS+=("$timestamp|$pid|$process|journal")
                fi
            done <<< "$journal_output"
        fi
    fi
    
    # Recherche dans dmesg
    local dmesg_output
    if dmesg_output=$(dmesg -T 2>/dev/null | grep -i "killed process\|out of memory\|oom"); then
        while IFS= read -r line; do
            if [[ "$line" =~ killed\ process\ ([0-9]+)\ \(([^)]+)\) ]]; then
                local pid="${BASH_REMATCH[1]}"
                local process="${BASH_REMATCH[2]}"
                local timestamp=$(echo "$line" | awk '{print $1" "$2" "$3" "$4" "$5}')
                
                # Éviter les doublons avec journalctl
                local duplicate=false
                for event in "${OOM_EVENTS[@]}"; do
                    if [[ "$event" =~ \|$pid\|$process\| ]]; then
                        duplicate=true
                        break
                    fi
                done
                
                if ! $duplicate; then
                    OOM_EVENTS+=("$timestamp|$pid|$process|dmesg")
                fi
            fi
        done <<< "$dmesg_output"
    fi
    
    # Recherche dans /var/log/messages si accessible
    if [[ -r /var/log/messages ]]; then
        local messages_output
        if messages_output=$(grep -i "killed process\|out of memory\|oom" /var/log/messages 2>/dev/null | tail -20); then
            while IFS= read -r line; do
                if [[ "$line" =~ killed\ process\ ([0-9]+)\ \(([^)]+)\) ]]; then
                    local pid="${BASH_REMATCH[1]}"
                    local process="${BASH_REMATCH[2]}"
                    local timestamp=$(echo "$line" | awk '{print $1" "$2" "$3}')
                    
                    # Éviter les doublons
                    local duplicate=false
                    for event in "${OOM_EVENTS[@]}"; do
                        if [[ "$event" =~ \|$pid\|$process\| ]]; then
                            duplicate=true
                            break
                        fi
                    done
                    
                    if ! $duplicate; then
                        OOM_EVENTS+=("$timestamp|$pid|$process|messages")
                    fi
                fi
            done <<< "$messages_output"
        fi
    fi
}

get_current_memory_pressure() {
    local meminfo
    meminfo=$(cat /proc/meminfo 2>/dev/null) || return 1
    
    MEM_TOTAL=$(echo "$meminfo" | awk '/MemTotal/ {print $2}')
    MEM_AVAILABLE=$(echo "$meminfo" | awk '/MemAvailable/ {print $2}')
    
    PRESSURE_PERCENT=$(echo "scale=1; ((($MEM_TOTAL - $MEM_AVAILABLE) * 100) / $MEM_TOTAL)" | bc -l 2>/dev/null || echo "0")
}

output_results() {
    case "$OUTPUT_FORMAT" in
        json)
            echo "{"
            echo "  \"timestamp\": \"$(date -Iseconds)\","
            echo "  \"analysis_period_hours\": $HOURS_BACK,"
            echo "  \"oom_events_count\": ${#OOM_EVENTS[@]},"
            echo "  \"current_memory_pressure_percent\": $PRESSURE_PERCENT,"
            echo "  \"oom_events\": ["
            
            local first=true
            for event in "${OOM_EVENTS[@]}"; do
                IFS='|' read -r timestamp pid process source <<< "$event"
                
                if $first; then
                    first=false
                else
                    echo ","
                fi
                
                echo "    {"
                echo "      \"timestamp\": \"$timestamp\","
                echo "      \"killed_pid\": $pid,"
                echo "      \"killed_process\": \"$process\","
                echo "      \"source\": \"$source\""
                echo -n "    }"
            done
            
            echo ""
            echo "  ]"
            echo "}"
            ;;
        text)
            echo "=== Analyse des événements OOM (dernières $HOURS_BACK heures) ==="
            echo "Événements OOM détectés: ${#OOM_EVENTS[@]}"
            echo "Pression mémoire actuelle: $PRESSURE_PERCENT%"
            echo ""
            
            if [[ ${#OOM_EVENTS[@]} -gt 0 ]]; then
                echo "Processus tués par OOM:"
                printf "%-20s %-8s %-20s %-s\n" "TIMESTAMP" "PID" "PROCESS" "SOURCE"
                echo "----------------------------------------------------------------"
                
                for event in "${OOM_EVENTS[@]}"; do
                    IFS='|' read -r timestamp pid process source <<< "$event"
                    printf "%-20s %-8s %-20s %-s\n" "$timestamp" "$pid" "$process" "$source"
                done
            else
                echo "Aucun événement OOM détecté dans la période analysée."
            fi
            ;;
        csv)
            echo "timestamp,killed_pid,killed_process,source,current_pressure_percent"
            
            for event in "${OOM_EVENTS[@]}"; do
                IFS='|' read -r timestamp pid process source <<< "$event"
                echo "$timestamp,$pid,$process,$source,$PRESSURE_PERCENT"
            done
            ;;
    esac
}

main() {
    atomic_init_logging "$SCRIPT_NAME" "$QUIET"
    
    if ! command -v bc >/dev/null 2>&1; then
        atomic_warn "bc non trouvé, calculs de pression limités"
    fi
    
    parse_args "$@" || { show_help >&2; return 1; }
    
    if $VERBOSE; then
        atomic_info "Analyse des événements OOM (dernières $HOURS_BACK heures)"
    fi
    
    check_oom_events
    get_current_memory_pressure
    
    output_results
    
    if $VERBOSE; then
        if [[ ${#OOM_EVENTS[@]} -gt 0 ]]; then
            atomic_warn "${#OOM_EVENTS[@]} événements OOM détectés"
        else
            atomic_success "Aucun événement OOM récent"
        fi
    fi
    
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi