#!/usr/bin/env bash
# get-io.stats.sh - Statistiques I/O système

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(realpath "$SCRIPT_DIR/../../../lib")"
[[ -f "$LIB_DIR/lib-atomics-common.sh" ]] && source "$LIB_DIR/lib-atomics-common.sh"

OUTPUT_FORMAT="text"
DEVICE=""
INTERVAL=""
COUNT=""
VERBOSE=false
QUIET=false

show_help() {
    cat << 'EOF'
get-io.stats.sh - Statistiques I/O système

Usage: get-io.stats.sh [OPTIONS]

OPTIONS:
    -d, --device DEV       Périphérique spécifique
    -i, --interval SEC     Intervalle (avec -c)
    -c, --count NUM        Nombre de mesures
    -f, --format FORMAT    Format: text|json|csv [défaut: text]
    -v, --verbose          Mode verbeux
    -q, --quiet            Mode silencieux
    -h, --help             Affiche cette aide

EXEMPLES:
    get-io.stats.sh
    get-io.stats.sh -d sda -f json
    get-io.stats.sh -i 2 -c 5 --format csv

SORTIES:
    text: Format lisible
    json: Format JSON
    csv:  Format CSV
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--device) DEVICE="$2"; shift 2 ;;
            -i|--interval) INTERVAL="$2"; shift 2 ;;
            -c|--count) COUNT="$2"; shift 2 ;;
            -f|--format) OUTPUT_FORMAT="$2"; shift 2 ;;
            -v|--verbose) VERBOSE=true; shift ;;
            -q|--quiet) QUIET=true; shift ;;
            -h|--help) show_help; exit 0 ;;
            *) atomic_error "Option inconnue: $1"; return 1 ;;
        esac
    done
    
    if [[ -n "$COUNT" && -z "$INTERVAL" ]]; then
        atomic_error "Option -c nécessite -i (interval)"
        return 1
    fi
}

get_iostat_data() {
    local device_arg=""
    local interval_arg=""
    
    [[ -n "$DEVICE" ]] && device_arg="-d $DEVICE"
    [[ -n "$INTERVAL" && -n "$COUNT" ]] && interval_arg="$INTERVAL $COUNT"
    
    if command -v iostat >/dev/null 2>&1; then
        iostat -x $device_arg $interval_arg 2>/dev/null
    else
        atomic_error "iostat non disponible (installer sysstat)"
        return 1
    fi
}

parse_diskstats() {
    while read -r line; do
        [[ "$line" =~ ^[[:space:]]*[0-9] ]] || continue
        
        local fields=($line)
        [[ ${#fields[@]} -ge 14 ]] || continue
        
        local dev_name="${fields[2]}"
        [[ -n "$DEVICE" && "$dev_name" != "$DEVICE" ]] && continue
        
        echo "device:$dev_name"
        echo "reads:${fields[3]}"
        echo "reads_merged:${fields[4]}"
        echo "sectors_read:${fields[5]}"
        echo "read_time_ms:${fields[6]}"
        echo "writes:${fields[7]}"
        echo "writes_merged:${fields[8]}"
        echo "sectors_written:${fields[9]}"
        echo "write_time_ms:${fields[10]}"
        echo "io_in_progress:${fields[11]}"
        echo "io_time_ms:${fields[12]}"
        echo "weighted_io_time_ms:${fields[13]}"
        echo "---"
    done < /proc/diskstats
}

format_text_output() {
    echo "=== Statistiques I/O système ==="
    echo
    
    if command -v iostat >/dev/null 2>&1; then
        get_iostat_data
    else
        atomic_info "Utilisation de /proc/diskstats (iostat indisponible)"
        echo
        parse_diskstats | while IFS=':' read -r key value; do
            [[ "$key" == "---" ]] && { echo; continue; }
            printf "%-20s: %s\n" "$key" "$value"
        done
    fi
}

format_json_output() {
    echo "{"
    echo '  "timestamp": "'$(date -Iseconds)'",'
    echo '  "io_statistics": {'
    
    if command -v iostat >/dev/null 2>&1; then
        echo '    "source": "iostat",'
        echo '    "data": []'
    else
        echo '    "source": "proc_diskstats",'
        echo '    "devices": ['
        
        local first=true
        parse_diskstats | {
            local device_data=""
            while IFS=':' read -r key value; do
                if [[ "$key" == "---" ]]; then
                    if [[ -n "$device_data" ]]; then
                        $first || echo "      },"
                        echo "      {"
                        echo "$device_data"
                        first=false
                        device_data=""
                    fi
                elif [[ "$key" == "device" ]]; then
                    device_data='        "device": "'$value'"'
                else
                    device_data+=',\n        "'$key'": '$value
                fi
            done
            [[ -n "$device_data" ]] && {
                $first || echo "      },"
                echo "      {"
                echo -e "$device_data"
            }
        }
        echo "      }"
        echo "    ]"
    fi
    
    echo "  }"
    echo "}"
}

format_csv_output() {
    if command -v iostat >/dev/null 2>&1; then
        echo "timestamp,source,device,data"
        echo "$(date -Iseconds),iostat,various,see_iostat_output"
    else
        echo "timestamp,device,reads,reads_merged,sectors_read,read_time_ms,writes,writes_merged,sectors_written,write_time_ms,io_in_progress,io_time_ms,weighted_io_time_ms"
        
        parse_diskstats | {
            local values=("$(date -Iseconds)")
            while IFS=':' read -r key value; do
                if [[ "$key" == "---" ]]; then
                    [[ ${#values[@]} -gt 1 ]] && {
                        IFS=','; echo "${values[*]}"
                        values=("$(date -Iseconds)")
                    }
                else
                    values+=("$value")
                fi
            done
            [[ ${#values[@]} -gt 1 ]] && {
                IFS=','; echo "${values[*]}"
            }
        }
    fi
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