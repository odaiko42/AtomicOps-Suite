#!/usr/bin/env bash
# benchmark-disk.speed.sh - Benchmark de vitesse disque

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(realpath "$SCRIPT_DIR/../../../lib")"
[[ -f "$LIB_DIR/lib-atomics-common.sh" ]] && source "$LIB_DIR/lib-atomics-common.sh"

OUTPUT_FORMAT="text"
TARGET_PATH=""
FILE_SIZE="1G"
BLOCK_SIZE="1M"
TEST_TYPES="write,read"
VERBOSE=false
QUIET=false
DRY_RUN=false

show_help() {
    cat << 'EOF'
benchmark-disk.speed.sh - Benchmark de vitesse disque

Usage: benchmark-disk.speed.sh -p PATH [OPTIONS]

OPTIONS:
    -p, --path PATH        Répertoire de test (requis)
    -s, --size SIZE        Taille du fichier [défaut: 1G]
    -b, --block-size SIZE  Taille des blocs [défaut: 1M]
    -t, --tests TYPES      Tests: write,read,both [défaut: write,read]
    -f, --format FORMAT    Format: text|json|csv [défaut: text]
    -n, --dry-run          Simulation
    -v, --verbose          Mode verbeux
    -q, --quiet            Mode silencieux
    -h, --help             Affiche cette aide

EXEMPLES:
    benchmark-disk.speed.sh -p /tmp
    benchmark-disk.speed.sh -p /mnt/disk1 -s 500M --tests write
    benchmark-disk.speed.sh -p /home --size 2G --format json

NOTES:
    - Test destructeur (crée/supprime des fichiers)
    - Espace disque requis: taille du fichier × 2
    - Résultats en MB/s (1MB = 1000000 bytes)
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--path) TARGET_PATH="$2"; shift 2 ;;
            -s|--size) FILE_SIZE="$2"; shift 2 ;;
            -b|--block-size) BLOCK_SIZE="$2"; shift 2 ;;
            -t|--tests) TEST_TYPES="$2"; shift 2 ;;
            -f|--format) OUTPUT_FORMAT="$2"; shift 2 ;;
            -n|--dry-run) DRY_RUN=true; shift ;;
            -v|--verbose) VERBOSE=true; shift ;;
            -q|--quiet) QUIET=true; shift ;;
            -h|--help) show_help; exit 0 ;;
            *) atomic_error "Option inconnue: $1"; return 1 ;;
        esac
    done
    
    if [[ -z "$TARGET_PATH" ]]; then
        atomic_error "Chemin requis (-p|--path)"
        return 1
    fi
    
    if [[ ! -d "$TARGET_PATH" ]]; then
        atomic_error "Répertoire inexistant: $TARGET_PATH"
        return 1
    fi
    
    if ! [[ "$TEST_TYPES" =~ ^(write|read|both|write,read|read,write)$ ]]; then
        atomic_error "Tests invalides: $TEST_TYPES (write|read|both)"
        return 1
    fi
}

convert_size_to_bytes() {
    local size="$1"
    local number="${size%[KMGT]*}"
    local unit="${size: -1}"
    
    case "$unit" in
        K|k) echo $((number * 1024)) ;;
        M|m) echo $((number * 1024 * 1024)) ;;
        G|g) echo $((number * 1024 * 1024 * 1024)) ;;
        T|t) echo $((number * 1024 * 1024 * 1024 * 1024)) ;;
        *) echo "$number" ;;
    esac
}

get_block_count() {
    local file_bytes
    local block_bytes
    
    file_bytes=$(convert_size_to_bytes "$FILE_SIZE")
    block_bytes=$(convert_size_to_bytes "$BLOCK_SIZE")
    
    echo $((file_bytes / block_bytes))
}

check_space() {
    local required_bytes
    required_bytes=$(convert_size_to_bytes "$FILE_SIZE")
    required_bytes=$((required_bytes * 2))  # Pour write + read
    
    local available_bytes
    available_bytes=$(df --output=avail "$TARGET_PATH" | tail -1)
    available_bytes=$((available_bytes * 1024))
    
    if [[ $available_bytes -lt $required_bytes ]]; then
        atomic_error "Espace insuffisant: $(($required_bytes / 1024 / 1024))MB requis"
        return 1
    fi
}

