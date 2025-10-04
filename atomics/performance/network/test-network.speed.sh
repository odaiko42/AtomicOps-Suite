#!/usr/bin/env bash
# test-network.speed.sh - Test de débit réseau avec serveurs externes

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(realpath "$SCRIPT_DIR/../../../lib")"
[[ -f "$LIB_DIR/lib-atomics-common.sh" ]] && source "$LIB_DIR/lib-atomics-common.sh"

OUTPUT_FORMAT="text"
TARGET_HOST=""
TEST_SIZE="10M"
TEST_COUNT=3
TIMEOUT=30
INTERFACE=""
VERBOSE=false
QUIET=false
DRY_RUN=false

show_help() {
    cat << 'EOF'
test-network.speed.sh - Test de débit réseau avec serveurs externes

Usage: test-network.speed.sh [OPTIONS]

OPTIONS:
    -h, --host HOST        Serveur de test (ou auto pour speedtest-cli)
    -s, --size SIZE        Taille du test [défaut: 10M]
    -c, --count NUM        Nombre de tests [défaut: 3]
    -t, --timeout SEC      Timeout [défaut: 30s]
    -i, --interface IF     Interface réseau
    -f, --format FORMAT    Format: text|json|csv [défaut: text]
    -n, --dry-run          Simulation
    -v, --verbose          Mode verbeux
    -q, --quiet            Mode silencieux
        --help             Affiche cette aide

EXEMPLES:
    test-network.speed.sh --host auto
    test-network.speed.sh -h 8.8.8.8 -s 50M
    test-network.speed.sh --host speedtest.net --count 5

NOTES:
    - Sans --host, utilise plusieurs serveurs de test
    - --host auto utilise speedtest-cli si disponible
    - Test basé sur curl/wget pour téléchargements
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--host) TARGET_HOST="$2"; shift 2 ;;
            -s|--size) TEST_SIZE="$2"; shift 2 ;;
            -c|--count) TEST_COUNT="$2"; shift 2 ;;
            -t|--timeout) TIMEOUT="$2"; shift 2 ;;
            -i|--interface) INTERFACE="$2"; shift 2 ;;
            -f|--format) OUTPUT_FORMAT="$2"; shift 2 ;;
            -n|--dry-run) DRY_RUN=true; shift ;;
            -v|--verbose) VERBOSE=true; shift ;;
            -q|--quiet) QUIET=true; shift ;;
            --help) show_help; exit 0 ;;
            *) atomic_error "Option inconnue: $1"; return 1 ;;
        esac
    done
    
    if ! [[ "$TEST_COUNT" =~ ^[0-9]+$ ]]; then
        atomic_error "Count invalide: $TEST_COUNT"
        return 1
    fi
    
    if ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]]; then
        atomic_error "Timeout invalide: $TIMEOUT"
        return 1
    fi
}

get_test_targets() {
    if [[ "$TARGET_HOST" == "auto" ]]; then
        if command -v speedtest-cli >/dev/null 2>&1; then
            echo "speedtest-cli"
        else
            atomic_warn "speedtest-cli non disponible, utilisation des tests manuels"
            get_manual_targets
        fi
    elif [[ -n "$TARGET_HOST" ]]; then
        echo "custom:$TARGET_HOST"
    else
        get_manual_targets
    fi
}

get_manual_targets() {
    # Serveurs de test courants avec des fichiers de test
    cat << 'EOF'
http://speedtest.ftp.otenet.gr/files/test1Mb.db:1M
http://speedtest.ftp.otenet.gr/files/test10Mb.db:10M
http://ipv4.download.thinkbroadband.com/5MB.zip:5M
http://ipv4.download.thinkbroadband.com/10MB.zip:10M
EOF
}

run_speedtest_cli() {
    if $DRY_RUN; then
        atomic_info "DRY-RUN: speedtest-cli --simple"
        return 0
    fi
    
    atomic_info "Exécution de speedtest-cli"
    
    local output
    if ! output=$(timeout "$TIMEOUT" speedtest-cli --simple 2>/dev/null); then
        atomic_error "Échec de speedtest-cli"
        return 1
    fi
    
    # Parse la sortie
    local ping download upload
    ping=$(echo "$output" | grep "Ping:" | awk '{print $2}')
    download=$(echo "$output" | grep "Download:" | awk '{print $2}')
    upload=$(echo "$output" | grep "Upload:" | awk '{print $2}')
    
    echo "method:speedtest-cli"
    echo "ping_ms:$ping"
    echo "download_mbps:$download"
    echo "upload_mbps:$upload"
    echo "test_server:auto"
    echo "---"
}

