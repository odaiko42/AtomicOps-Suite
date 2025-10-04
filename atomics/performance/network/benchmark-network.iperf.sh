#!/usr/bin/env bash
# benchmark-network.iperf.sh - Benchmark réseau avec iperf3

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(realpath "$SCRIPT_DIR/../../../lib")"
[[ -f "$LIB_DIR/lib-atomics-common.sh" ]] && source "$LIB_DIR/lib-atomics-common.sh"

OUTPUT_FORMAT="text"
SERVER_HOST=""
SERVER_PORT="5201"
TEST_DURATION="10"
PARALLEL_STREAMS="1"
BANDWIDTH=""
PROTOCOL="tcp"
REVERSE=false
BIDIRECTIONAL=false
VERBOSE=false
QUIET=false
DRY_RUN=false

show_help() {
    cat << 'EOF'
benchmark-network.iperf.sh - Benchmark réseau avec iperf3

Usage: benchmark-network.iperf.sh -s SERVER [OPTIONS]

OPTIONS:
    -s, --server HOST      Serveur iperf3 (requis)
    -p, --port PORT        Port serveur [défaut: 5201]
    -t, --time SEC         Durée du test [défaut: 10s]
    -P, --parallel NUM     Streams parallèles [défaut: 1]
    -b, --bandwidth BW     Limite de bande passante
    -u, --udp              Utilise UDP au lieu de TCP
    -R, --reverse          Test reverse (serveur->client)
    -d, --bidir            Test bidirectionnel
    -f, --format FORMAT    Format: text|json|csv [défaut: text]
    -n, --dry-run          Simulation
    -v, --verbose          Mode verbeux
    -q, --quiet            Mode silencieux
    -h, --help             Affiche cette aide

EXEMPLES:
    benchmark-network.iperf.sh -s 192.168.1.100
    benchmark-network.iperf.sh -s server.lan -P 4 --bidir
    benchmark-network.iperf.sh -s 10.0.0.1 --udp -b 100M

NOTES:
    - Nécessite iperf3 installé
    - Serveur iperf3 doit être en cours d'exécution
    - Résultats en bits/sec et bytes/sec
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--server) SERVER_HOST="$2"; shift 2 ;;
            -p|--port) SERVER_PORT="$2"; shift 2 ;;
            -t|--time) TEST_DURATION="$2"; shift 2 ;;
            -P|--parallel) PARALLEL_STREAMS="$2"; shift 2 ;;
            -b|--bandwidth) BANDWIDTH="$2"; shift 2 ;;
            -u|--udp) PROTOCOL="udp"; shift ;;
            -R|--reverse) REVERSE=true; shift ;;
            -d|--bidir) BIDIRECTIONAL=true; shift ;;
            -f|--format) OUTPUT_FORMAT="$2"; shift 2 ;;
            -n|--dry-run) DRY_RUN=true; shift ;;
            -v|--verbose) VERBOSE=true; shift ;;
            -q|--quiet) QUIET=true; shift ;;
            -h|--help) show_help; exit 0 ;;
            *) atomic_error "Option inconnue: $1"; return 1 ;;
        esac
    done
    
    if [[ -z "$SERVER_HOST" ]]; then
        atomic_error "Serveur requis (-s|--server)"
        return 1
    fi
    
    if ! [[ "$SERVER_PORT" =~ ^[0-9]+$ ]]; then
        atomic_error "Port invalide: $SERVER_PORT"
        return 1
    fi
    
    if ! [[ "$TEST_DURATION" =~ ^[0-9]+$ ]]; then
        atomic_error "Durée invalide: $TEST_DURATION"
        return 1
    fi
    
    if ! [[ "$PARALLEL_STREAMS" =~ ^[0-9]+$ ]]; then
        atomic_error "Streams invalides: $PARALLEL_STREAMS"
        return 1
    fi
}

check_iperf3() {
    if ! command -v iperf3 >/dev/null 2>&1; then
        atomic_error "iperf3 non trouvé (apt install iperf3)"
        return 1
    fi
    
    # Test de connectivité
    if ! timeout 5 nc -z "$SERVER_HOST" "$SERVER_PORT" 2>/dev/null; then
        atomic_error "Serveur iperf3 inaccessible: $SERVER_HOST:$SERVER_PORT"
        return 1
    fi
}

build_iperf_command() {
    local iperf_cmd="iperf3 -c $SERVER_HOST -p $SERVER_PORT"
    iperf_cmd+=" -t $TEST_DURATION"
    iperf_cmd+=" -P $PARALLEL_STREAMS"
    iperf_cmd+=" --json"
    
    [[ "$PROTOCOL" == "udp" ]] && iperf_cmd+=" -u"
    [[ -n "$BANDWIDTH" ]] && iperf_cmd+=" -b $BANDWIDTH"
    $REVERSE && iperf_cmd+=" -R"
    $BIDIRECTIONAL && iperf_cmd+=" --bidir"
    
    echo "$iperf_cmd"
}

