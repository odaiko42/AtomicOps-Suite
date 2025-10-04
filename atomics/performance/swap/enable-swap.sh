#!/usr/bin/env bash
# enable-swap.sh - Active un fichier ou partition swap

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(realpath "$SCRIPT_DIR/../../../lib")"
[[ -f "$LIB_DIR/lib-atomics-common.sh" ]] && source "$LIB_DIR/lib-atomics-common.sh"

SWAP_TARGET=""
PRIORITY=""
VERBOSE=false
QUIET=false
DRY_RUN=false

show_help() {
    cat << 'EOF'
enable-swap.sh - Active un fichier ou partition swap

Usage: enable-swap.sh SWAP_TARGET [OPTIONS]

ARGUMENTS:
    SWAP_TARGET            Fichier ou partition swap

OPTIONS:
    -p, --priority NUM     Priorité swap (0-32767)
    -n, --dry-run          Simulation
    -v, --verbose          Mode verbeux
    -q, --quiet            Mode silencieux
    -h, --help             Affiche cette aide

EXEMPLES:
    enable-swap.sh /swapfile
    enable-swap.sh /dev/sda2 -p 10
    enable-swap.sh /var/swap/file1 --priority 5

ATTENTION: Nécessite les permissions root
EOF
}

parse_args() {
    [[ $# -eq 0 ]] && { show_help >&2; return 1; }
    
    SWAP_TARGET="$1"; shift
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--priority) PRIORITY="$2"; shift 2 ;;
            -n|--dry-run) DRY_RUN=true; shift ;;
            -v|--verbose) VERBOSE=true; shift ;;
            -q|--quiet) QUIET=true; shift ;;
            -h|--help) show_help; exit 0 ;;
            *) atomic_error "Option inconnue: $1"; return 1 ;;
        esac
    done
    
    [[ -z "$SWAP_TARGET" ]] && { atomic_error "Target swap requis"; return 1; }
}

validate_target() {
    if [[ ! -e "$SWAP_TARGET" ]]; then
        atomic_error "Target inexistant: $SWAP_TARGET"
        return 1
    fi
    
    if [[ -n "$PRIORITY" ]] && ! [[ "$PRIORITY" =~ ^[0-9]+$ ]]; then
        atomic_error "Priorité invalide: $PRIORITY (0-32767)"
        return 1
    fi
}

check_swap_status() {
    if grep -q "^$(realpath "$SWAP_TARGET")" /proc/swaps 2>/dev/null; then
        atomic_info "Le swap est déjà actif: $SWAP_TARGET"
        return 2
    fi
    return 0
}

enable_swap() {
    if $DRY_RUN; then
        atomic_info "DRY-RUN: Activation swap $SWAP_TARGET"
        [[ -n "$PRIORITY" ]] && atomic_info "DRY-RUN: Priorité: $PRIORITY"
        return 0
    fi
    
    if [[ $EUID -ne 0 ]]; then
        atomic_error "Permissions root requises"
        return 2
    fi
    
    check_swap_status || return $?
    
    # Construction de la commande
    local swapon_cmd="swapon"
    [[ -n "$PRIORITY" ]] && swapon_cmd+=" -p $PRIORITY"
    swapon_cmd+=" $SWAP_TARGET"
    
    atomic_info "Activation du swap: $SWAP_TARGET"
    [[ -n "$PRIORITY" ]] && atomic_info "Priorité: $PRIORITY"
    
    if ! eval "$swapon_cmd" 2>/dev/null; then
        atomic_error "Erreur d'activation du swap"
        return 1
    fi
    
    # Vérification
    if grep -q "^$(realpath "$SWAP_TARGET")" /proc/swaps 2>/dev/null; then
        atomic_success "Swap activé avec succès: $SWAP_TARGET"
        
        # Affichage des infos
        if $VERBOSE; then
            atomic_info "Statut swap actuel:"
            swapon --show 2>/dev/null || true
        fi
        
        return 0
    else
        atomic_error "Échec de vérification après activation"
        return 1
    fi
}

main() {
    atomic_init_logging "${BASH_SOURCE[0]##*/}" "$QUIET"
    parse_args "$@" || { show_help >&2; return 1; }
    validate_target || return 1
    enable_swap
    return $?
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"