run_curl_test() {
    local url="$1"
    local expected_size="$2"
    
    if $DRY_RUN; then
        atomic_info "DRY-RUN: curl test vers $url"
        return 0
    fi
    
    local temp_file="/tmp/network_speed_test.$$"
    local curl_cmd="curl -L -s -w '%{speed_download}:%{time_total}:%{size_download}'"
    
    [[ -n "$INTERFACE" ]] && curl_cmd+=" --interface $INTERFACE"
    curl_cmd+=" --max-time $TIMEOUT -o $temp_file '$url'"
    
    atomic_info "Test de téléchargement: $url"
    
    local result
    if ! result=$(eval "$curl_cmd" 2>/dev/null); then
        rm -f "$temp_file"
        atomic_error "Échec du test curl: $url"
        return 1
    fi
    
    rm -f "$temp_file"
    
    IFS=':' read -r speed_bps time_total size_bytes <<< "$result"
    
    # Conversion en Mbps
    local speed_mbps
    speed_mbps=$(echo "scale=2; $speed_bps * 8 / 1000000" | bc -l 2>/dev/null || echo "0")
    
    echo "method:curl"
    echo "test_url:$url"
    echo "expected_size:$expected_size"
    echo "actual_size_bytes:$size_bytes"
    echo "time_total_s:$time_total"
    echo "speed_bytes_per_sec:${speed_bps%.*}"
    echo "speed_mbps:$speed_mbps"
    echo "---"
    
    return 0
}

run_ping_test() {
    local host="$1"
    
    if $DRY_RUN; then
        atomic_info "DRY-RUN: ping test vers $host"
        return 0
    fi
    
    atomic_info "Test de latence: $host"
    
    local ping_result
    if ! ping_result=$(ping -c 4 -W 5 "$host" 2>/dev/null | tail -1); then
        atomic_error "Échec du ping: $host"
        return 1
    fi
    
    # Parse: round-trip min/avg/max/stddev = 10.1/15.2/20.3/4.5 ms
    local stats
    stats=$(echo "$ping_result" | grep -o '[0-9.]*/[0-9.]*/[0-9.]*/[0-9.]*' | head -1)
    
    if [[ -n "$stats" ]]; then
        IFS='/' read -r min_ms avg_ms max_ms stddev_ms <<< "$stats"
        echo "ping_host:$host"
        echo "ping_min_ms:$min_ms"
        echo "ping_avg_ms:$avg_ms"
        echo "ping_max_ms:$max_ms"
        echo "ping_stddev_ms:$stddev_ms"
        echo "---"
    fi
}

run_network_tests() {
    echo "timestamp:$(date -Iseconds)"
    echo "test_count:$TEST_COUNT"
    echo "timeout_s:$TIMEOUT"
    [[ -n "$INTERFACE" ]] && echo "interface:$INTERFACE"
    
    get_test_targets | while read -r target; do
        [[ -z "$target" ]] && continue
        
        if [[ "$target" == "speedtest-cli" ]]; then
            run_speedtest_cli
        elif [[ "$target" =~ ^custom: ]]; then
            local host="${target#custom:}"
            run_ping_test "$host"
            # Test de téléchargement basique si possible
            if [[ "$host" =~ ^https?:// ]]; then
                for ((i=1; i<=TEST_COUNT; i++)); do
                    run_curl_test "$host" "$TEST_SIZE"
                done
            fi
        else
            # Format: URL:SIZE
            local url="${target%:*}"
            local size="${target#*:}"
            
            for ((i=1; i<=TEST_COUNT; i++)); do
                run_curl_test "$url" "$size"
            done
        fi
    done
}

format_text_output() {
    echo "=== Test de vitesse réseau ==="
    echo
    
    run_network_tests | while IFS=':' read -r key value; do
        case "$key" in
            ---) echo ;;
            *_mbps|*_bps) printf "%-25s: %s\n" "$key" "$value" ;;
            *) printf "%-25s: %s\n" "$key" "$value" ;;
        esac
    done
}

format_json_output() {
    echo "{"
    echo '  "network_speed_tests": ['
    
    local first_test=true
    local current_test=""
    
    run_network_tests | while IFS=':' read -r key value; do
        if [[ "$key" == "---" ]]; then
            if [[ -n "$current_test" ]]; then
                $first_test || echo ","
                echo "    { $current_test }"
                first_test=false
                current_test=""
            fi
        else
            [[ -n "$current_test" ]] && current_test+=", "
            current_test+='"'$key'": "'$value'"'
        fi
    done
    
    [[ -n "$current_test" ]] && {
        $first_test || echo ","
        echo "    { $current_test }"
    }
    
    echo "  ]"
    echo "}"
}

format_csv_output() {
    echo "timestamp,method,test_details,speed_mbps,additional_metrics"
    
    local timestamp
    timestamp=$(date -Iseconds)
    
    run_network_tests | {
        local method="" speed="" details=""
        while IFS=':' read -r key value; do
            if [[ "$key" == "---" ]]; then
                [[ -n "$method" && -n "$speed" ]] && echo "$timestamp,$method,$details,$speed,additional"
                method="" speed="" details=""
            else
                case "$key" in
                    method) method="$value" ;;
                    *_mbps|speed_mbps) speed="$value" ;;
                    *) details+="$key=$value;" ;;
                esac
            fi
        done
        [[ -n "$method" && -n "$speed" ]] && echo "$timestamp,$method,$details,$speed,additional"
    }
}

main() {
    atomic_init_logging "${BASH_SOURCE[0]##*/}" "$QUIET"
    parse_args "$@" || { show_help >&2; return 1; }
    
    if ! command -v curl >/dev/null 2>&1; then
        atomic_error "curl requis pour les tests de débit"
        return 1
    fi
    
    if ! command -v bc >/dev/null 2>&1; then
        atomic_error "bc requis pour les calculs"
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