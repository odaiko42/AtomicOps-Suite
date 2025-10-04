#!/usr/bin/env bash

# ===================================================================
# Script: clear-memory.cache.sh
# Description: Vide les caches mémoire
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

VERBOSE=false
QUIET=false
DRY_RUN=false
CACHE_TYPE="all"

show_help() {
    cat << 'EOF'
clear-memory.cache.sh - Vide les caches mémoire

SYNOPSIS:
    clear-memory.cache.sh [OPTIONS]

DESCRIPTION:
    Libère les caches mémoire système :
    - Page cache (1), dentries/inodes (2), ou tout (3)
    - Synchronisation préalable des données
    - Affichage de la mémoire libérée
    
ATTENTION: Nécessite les permissions root
    
OPTIONS:
    -t, --type TYPE     Type de cache (pagecache|dentries|all) [défaut: all]
    -n, --dry-run       Simulation sans modification
    -v, --verbose       Mode verbeux
    -q, --quiet         Mode silencieux
    -h, --help          Affiche cette aide

CODES DE RETOUR:
    0    Succès
    1    Erreur générale
    2    Permissions insuffisantes
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--type)
                case "$2" in
                    pagecache|dentries|all) CACHE_TYPE="$2" ;;
                    *) atomic_error "Type invalide: $2"; return 1 ;;
                esac
                shift 2 ;;
            -n|--dry-run) DRY_RUN=true; shift ;;
            -v|--verbose) VERBOSE=true; shift ;;
            -q|--quiet) QUIET=true; shift ;;
            -h|--help) show_help; exit 0 ;;
            *) atomic_error "Option inconnue: $1"; return 1 ;;
        esac
    done
}

get_memory_before() {
    BEFORE_FREE=$(awk '/MemFree/ {print $2}' /proc/meminfo)
    BEFORE_CACHED=$(awk '/^Cached/ {print $2}' /proc/meminfo)
    BEFORE_BUFFERS=$(awk '/Buffers/ {print $2}' /proc/meminfo)
}

get_memory_after() {
    AFTER_FREE=$(awk '/MemFree/ {print $2}' /proc/meminfo)
    AFTER_CACHED=$(awk '/^Cached/ {print $2}' /proc/meminfo)
    AFTER_BUFFERS=$(awk '/Buffers/ {print $2}' /proc/meminfo)
    
    FREED_KB=$(( (AFTER_FREE + AFTER_CACHED + AFTER_BUFFERS) - (BEFORE_FREE + BEFORE_CACHED + BEFORE_BUFFERS) ))
    FREED_MB=$(( FREED_KB / 1024 ))
}

clear_caches() {
    local drop_value
    
    case "$CACHE_TYPE" in
        pagecache) drop_value=1 ;;
        dentries) drop_value=2 ;;
        all) drop_value=3 ;;
    esac
    
    if $DRY_RUN; then
        atomic_info "DRY-RUN: Effacement cache type $CACHE_TYPE (echo $drop_value > /proc/sys/vm/drop_caches)"
        return 0
    fi
    
    # Synchronisation des données
    if ! sync; then
        atomic_error "Erreur lors de la synchronisation"
        return 1
    fi
    
    # Vidage des caches
    if ! echo "$drop_value" > /proc/sys/vm/drop_caches 2>/dev/null; then
        atomic_error "Impossible d'écrire dans /proc/sys/vm/drop_caches"
        atomic_info "Permissions root requises"
        return 2
    fi
    
    return 0
}

main() {
    atomic_init_logging "$SCRIPT_NAME" "$QUIET"
    
    parse_args "$@" || { show_help >&2; return 1; }
    
    if ! $DRY_RUN && [[ $EUID -ne 0 ]]; then
        atomic_error "Permissions root requises"
        return 2
    fi
    
    if $VERBOSE; then
        atomic_info "Vidage des caches: $CACHE_TYPE"
    fi
    
    get_memory_before
    
    if ! clear_caches; then
        return $?
    fi
    
    sleep 1
    get_memory_after
    
    if ! $QUIET; then
        if $DRY_RUN; then
            atomic_info "Simulation du vidage des caches $CACHE_TYPE"
        else
            atomic_success "Caches vidés - Mémoire libérée: ${FREED_MB} MB"
        fi
    fi
    
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi