#!/usr/bin/env bash
# get-io.top.processes.sh - Processus avec plus forte utilisation I/O

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(realpath "$SCRIPT_DIR/../../../lib")"
[[ -f "$LIB_DIR/lib-atomics-common.sh" ]] && source "$LIB_DIR/lib-atomics-common.sh"

OUTPUT_FORMAT="text"
TOP_COUNT=10
SORT_BY="total"
SHOW_THREADS=false
VERBOSE=false
QUIET=false

show_help() {
    cat << 'EOF'
get-io.top.processes.sh - Processus avec plus forte utilisation I/O

Usage: get-io.top.processes.sh [OPTIONS]

OPTIONS:
    -n, --count NUM        Nombre de processus [défaut: 10]
    -s, --sort FIELD       Tri: total|read|write [défaut: total]
    -t, --threads          Inclure les threads
    -f, --format FORMAT    Format: text|json|csv [défaut: text]
    -v, --verbose          Mode verbeux
    -q, --quiet            Mode silencieux
    -h, --help             Affiche cette aide

EXEMPLES:
    get-io.top.processes.sh
    get-io.top.processes.sh -n 20 -s write
    get-io.top.processes.sh --threads --format json

NOTES:
    - Nécessite iotop ou lecture de /proc/*/io
    - Affiche les statistiques depuis le démarrage du processus
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--count) TOP_COUNT="$2"; shift 2 ;;
            -s|--sort) SORT_BY="$2"; shift 2 ;;
            -t|--threads) SHOW_THREADS=true; shift ;;
            -f|--format) OUTPUT_FORMAT="$2"; shift 2 ;;
            -v|--verbose) VERBOSE=true; shift ;;
            -q|--quiet) QUIET=true; shift ;;
            -h|--help) show_help; exit 0 ;;
            *) atomic_error "Option inconnue: $1"; return 1 ;;
        esac
    done
    
    if ! [[ "$TOP_COUNT" =~ ^[0-9]+$ ]]; then
        atomic_error "Count invalide: $TOP_COUNT"
        return 1
    fi
    
    if [[ ! "$SORT_BY" =~ ^(total|read|write)$ ]]; then
        atomic_error "Sort invalide: $SORT_BY (total|read|write)"
        return 1
    fi
}

get_process_io() {
    local pid="$1"
    local comm_file="/proc/$pid/comm"
    local io_file="/proc/$pid/io"
    
    [[ ! -f "$io_file" || ! -f "$comm_file" ]] && return 1
    
    local read_bytes write_bytes
    local comm
    
    # Lecture sécurisée
    comm=$(cat "$comm_file" 2>/dev/null) || return 1
    
    read_bytes=$(awk '/^read_bytes:/ {print $2}' "$io_file" 2>/dev/null) || return 1
    write_bytes=$(awk '/^write_bytes:/ {print $2}' "$io_file" 2>/dev/null) || return 1
    
    [[ -z "$read_bytes" || -z "$write_bytes" ]] && return 1
    
    local total_bytes=$((read_bytes + write_bytes))
    
    echo "$pid:$comm:$read_bytes:$write_bytes:$total_bytes"
}

collect_io_data() {
    local proc_pattern="/proc/[0-9]*"
    
    if $SHOW_THREADS; then
        proc_pattern="/proc/[0-9]*/task/[0-9]*"
    fi
    
    for proc_dir in $proc_pattern; do
        [[ -d "$proc_dir" ]] || continue
        
        local pid
        if $SHOW_THREADS; then
            pid=$(basename "$proc_dir")
        else
            pid=$(basename "$proc_dir")
            [[ "$pid" =~ ^[0-9]+$ ]] || continue
        fi
        
        get_process_io "$pid" 2>/dev/null || continue
    done
}

sort_processes() {
    local sort_column
    case "$SORT_BY" in
        read) sort_column=3 ;;
        write) sort_column=4 ;;
        total) sort_column=5 ;;
    esac
    
    sort -t: -k${sort_column}nr | head -n "$TOP_COUNT"
}

format_bytes() {
    local bytes="$1"
    
    if [[ $bytes -lt 1024 ]]; then
        echo "${bytes}B"
    elif [[ $bytes -lt $((1024*1024)) ]]; then
        echo "$((bytes/1024))K"
    elif [[ $bytes -lt $((1024*1024*1024)) ]]; then
        echo "$((bytes/(1024*1024)))M"
    else
        echo "$((bytes/(1024*1024*1024)))G"
    fi
}

format_text_output() {
    echo "=== Top $TOP_COUNT processus par I/O ($SORT_BY) ==="
    echo
    printf "%-8s %-20s %12s %12s %12s\n" "PID" "COMMAND" "READ" "WRITE" "TOTAL"
    echo "------------------------------------------------------------------------"
    
    collect_io_data | sort_processes | while IFS=: read -r pid comm read_bytes write_bytes total_bytes; do
        printf "%-8s %-20s %12s %12s %12s\n" \
            "$pid" \
            "${comm:0:20}" \
            "$(format_bytes "$read_bytes")" \
            "$(format_bytes "$write_bytes")" \
            "$(format_bytes "$total_bytes")"
    done
}

format_json_output() {
    echo "{"
    echo '  "timestamp": "'$(date -Iseconds)'",'
    echo '  "top_processes": {'
    echo '    "count": '$TOP_COUNT','
    echo '    "sort_by": "'$SORT_BY'",'
    echo '    "include_threads": '$SHOW_THREADS','
    echo '    "processes": ['
    
    local first=true
    collect_io_data | sort_processes | while IFS=: read -r pid comm read_bytes write_bytes total_bytes; do
        $first || echo ","
        echo -n '      {'
        echo -n '"pid": '$pid', '
        echo -n '"command": "'"$comm"'", '
        echo -n '"read_bytes": '$read_bytes', '
        echo -n '"write_bytes": '$write_bytes', '
        echo -n '"total_bytes": '$total_bytes
        echo -n '}'
        first=false
    done
    
    echo
    echo "    ]"
    echo "  }"
    echo "}"
}

format_csv_output() {
    echo "timestamp,pid,command,read_bytes,write_bytes,total_bytes"
    
    local timestamp
    timestamp=$(date -Iseconds)
    
    collect_io_data | sort_processes | while IFS=: read -r pid comm read_bytes write_bytes total_bytes; do
        echo "$timestamp,$pid,\"$comm\",$read_bytes,$write_bytes,$total_bytes"
    done
}

main() {
    atomic_init_logging "${BASH_SOURCE[0]##*/}" "$QUIET"
    parse_args "$@" || { show_help >&2; return 1; }
    
    case "$OUTPUT_FORMAT" in
        text) format_text_output ;;
        json) format_json_output ;;
        csv) format_csv_output ;;
        *) atomic_error "Format invalide: $OUTPUT_FORMAT"; return 1 ;;
    esac
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"