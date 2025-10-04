#!/usr/bin/env bash

# ===================================================================
# Script: get-memory.top.processes.sh
# Description: Liste les processus consommant le plus de RAM
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
TOP_COUNT=10
UNIT="MB"

show_help() {
    cat << 'EOF'
get-memory.top.processes.sh - Liste les processus consommant le plus de RAM

SYNOPSIS:
    get-memory.top.processes.sh [OPTIONS]

DESCRIPTION:
    Identifie les processus avec la plus haute consommation mémoire :
    - Top N processus par utilisation RAM
    - RSS, VSZ, pourcentage mémoire
    - Informations détaillées des processus
    
OPTIONS:
    -f, --format FORMAT    Format (json|text|csv) [défaut: json]
    -n, --count COUNT      Nombre de processus [défaut: 10]  
    -u, --unit UNIT        Unité (B|KB|MB|GB) [défaut: MB]
    -v, --verbose          Mode verbeux
    -q, --quiet            Mode silencieux
    -h, --help             Affiche cette aide
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--format) OUTPUT_FORMAT="$2"; shift 2 ;;
            -n|--count) TOP_COUNT="$2"; shift 2 ;;
            -u|--unit) UNIT="$2"; shift 2 ;;
            -v|--verbose) VERBOSE=true; shift ;;
            -q|--quiet) QUIET=true; shift ;;
            -h|--help) show_help; exit 0 ;;
            *) atomic_error "Option inconnue: $1"; return 1 ;;
        esac
    done
}

convert_kb() {
    local kb="$1"
    case "$UNIT" in
        B) echo $((kb * 1024)) ;;
        KB) echo "$kb" ;;
        MB) echo "scale=1; $kb / 1024" | bc -l ;;
        GB) echo "scale=2; $kb / 1024 / 1024" | bc -l ;;
        *) echo "$kb" ;;
    esac
}

collect_processes() {
    PROCESSES_ARRAY=()
    
    # Collecte via ps, tri par RSS (mémoire physique)
    local ps_output
    ps_output=$(ps aux --sort=-rss 2>/dev/null) || return 1
    
    local line_count=0
    local first_line=true
    
    while IFS= read -r line && [[ $line_count -lt $TOP_COUNT ]]; do
        if $first_line; then
            first_line=false
            continue
        fi
        
        local fields
        read -ra fields <<< "$line"
        
        if [[ ${#fields[@]} -lt 11 ]]; then
            continue
        fi
        
        local user="${fields[0]}"
        local pid="${fields[1]}"
        local cpu_percent="${fields[2]}"
        local mem_percent="${fields[3]}"
        local vsz_kb="${fields[4]}"
        local rss_kb="${fields[5]}"
        
        # Reconstruction de la commande
        local command=""
        for ((i=10; i<${#fields[@]}; i++)); do
            if [[ -n "$command" ]]; then
                command="$command ${fields[i]}"
            else
                command="${fields[i]}"
            fi
        done
        
        # Filtrer les processus avec mémoire significative
        if [[ $rss_kb -gt 0 ]]; then
            PROCESSES_ARRAY+=("$user|$pid|$mem_percent|$(convert_kb "$rss_kb")|$(convert_kb "$vsz_kb")|$command")
            ((line_count++))
        fi
    done <<< "$ps_output"
}

output_results() {
    case "$OUTPUT_FORMAT" in
        json)
            echo "{"
            echo "  \"timestamp\": \"$(date -Iseconds)\","
            echo "  \"unit\": \"$UNIT\","
            echo "  \"top_count\": $TOP_COUNT,"
            echo "  \"processes\": ["
            
            local first=true
            for process_data in "${PROCESSES_ARRAY[@]}"; do
                IFS='|' read -r user pid mem_percent rss vsz command <<< "$process_data"
                
                if $first; then
                    first=false
                else
                    echo ","
                fi
                
                echo "    {"
                echo "      \"user\": \"$user\","
                echo "      \"pid\": $pid,"
                echo "      \"memory_percent\": $mem_percent,"
                echo "      \"rss_${UNIT,,}\": $rss,"
                echo "      \"vsz_${UNIT,,}\": $vsz,"
                echo "      \"command\": \"$(echo "$command" | sed 's/"/\\"/g')\""
                echo -n "    }"
            done
            
            echo ""
            echo "  ]"
            echo "}"
            ;;
        text)
            echo "=== Top $TOP_COUNT processus par mémoire ==="
            printf "%-10s %-8s %-6s %-10s %-10s %-s\n" "USER" "PID" "%MEM" "RSS($UNIT)" "VSZ($UNIT)" "COMMAND"
            echo "--------------------------------------------------------------------------------"
            
            for process_data in "${PROCESSES_ARRAY[@]}"; do
                IFS='|' read -r user pid mem_percent rss vsz command <<< "$process_data"
                
                local cmd_display="$command"
                if [[ ${#cmd_display} -gt 40 ]]; then
                    cmd_display="${cmd_display:0:37}..."
                fi
                
                printf "%-10s %-8s %-6s %-10s %-10s %-s\n" \
                    "$user" "$pid" "$mem_percent" "$rss" "$vsz" "$cmd_display"
            done
            ;;
        csv)
            echo "timestamp,user,pid,memory_percent,rss_${UNIT,,},vsz_${UNIT,,},command"
            
            for process_data in "${PROCESSES_ARRAY[@]}"; do
                IFS='|' read -r user pid mem_percent rss vsz command <<< "$process_data"
                echo "$(date -Iseconds),$user,$pid,$mem_percent,$rss,$vsz,\"$(echo "$command" | sed 's/"/\\"/g')\""
            done
            ;;
    esac
}

main() {
    atomic_init_logging "$SCRIPT_NAME" "$QUIET"
    
    if ! command -v bc >/dev/null 2>&1; then
        atomic_warn "bc non trouvé, conversion d'unités limitée"
    fi
    
    parse_args "$@" || { show_help >&2; return 1; }
    
    if $VERBOSE; then
        atomic_info "Collecte top $TOP_COUNT processus par mémoire"
    fi
    
    collect_processes || return 1
    output_results
    
    if $VERBOSE; then
        atomic_success "Collecte terminée (${#PROCESSES_ARRAY[@]} processus)"
    fi
    
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi