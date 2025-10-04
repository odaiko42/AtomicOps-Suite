#!/usr/bin/env bash
# check-disk.latency.sh - Vérifie la latence des disques

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(realpath "$SCRIPT_DIR/../../../lib")"
[[ -f "$LIB_DIR/lib-atomics-common.sh" ]] && source "$LIB_DIR/lib-atomics-common.sh"

OUTPUT_FORMAT="text"
DEVICE=""
TEST_SIZE="1M"
TEST_COUNT=10
THRESHOLD_MS=100
VERBOSE=false
QUIET=false
DRY_RUN=false

show_help() {
    cat << 'EOF'
check-disk.latency.sh - Vérifie la latence des disques

Usage: check-disk.latency.sh [OPTIONS]

OPTIONS:
    -d, --device DEV       Périphérique à tester
    -s, --size SIZE        Taille du test [défaut: 1M]
    -c, --count NUM        Nombre de tests [défaut: 10]
    -t, --threshold MS     Seuil d'alerte (ms) [défaut: 100]
    -f, --format FORMAT    Format: text|json|csv [défaut: text]
    -n, --dry-run          Simulation
    -v, --verbose          Mode verbeux
    -q, --quiet            Mode silencieux
    -h, --help             Affiche cette aide

EXEMPLES:
    check-disk.latency.sh -d /dev/sda
    check-disk.latency.sh --device /tmp --count 20
    check-disk.latency.sh -d /dev/nvme0n1 -t 50 --format json

NOTES:
    - Test non-destructif utilisant dd
    - Sans -d, teste tous les disques montés
    - Seuil recommandé: HDD=100ms, SSD=10ms, NVMe=1ms
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--device) DEVICE="$2"; shift 2 ;;
            -s|--size) TEST_SIZE="$2"; shift 2 ;;
            -c|--count) TEST_COUNT="$2"; shift 2 ;;
            -t|--threshold) THRESHOLD_MS="$2"; shift 2 ;;
            -f|--format) OUTPUT_FORMAT="$2"; shift 2 ;;
            -n|--dry-run) DRY_RUN=true; shift ;;
            -v|--verbose) VERBOSE=true; shift ;;
            -q|--quiet) QUIET=true; shift ;;
            -h|--help) show_help; exit 0 ;;
            *) atomic_error "Option inconnue: $1"; return 1 ;;
        esac
    done
    
    if ! [[ "$TEST_COUNT" =~ ^[0-9]+$ ]]; then
        atomic_error "Count invalide: $TEST_COUNT"
        return 1
    fi
    
    if ! [[ "$THRESHOLD_MS" =~ ^[0-9]+$ ]]; then
        atomic_error "Threshold invalide: $THRESHOLD_MS"
        return 1
    fi
}

get_mount_points() {
    if [[ -n "$DEVICE" ]]; then
        if [[ -b "$DEVICE" ]]; then
            # Block device - trouve le point de montage
            mount | grep "^$DEVICE " | awk '{print $3}' | head -1
        elif [[ -d "$DEVICE" ]]; then
            # Directory
            echo "$DEVICE"
        else
            atomic_error "Device invalide: $DEVICE"
            return 1
        fi
    else
        # Tous les systèmes de fichiers locaux
        df -t ext2 -t ext3 -t ext4 -t xfs -t btrfs | awk 'NR>1 {print $6}'
    fi
}

test_latency() {
    local target_dir="$1"
    local test_file="$target_dir/.latency_test.$$"
    
    # Vérification des permissions
    if ! touch "$test_file" 2>/dev/null; then
        atomic_error "Pas d'accès en écriture: $target_dir"
        return 1
    fi
    
    rm -f "$test_file"
    
    if $DRY_RUN; then
        atomic_info "DRY-RUN: Test latence sur $target_dir ($TEST_COUNT tests de $TEST_SIZE)"
        return 0
    fi
    
    local total_time=0
    local min_time=999999
    local max_time=0
    local times=()
    
    atomic_info "Test de latence: $target_dir ($TEST_COUNT × $TEST_SIZE)"
    
    for ((i=1; i<=TEST_COUNT; i++)); do
        local start_time
        start_time=$(date +%s.%3N)
        
        # Test d'écriture + sync
        dd if=/dev/zero of="$test_file" bs="$TEST_SIZE" count=1 conv=fsync 2>/dev/null || {
            rm -f "$test_file"
            atomic_error "Erreur dd pour $target_dir"
            return 1
        }
        
        local end_time
        end_time=$(date +%s.%3N)
        
        rm -f "$test_file"
        
        # Calcul de la latence en ms
        local latency_ms
        latency_ms=$(echo "($end_time - $start_time) * 1000" | bc -l 2>/dev/null)
        latency_ms=${latency_ms%.*}  # Tronquer les décimales
        
        times+=("$latency_ms")
        total_time=$((total_time + latency_ms))
        
        [[ $latency_ms -lt $min_time ]] && min_time=$latency_ms
        [[ $latency_ms -gt $max_time ]] && max_time=$latency_ms
        
        $VERBOSE && atomic_info "Test $i: ${latency_ms}ms"
    done
    
    # Statistiques
    local avg_time=$((total_time / TEST_COUNT))
    local status="OK"
    
    [[ $avg_time -gt $THRESHOLD_MS ]] && status="WARNING"
    [[ $max_time -gt $((THRESHOLD_MS * 2)) ]] && status="CRITICAL"
    
    echo "target:$target_dir"
    echo "avg_latency_ms:$avg_time"
    echo "min_latency_ms:$min_time"
    echo "max_latency_ms:$max_time"
    echo "threshold_ms:$THRESHOLD_MS"
    echo "status:$status"
    echo "test_count:$TEST_COUNT"
    echo "test_size:$TEST_SIZE"
    echo "---"
    
    return 0
}

format_text_output() {
    echo "=== Test de latence disque ==="
    echo
    
    get_mount_points | while read -r mount_point; do
        [[ -z "$mount_point" ]] && continue
        
        test_latency "$mount_point" | while IFS=':' read -r key value; do
            [[ "$key" == "---" ]] && { echo; continue; }
            printf "%-20s: %s\n" "$key" "$value"
        done
    done
}

format_json_output() {
    echo "{"
    echo '  "timestamp": "'$(date -Iseconds)'",'
    echo '  "latency_tests": ['
    
    local first=true
    get_mount_points | while read -r mount_point; do
        [[ -z "$mount_point" ]] && continue
        
        $first || echo ","
        echo "    {"
        
        test_latency "$mount_point" | {
            local json_fields=""
            while IFS=':' read -r key value; do
                [[ "$key" == "---" ]] && break
                [[ -n "$json_fields" ]] && json_fields+=","
                json_fields+='"'$key'": "'$value'"'
            done
            echo "      $json_fields"
        }
        
        echo -n "    }"
        first=false
    done
    
    echo
    echo "  ]"
    echo "}"
}

format_csv_output() {
    echo "timestamp,target,avg_latency_ms,min_latency_ms,max_latency_ms,threshold_ms,status,test_count,test_size"
    
    local timestamp
    timestamp=$(date -Iseconds)
    
    get_mount_points | while read -r mount_point; do
        [[ -z "$mount_point" ]] && continue
        
        test_latency "$mount_point" | {
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
    
    # Vérification des dépendances
    if ! command -v bc >/dev/null 2>&1; then
        atomic_error "bc requis pour les calculs de latence"
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