#!/usr/bin/env bash
# get-network.bandwidth.sh - Mesure la bande passante réseau

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(realpath "$SCRIPT_DIR/../../../lib")"
[[ -f "$LIB_DIR/lib-atomics-common.sh" ]] && source "$LIB_DIR/lib-atomics-common.sh"

OUTPUT_FORMAT="text"
INTERFACE=""
INTERVAL=1
COUNT=10
VERBOSE=false
QUIET=false

show_help() {
    cat << 'EOF'
get-network.bandwidth.sh - Mesure la bande passante réseau

Usage: get-network.bandwidth.sh [OPTIONS]

OPTIONS:
    -i, --interface IF     Interface réseau spécifique
    -t, --interval SEC     Intervalle entre mesures [défaut: 1]
    -c, --count NUM        Nombre de mesures [défaut: 10]
    -f, --format FORMAT    Format: text|json|csv [défaut: text]
    -v, --verbose          Mode verbeux
    -q, --quiet            Mode silencieux
    -h, --help             Affiche cette aide

EXEMPLES:
    get-network.bandwidth.sh
    get-network.bandwidth.sh -i eth0 -c 20
    get-network.bandwidth.sh --interval 5 --format json

NOTES:
    - Mesure le trafic en temps réel via /proc/net/dev
    - Sans -i, analyse toutes les interfaces actives
    - Résultats en bits/sec et bytes/sec
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--interface) INTERFACE="$2"; shift 2 ;;
            -t|--interval) INTERVAL="$2"; shift 2 ;;
            -c|--count) COUNT="$2"; shift 2 ;;
            -f|--format) OUTPUT_FORMAT="$2"; shift 2 ;;
            -v|--verbose) VERBOSE=true; shift ;;
            -q|--quiet) QUIET=true; shift ;;
            -h|--help) show_help; exit 0 ;;
            *) atomic_error "Option inconnue: $1"; return 1 ;;
        esac
    done
    
    if ! [[ "$INTERVAL" =~ ^[0-9]+$ ]]; then
        atomic_error "Interval invalide: $INTERVAL"
        return 1
    fi
    
    if ! [[ "$COUNT" =~ ^[0-9]+$ ]]; then
        atomic_error "Count invalide: $COUNT"
        return 1
    fi
}

