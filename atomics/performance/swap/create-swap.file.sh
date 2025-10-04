#!/usr/bin/env bash
# create-swap.file.sh - Crée un fichier swap

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(realpath "$SCRIPT_DIR/../../../lib")"
[[ -f "$LIB_DIR/lib-atomics-common.sh" ]] && source "$LIB_DIR/lib-atomics-common.sh"

SWAP_SIZE=""
SWAP_FILE="/swapfile"
VERBOSE=false
QUIET=false
DRY_RUN=false

show_help() {
    cat << 'EOF'
create-swap.file.sh - Crée un fichier swap

Usage: create-swap.file.sh -s SIZE [OPTIONS]

OPTIONS:
    -s, --size SIZE        Taille (ex: 1G, 512M, 2048M)
    -f, --file FILE        Chemin du fichier [défaut: /swapfile]
    -n, --dry-run          Simulation
    -v, --verbose          Mode verbeux
    -q, --quiet            Mode silencieux
    -h, --help             Affiche cette aide

ATTENTION: Nécessite les permissions root
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--size) SWAP_SIZE="$2"; shift 2 ;;
            -f|--file) SWAP_FILE="$2"; shift 2 ;;
            -n|--dry-run) DRY_RUN=true; shift ;;
            -v|--verbose) VERBOSE=true; shift ;;
            -q|--quiet) QUIET=true; shift ;;
            -h|--help) show_help; exit 0 ;;
            *) atomic_error "Option inconnue: $1"; return 1 ;;
        esac
    done
    
    [[ -z "$SWAP_SIZE" ]] && { atomic_error "Taille requise (-s|--size)"; return 1; }
}

validate_size() {
    if [[ ! "$SWAP_SIZE" =~ ^[0-9]+[KMGT]?$ ]]; then
        atomic_error "Format de taille invalide: $SWAP_SIZE (ex: 1G, 512M)"
        return 1
    fi
}

create_swap() {
    if [[ -f "$SWAP_FILE" ]]; then
        atomic_error "Le fichier $SWAP_FILE existe déjà"
        return 1
    fi
    
    if $DRY_RUN; then
        atomic_info "DRY-RUN: Création swap $SWAP_SIZE dans $SWAP_FILE"
        return 0
    fi
    
    if [[ $EUID -ne 0 ]]; then
        atomic_error "Permissions root requises"
        return 2
    fi
    
    # Création du fichier
    atomic_info "Création du fichier swap ($SWAP_SIZE)..."
    if ! dd if=/dev/zero of="$SWAP_FILE" bs=1M count="${SWAP_SIZE%[KMGT]}" status=progress 2>/dev/null; then
        atomic_error "Erreur lors de la création du fichier"
        return 1
    fi
    
    # Permissions
    chmod 600 "$SWAP_FILE" || return 1
    
    # Format swap
    atomic_info "Configuration du format swap..."
    if ! mkswap "$SWAP_FILE" >/dev/null 2>&1; then
        atomic_error "Erreur mkswap"
        rm -f "$SWAP_FILE"
        return 1
    fi
    
    # Activation
    atomic_info "Activation du swap..."
    if ! swapon "$SWAP_FILE"; then
        atomic_error "Erreur d'activation"
        rm -f "$SWAP_FILE"
        return 1
    fi
    
    atomic_success "Fichier swap créé et activé: $SWAP_FILE ($SWAP_SIZE)"
    
    # Ajout au fstab si désiré
    if ! grep -q "$SWAP_FILE" /etc/fstab 2>/dev/null; then
        atomic_info "Ajout recommandé à /etc/fstab:"
        atomic_info "$SWAP_FILE none swap sw 0 0"
    fi
    
    return 0
}

main() {
    atomic_init_logging "${BASH_SOURCE[0]##*/}" "$QUIET"
    parse_args "$@" || { show_help >&2; return 1; }
    validate_size || return 1
    create_swap
    return $?
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"