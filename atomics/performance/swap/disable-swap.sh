#!/usr/bin/env bash
# disable-swap.sh - Désactive un fichier ou partition swap

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(realpath "$SCRIPT_DIR/../../../lib")"
[[ -f "$LIB_DIR/lib-atomics-common.sh" ]] && source "$LIB_DIR/lib-atomics-common.sh"

SWAP_TARGET=""
ALL_SWAP=false
DELETE_FILE=false
VERBOSE=false
QUIET=false
DRY_RUN=false

show_help() {
    cat << 'EOF'
disable-swap.sh - Désactive un fichier ou partition swap

Usage: disable-swap.sh [SWAP_TARGET] [OPTIONS]

ARGUMENTS:
    SWAP_TARGET            Fichier ou partition swap spécifique

OPTIONS:
    -a, --all              Désactive tous les swaps
    -d, --delete           Supprime le fichier après désactivation
    -n, --dry-run          Simulation
    -v, --verbose          Mode verbeux
    -q, --quiet            Mode silencieux
    -h, --help             Affiche cette aide

EXEMPLES:
    disable-swap.sh /swapfile
    disable-swap.sh /dev/sda2
    disable-swap.sh --all
    disable-swap.sh /swapfile --delete

ATTENTION: Nécessite les permissions root
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -a|--all) ALL_SWAP=true; shift ;;
            -d|--delete) DELETE_FILE=true; shift ;;
            -n|--dry-run) DRY_RUN=true; shift ;;
            -v|--verbose) VERBOSE=true; shift ;;
            -q|--quiet) QUIET=true; shift ;;
            -h|--help) show_help; exit 0 ;;
            -*) atomic_error "Option inconnue: $1"; return 1 ;;
            *) SWAP_TARGET="$1"; shift ;;
        esac
    done
    
    if [[ "$ALL_SWAP" == false && -z "$SWAP_TARGET" ]]; then
        atomic_error "Target swap requis ou utiliser --all"
        return 1
    fi
}

validate_target() {
    if [[ "$ALL_SWAP" == false ]]; then
        if [[ ! -e "$SWAP_TARGET" ]]; then
            atomic_error "Target inexistant: $SWAP_TARGET"
            return 1
        fi
        
        if ! grep -q "^$(realpath "$SWAP_TARGET")" /proc/swaps 2>/dev/null; then
            atomic_info "Le swap n'est pas actif: $SWAP_TARGET"
            return 2
        fi
    fi
    
    if $DELETE_FILE && $ALL_SWAP; then
        atomic_error "Option --delete incompatible avec --all"
        return 1
    fi
}

disable_single_swap() {
    local target="$1"
    
    atomic_info "Désactivation du swap: $target"
    
    if ! swapoff "$target" 2>/dev/null; then
        atomic_error "Erreur lors de la désactivation: $target"
        return 1
    fi
    
    # Vérification
    if ! grep -q "^$(realpath "$target")" /proc/swaps 2>/dev/null; then
        atomic_success "Swap désactivé: $target"
        
        # Suppression du fichier si demandé
        if $DELETE_FILE && [[ -f "$target" ]]; then
            atomic_info "Suppression du fichier: $target"
            rm -f "$target" || atomic_warn "Impossible de supprimer: $target"
        fi
        
        return 0
    else
        atomic_error "Échec de vérification après désactivation: $target"
        return 1
    fi
}

disable_all_swap() {
    atomic_info "Désactivation de tous les swaps"
    
    if ! swapoff -a 2>/dev/null; then
        atomic_error "Erreur lors de la désactivation globale"
        return 1
    fi
    
    # Vérification
    if [[ -s /proc/swaps ]] && [[ $(wc -l < /proc/swaps 2>/dev/null || echo 0) -gt 1 ]]; then
        atomic_error "Certains swaps sont encore actifs"
        return 1
    else
        atomic_success "Tous les swaps ont été désactivés"
        return 0
    fi
}

disable_swap() {
    if $DRY_RUN; then
        if $ALL_SWAP; then
            atomic_info "DRY-RUN: Désactivation de tous les swaps"
        else
            atomic_info "DRY-RUN: Désactivation swap $SWAP_TARGET"
            $DELETE_FILE && atomic_info "DRY-RUN: Suppression fichier $SWAP_TARGET"
        fi
        return 0
    fi
    
    if [[ $EUID -ne 0 ]]; then
        atomic_error "Permissions root requises"
        return 2
    fi
    
    if $ALL_SWAP; then
        disable_all_swap
    else
        disable_single_swap "$SWAP_TARGET"
    fi
    
    local result=$?
    
    # Affichage du statut final
    if $VERBOSE && [[ $result -eq 0 ]]; then
        atomic_info "Statut swap final:"
        swapon --show 2>/dev/null || atomic_info "Aucun swap actif"
    fi
    
    return $result
}

main() {
    atomic_init_logging "${BASH_SOURCE[0]##*/}" "$QUIET"
    parse_args "$@" || { show_help >&2; return 1; }
    validate_target || return $?
    disable_swap
    return $?
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"