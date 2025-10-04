#!/usr/bin/env bash
# get-swap.usage.sh - Récupère l'utilisation du swap

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(realpath "$SCRIPT_DIR/../../../lib")"
[[ -f "$LIB_DIR/lib-atomics-common.sh" ]] && source "$LIB_DIR/lib-atomics-common.sh"

OUTPUT_FORMAT="json"
VERBOSE=false
QUIET=false
UNIT="MB"

show_help() {
    echo "get-swap.usage.sh - Récupère l'utilisation du swap"
    echo "Usage: $0 [-f json|text|csv] [-u B|KB|MB|GB] [-v] [-q] [-h]"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--format) OUTPUT_FORMAT="$2"; shift 2 ;;
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

get_swap_info() {
    SWAP_DEVICES=()
    
    # Info globale via /proc/meminfo
    local meminfo=$(cat /proc/meminfo 2>/dev/null)
    SWAP_TOTAL=$(echo "$meminfo" | awk '/SwapTotal/ {print $2}')
    SWAP_FREE=$(echo "$meminfo" | awk '/SwapFree/ {print $2}')
    SWAP_USED=$((SWAP_TOTAL - SWAP_FREE))
    
    if [[ $SWAP_TOTAL -gt 0 ]]; then
        SWAP_USAGE_PERCENT=$(echo "scale=1; ($SWAP_USED * 100) / $SWAP_TOTAL" | bc -l)
    else
        SWAP_USAGE_PERCENT=0
    fi
    
    # Détails par device via /proc/swaps
    if [[ -r /proc/swaps ]]; then
        while read -r filename type size used priority; do
            [[ "$filename" == "Filename" ]] && continue
            SWAP_DEVICES+=("$filename|$type|$size|$used|$priority")
        done < /proc/swaps
    fi
}

output_results() {
    case "$OUTPUT_FORMAT" in
        json)
            echo "{"
            echo "  \"timestamp\": \"$(date -Iseconds)\","
            echo "  \"unit\": \"$UNIT\","
            echo "  \"swap_summary\": {"
            echo "    \"total_${UNIT,,}\": $(convert_kb "$SWAP_TOTAL"),"
            echo "    \"used_${UNIT,,}\": $(convert_kb "$SWAP_USED"),"
            echo "    \"free_${UNIT,,}\": $(convert_kb "$SWAP_FREE"),"
            echo "    \"usage_percent\": $SWAP_USAGE_PERCENT"
            echo "  },"
            echo "  \"devices\": ["
            
            local first=true
            for device in "${SWAP_DEVICES[@]}"; do
                IFS='|' read -r filename type size used priority <<< "$device"
                
                if $first; then first=false; else echo ","; fi
                
                echo "    {"
                echo "      \"filename\": \"$filename\","
                echo "      \"type\": \"$type\","
                echo "      \"size_${UNIT,,}\": $(convert_kb "$size"),"
                echo "      \"used_${UNIT,,}\": $(convert_kb "$used"),"
                echo "      \"priority\": $priority"
                echo -n "    }"
            done
            
            echo ""
            echo "  ]"
            echo "}"
            ;;
        text)
            echo "=== Utilisation du Swap ==="
            echo "Total: $(convert_kb "$SWAP_TOTAL") $UNIT"
            echo "Utilisé: $(convert_kb "$SWAP_USED") $UNIT ($SWAP_USAGE_PERCENT%)"
            echo "Libre: $(convert_kb "$SWAP_FREE") $UNIT"
            echo ""
            echo "Devices:"
            for device in "${SWAP_DEVICES[@]}"; do
                IFS='|' read -r filename type size used priority <<< "$device"
                echo "  $filename ($type): $(convert_kb "$used")/$(convert_kb "$size") $UNIT (priorité: $priority)"
            done
            ;;
        csv)
            echo "timestamp,total_${UNIT,,},used_${UNIT,,},free_${UNIT,,},usage_percent"
            echo "$(date -Iseconds),$(convert_kb "$SWAP_TOTAL"),$(convert_kb "$SWAP_USED"),$(convert_kb "$SWAP_FREE"),$SWAP_USAGE_PERCENT"
            ;;
    esac
}

main() {
    atomic_init_logging "${BASH_SOURCE[0]##*/}" "$QUIET"
    command -v bc >/dev/null 2>&1 || { atomic_error "bc requis"; return 2; }
    parse_args "$@" || { show_help >&2; return 1; }
    get_swap_info
    output_results
    return 0
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"