get_interfaces() {
    if [[ -n "$INTERFACE" ]]; then
        if [[ ! -d "/sys/class/net/$INTERFACE" ]]; then
            atomic_error "Interface inexistante: $INTERFACE"
            return 1
        fi
        echo "$INTERFACE"
    else
        # Interfaces actives (pas loopback)
        for iface in /sys/class/net/*/; do
            local name
            name=$(basename "$iface")
            [[ "$name" == "lo" ]] && continue
            
            # Vérifier si l'interface est up
            if [[ -f "$iface/operstate" ]]; then
                local state
                state=$(cat "$iface/operstate" 2>/dev/null)
                [[ "$state" == "up" ]] && echo "$name"
            fi
        done
    fi
}

read_interface_stats() {
    local iface="$1"
    
    # Lecture de /proc/net/dev
    local line
    line=$(grep "^[[:space:]]*$iface:" /proc/net/dev 2>/dev/null)
    
    if [[ -z "$line" ]]; then
        atomic_error "Interface non trouvée: $iface"
        return 1
    fi
    
    # Parse les statistiques
    local fields
    read -r -a fields <<< "${line#*:}"
    
    local rx_bytes="${fields[0]}"
    local rx_packets="${fields[1]}"
    local tx_bytes="${fields[8]}"
    local tx_packets="${fields[9]}"
    
    echo "$rx_bytes:$rx_packets:$tx_bytes:$tx_packets"
}

calculate_bandwidth() {
    local iface="$1"
    declare -A prev_stats curr_stats
    
    atomic_info "Mesure bande passante: $iface ($COUNT mesures, intervalle ${INTERVAL}s)"
    
    # Première lecture
    local stats
    stats=$(read_interface_stats "$iface") || return 1
    IFS=':' read -r prev_rx_bytes prev_rx_packets prev_tx_bytes prev_tx_packets <<< "$stats"
    local prev_time
    prev_time=$(date +%s)
    
    echo "interface:$iface"
    echo "interval_s:$INTERVAL"
    echo "measurement_count:$COUNT"
    
    local total_rx_bps=0 total_tx_bps=0
    local max_rx_bps=0 max_tx_bps=0
    local measurements=0
    
    for ((i=1; i<=COUNT; i++)); do
        sleep "$INTERVAL"
        
        stats=$(read_interface_stats "$iface") || return 1
        IFS=':' read -r curr_rx_bytes curr_rx_packets curr_tx_bytes curr_tx_packets <<< "$stats"
        local curr_time
        curr_time=$(date +%s)
        
        local time_diff=$((curr_time - prev_time))
        [[ $time_diff -eq 0 ]] && time_diff=1
        
        local rx_bytes_diff=$((curr_rx_bytes - prev_rx_bytes))
        local tx_bytes_diff=$((curr_tx_bytes - prev_tx_bytes))
        
        local rx_bps=$((rx_bytes_diff / time_diff))
        local tx_bps=$((tx_bytes_diff / time_diff))
        
        # Statistiques
        total_rx_bps=$((total_rx_bps + rx_bps))
        total_tx_bps=$((total_tx_bps + tx_bps))
        measurements=$((measurements + 1))
        
        [[ $rx_bps -gt $max_rx_bps ]] && max_rx_bps=$rx_bps
        [[ $tx_bps -gt $max_tx_bps ]] && max_tx_bps=$tx_bps
        
        $VERBOSE && atomic_info "Mesure $i: RX=${rx_bps}B/s, TX=${tx_bps}B/s"
        
        # Préparation pour la prochaine itération
        prev_rx_bytes=$curr_rx_bytes
        prev_tx_bytes=$curr_tx_bytes
        prev_time=$curr_time
    done
    
    # Calcul des moyennes
    local avg_rx_bps=$((total_rx_bps / measurements))
    local avg_tx_bps=$((total_tx_bps / measurements))
    
    echo "avg_rx_bytes_per_sec:$avg_rx_bps"
    echo "avg_tx_bytes_per_sec:$avg_tx_bps"
    echo "avg_rx_bits_per_sec:$((avg_rx_bps * 8))"
    echo "avg_tx_bits_per_sec:$((avg_tx_bps * 8))"
    echo "max_rx_bytes_per_sec:$max_rx_bps"
    echo "max_tx_bytes_per_sec:$max_tx_bps"
    echo "max_rx_bits_per_sec:$((max_rx_bps * 8))"
    echo "max_tx_bits_per_sec:$((max_tx_bps * 8))"
    echo "total_measurements:$measurements"
    echo "---"
}

format_bytes_per_sec() {
    local bps="$1"
    
    if [[ $bps -lt 1024 ]]; then
        echo "${bps} B/s"
    elif [[ $bps -lt $((1024*1024)) ]]; then
        echo "$((bps/1024)) KB/s"
    elif [[ $bps -lt $((1024*1024*1024)) ]]; then
        echo "$((bps/(1024*1024))) MB/s"
    else
        echo "$((bps/(1024*1024*1024))) GB/s"
    fi
}

format_text_output() {
    echo "=== Bande passante réseau ==="
    echo
    
    get_interfaces | while read -r iface; do
        [[ -z "$iface" ]] && continue
        
        calculate_bandwidth "$iface" | while IFS=':' read -r key value; do
            case "$key" in
                ---) echo ;;
                *bytes_per_sec) printf "%-25s: %s (%s)\n" "$key" "$value" "$(format_bytes_per_sec "$value")" ;;
                *bits_per_sec) printf "%-25s: %s\n" "$key" "$value" ;;
                *) printf "%-25s: %s\n" "$key" "$value" ;;
            esac
        done
    done
}

format_json_output() {
    echo "{"
    echo '  "timestamp": "'$(date -Iseconds)'",'
    echo '  "network_bandwidth": ['
    
    local first_iface=true
    get_interfaces | while read -r iface; do
        [[ -z "$iface" ]] && continue
        
        $first_iface || echo ","
        echo "    {"
        
        calculate_bandwidth "$iface" | {
            local json_fields=""
            while IFS=':' read -r key value; do
                [[ "$key" == "---" ]] && break
                [[ -n "$json_fields" ]] && json_fields+=", "
                json_fields+='"'$key'": "'$value'"'
            done
            echo "      $json_fields"
        }
        
        echo -n "    }"
        first_iface=false
    done
    
    echo
    echo "  ]"
    echo "}"
}

format_csv_output() {
    echo "timestamp,interface,interval_s,measurement_count,avg_rx_bytes_per_sec,avg_tx_bytes_per_sec,avg_rx_bits_per_sec,avg_tx_bits_per_sec,max_rx_bytes_per_sec,max_tx_bytes_per_sec,max_rx_bits_per_sec,max_tx_bits_per_sec,total_measurements"
    
    local timestamp
    timestamp=$(date -Iseconds)
    
    get_interfaces | while read -r iface; do
        [[ -z "$iface" ]] && continue
        
        calculate_bandwidth "$iface" | {
            local values=("$timestamp")
            while IFS=':' read -r key value; do
                [[ "$key" == "---" ]] && break
                values+=("$value")
            done
            IFS=','; echo "${values[*]}"
        }
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