benchmark_write() {
    local test_file="$TARGET_PATH/benchmark_write.$$"
    local block_count
    block_count=$(get_block_count)
    
    atomic_info "Test d'écriture: $FILE_SIZE ($block_count × $BLOCK_SIZE)"
    
    local start_time
    start_time=$(date +%s.%3N)
    
    if ! dd if=/dev/zero of="$test_file" bs="$BLOCK_SIZE" count="$block_count" conv=fsync 2>/dev/null; then
        atomic_error "Erreur lors du test d'écriture"
        rm -f "$test_file"
        return 1
    fi
    
    local end_time
    end_time=$(date +%s.%3N)
    
    local duration
    duration=$(echo "$end_time - $start_time" | bc -l)
    
    local bytes_written
    bytes_written=$(convert_size_to_bytes "$FILE_SIZE")
    
    local speed_mbps
    speed_mbps=$(echo "scale=2; $bytes_written / $duration / 1000000" | bc -l)
    
    echo "write_speed_mbps:$speed_mbps"
    echo "write_duration_s:$duration"
    echo "write_bytes:$bytes_written"
    echo "write_test_file:$test_file"
    
    return 0
}

benchmark_read() {
    local test_file="$TARGET_PATH/benchmark_write.$$"
    
    if [[ ! -f "$test_file" ]]; then
        # Créer le fichier s'il n'existe pas
        atomic_info "Création du fichier de test pour la lecture"
        benchmark_write >/dev/null || return 1
    fi
    
    atomic_info "Test de lecture: $FILE_SIZE"
    
    # Clear cache si possible
    sync 2>/dev/null || true
    [[ -w /proc/sys/vm/drop_caches ]] && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
    
    local start_time
    start_time=$(date +%s.%3N)
    
    if ! dd if="$test_file" of=/dev/null bs="$BLOCK_SIZE" 2>/dev/null; then
        atomic_error "Erreur lors du test de lecture"
        rm -f "$test_file"
        return 1
    fi
    
    local end_time
    end_time=$(date +%s.%3N)
    
    local duration
    duration=$(echo "$end_time - $start_time" | bc -l)
    
    local bytes_read
    bytes_read=$(convert_size_to_bytes "$FILE_SIZE")
    
    local speed_mbps
    speed_mbps=$(echo "scale=2; $bytes_read / $duration / 1000000" | bc -l)
    
    echo "read_speed_mbps:$speed_mbps"
    echo "read_duration_s:$duration"
    echo "read_bytes:$bytes_read"
    echo "read_test_file:$test_file"
    
    # Nettoyage
    rm -f "$test_file"
    
    return 0
}

run_benchmarks() {
    if $DRY_RUN; then
        atomic_info "DRY-RUN: Benchmark sur $TARGET_PATH"
        atomic_info "DRY-RUN: Taille: $FILE_SIZE, Blocs: $BLOCK_SIZE"
        atomic_info "DRY-RUN: Tests: $TEST_TYPES"
        return 0
    fi
    
    check_space || return 1
    
    echo "target_path:$TARGET_PATH"
    echo "file_size:$FILE_SIZE"
    echo "block_size:$BLOCK_SIZE"
    echo "timestamp:$(date -Iseconds)"
    
    local do_write=false do_read=false
    
    [[ "$TEST_TYPES" =~ write|both ]] && do_write=true
    [[ "$TEST_TYPES" =~ read|both ]] && do_read=true
    
    if $do_write; then
        benchmark_write || return 1
    fi
    
    if $do_read; then
        benchmark_read || return 1
    fi
    
    echo "---"
}

format_text_output() {
    echo "=== Benchmark vitesse disque ==="
    echo
    
    run_benchmarks | while IFS=':' read -r key value; do
        [[ "$key" == "---" ]] && return
        printf "%-20s: %s\n" "$key" "$value"
    done
}

format_json_output() {
    echo "{"
    
    local json_data=""
    run_benchmarks | while IFS=':' read -r key value; do
        [[ "$key" == "---" ]] && break
        [[ -n "$json_data" ]] && json_data+=", "
        json_data+='"'$key'": "'$value'"'
    done
    
    echo "  $json_data"
    echo "}"
}

format_csv_output() {
    # En-tête dynamique basé sur les tests
    local headers="timestamp,target_path,file_size,block_size"
    
    [[ "$TEST_TYPES" =~ write|both ]] && headers+=",write_speed_mbps,write_duration_s,write_bytes"
    [[ "$TEST_TYPES" =~ read|both ]] && headers+=",read_speed_mbps,read_duration_s,read_bytes"
    
    echo "$headers"
    
    # Données
    local values=()
    run_benchmarks | while IFS=':' read -r key value; do
        [[ "$key" == "---" ]] && break
        values+=("$value")
    done
    
    IFS=','; echo "${values[*]}"
}

main() {
    atomic_init_logging "${BASH_SOURCE[0]##*/}" "$QUIET"
    parse_args "$@" || { show_help >&2; return 1; }
    
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