parse_iperf_json() {
    local json_output="$1"
    
    # Extraction des métriques principales
    local start_timestamp end_timestamp
    local sent_bytes sent_bps received_bytes received_bps
    local cpu_local cpu_remote
    local retransmits
    
    start_timestamp=$(echo "$json_output" | jq -r '.start.timestamp.timesecs // empty' 2>/dev/null)
    end_timestamp=$(echo "$json_output" | jq -r '.end.timestamp.timesecs // empty' 2>/dev/null)
    
    sent_bytes=$(echo "$json_output" | jq -r '.end.sum_sent.bytes // empty' 2>/dev/null)
    sent_bps=$(echo "$json_output" | jq -r '.end.sum_sent.bits_per_second // empty' 2>/dev/null)
    
    received_bytes=$(echo "$json_output" | jq -r '.end.sum_received.bytes // empty' 2>/dev/null)
    received_bps=$(echo "$json_output" | jq -r '.end.sum_received.bits_per_second // empty' 2>/dev/null)
    
    cpu_local=$(echo "$json_output" | jq -r '.end.cpu_utilization_percent.host_total // empty' 2>/dev/null)
    cpu_remote=$(echo "$json_output" | jq -r '.end.cpu_utilization_percent.remote_total // empty' 2>/dev/null)
    
    retransmits=$(echo "$json_output" | jq -r '.end.sum_sent.retransmits // empty' 2>/dev/null)
    
    echo "test_start:$start_timestamp"
    echo "test_end:$end_timestamp"
    echo "sent_bytes:${sent_bytes:-0}"
    echo "sent_bits_per_sec:${sent_bps:-0}"
    echo "received_bytes:${received_bytes:-0}"
    echo "received_bits_per_sec:${received_bps:-0}"
    echo "cpu_local_percent:${cpu_local:-0}"
    echo "cpu_remote_percent:${cpu_remote:-0}"
    echo "retransmits:${retransmits:-0}"
}

run_iperf_test() {
    local test_name="$1"
    
    if $DRY_RUN; then
        atomic_info "DRY-RUN: Test iperf3 - $test_name"
        atomic_info "DRY-RUN: Serveur: $SERVER_HOST:$SERVER_PORT"
        atomic_info "DRY-RUN: Durée: ${TEST_DURATION}s, Streams: $PARALLEL_STREAMS"
        return 0
    fi
    
    atomic_info "Exécution test iperf3: $test_name"
    
    local iperf_cmd
    iperf_cmd=$(build_iperf_command)
    
    $VERBOSE && atomic_info "Commande: $iperf_cmd"
    
    local json_result
    if ! json_result=$(eval "$iperf_cmd" 2>/dev/null); then
        atomic_error "Échec du test iperf3: $test_name"
        return 1
    fi
    
    echo "test_name:$test_name"
    echo "server:$SERVER_HOST"
    echo "port:$SERVER_PORT"
    echo "protocol:$PROTOCOL"
    echo "duration_s:$TEST_DURATION"
    echo "parallel_streams:$PARALLEL_STREAMS"
    [[ -n "$BANDWIDTH" ]] && echo "bandwidth_limit:$BANDWIDTH"
    echo "reverse:$REVERSE"
    echo "bidirectional:$BIDIRECTIONAL"
    
    parse_iperf_json "$json_result"
    
    echo "---"
    
    return 0
}

format_bytes_per_sec() {
    local bps="$1"
    
    if [[ $bps -lt 1000 ]]; then
        echo "$bps B/s"
    elif [[ $bps -lt 1000000 ]]; then
        echo "$((bps/1000)) KB/s"
    elif [[ $bps -lt 1000000000 ]]; then
        echo "$((bps/1000000)) MB/s"
    else
        echo "$((bps/1000000000)) GB/s"
    fi
}

format_bits_per_sec() {
    local bps="$1"
    
    if [[ $bps -lt 1000 ]]; then
        echo "$bps bps"
    elif [[ $bps -lt 1000000 ]]; then
        echo "$((bps/1000)) Kbps"
    elif [[ $bps -lt 1000000000 ]]; then
        echo "$((bps/1000000)) Mbps"
    else
        echo "$((bps/1000000000)) Gbps"
    fi
}

format_text_output() {
    echo "=== Benchmark réseau iperf3 ==="
    echo
    
    run_iperf_test "primary" | while IFS=':' read -r key value; do
        case "$key" in
            ---) echo ;;
            *bits_per_sec)
                printf "%-25s: %s (%s)\n" "$key" "$value" "$(format_bits_per_sec "${value%.*}")"
                ;;
            sent_bytes|received_bytes)
                printf "%-25s: %s (%s)\n" "$key" "$value" "$(format_bytes_per_sec "$value")"
                ;;
            *)
                printf "%-25s: %s\n" "$key" "$value"
                ;;
        esac
    done
}

format_json_output() {
    echo "{"
    echo '  "timestamp": "'$(date -Iseconds)'",'
    echo '  "iperf3_benchmark": {'
    
    run_iperf_test "primary" | {
        local json_fields=""
        while IFS=':' read -r key value; do
            [[ "$key" == "---" ]] && break
            [[ -n "$json_fields" ]] && json_fields+=", "
            json_fields+='"'$key'": "'$value'"'
        done
        echo "    $json_fields"
    }
    
    echo "  }"
    echo "}"
}

format_csv_output() {
    echo "timestamp,test_name,server,port,protocol,duration_s,parallel_streams,bandwidth_limit,reverse,bidirectional,sent_bytes,sent_bits_per_sec,received_bytes,received_bits_per_sec,cpu_local_percent,cpu_remote_percent,retransmits"
    
    local timestamp
    timestamp=$(date -Iseconds)
    
    run_iperf_test "primary" | {
        local values=("$timestamp")
        while IFS=':' read -r key value; do
            [[ "$key" == "---" ]] && break
            values+=("$value")
        done
        IFS=','; echo "${values[*]}"
    }
}

main() {
    atomic_init_logging "${BASH_SOURCE[0]##*/}" "$QUIET"
    parse_args "$@" || { show_help >&2; return 1; }
    
    if ! $DRY_RUN; then
        check_iperf3 || return 1
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        atomic_error "jq requis pour parser JSON (apt install jq)"
        return 1
    fi
    
    case "$OUTPUT_FORMAT" in
        text) format_text_output ;;
        json) format_json_output ;;
        csv) format_csv_output ;;
        *) atomic_error "Format invalide: $OUTPUT_FORMAT"; return 1 ;;
    esac
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"