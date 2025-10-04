#!/usr/bin/env bash

# ===================================================================
# Script: get-cpu.info.sh
# Description: Récupère les informations CPU détaillées
# Author: AtomicOps-Suite
# Version: 1.0
# Niveau: atomic
# Catégorie: performance
# ===================================================================

set -euo pipefail

# === CONFIGURATION ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "$0")"
LIB_DIR="$(realpath "$SCRIPT_DIR/../../../lib")"

# Source des librairies communes
if [[ -f "$LIB_DIR/lib-atomics-common.sh" ]]; then
    source "$LIB_DIR/lib-atomics-common.sh"
fi

# === VARIABLES GLOBALES ===
OUTPUT_FORMAT="json"
VERBOSE=false
QUIET=false

# === FONCTIONS ===

#################################################################
# Affiche l'aide du script
# Arguments: Aucun
# Retour: 0
#################################################################
show_help() {
    cat << 'EOF'
get-cpu.info.sh - Récupère les informations CPU détaillées

SYNOPSIS:
    get-cpu.info.sh [OPTIONS]

DESCRIPTION:
    Ce script collecte des informations détaillées sur le processeur :
    - Modèle et architecture
    - Nombre de cœurs et threads
    - Taille des caches
    - Flags et fonctionnalités
    - Fréquences min/max
    
DÉPENDANCES:
    - lscpu (util-linux)
    - /proc/cpuinfo (kernel)
    
OPTIONS:
    -f, --format FORMAT    Format de sortie (json|text|csv) [défaut: json]
    -v, --verbose          Mode verbeux
    -q, --quiet            Mode silencieux
    -h, --help             Affiche cette aide

SORTIE:
    JSON avec les informations CPU complètes

EXEMPLES:
    # Informations CPU en JSON
    ./get-cpu.info.sh
    
    # Format texte
    ./get-cpu.info.sh --format text
    
    # Mode verbeux
    ./get-cpu.info.sh -v

CODES DE RETOUR:
    0    Succès
    1    Erreur générale
    2    Dépendance manquante
    3    Erreur de parsing
EOF
}

#################################################################
# Parse les arguments de la ligne de commande
# Arguments: $@
# Retour: 0 si succès, 1 sinon
#################################################################
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--format)
                if [[ -z "${2:-}" ]]; then
                    atomic_error "Format requis pour l'option --format"
                    return 1
                fi
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                atomic_error "Option inconnue: $1"
                return 1
                ;;
            *)
                atomic_error "Argument non reconnu: $1"
                return 1
                ;;
        esac
    done
    return 0
}

#################################################################
# Vérifie les dépendances nécessaires
# Arguments: Aucun
# Retour: 0 si toutes présentes, 2 sinon
#################################################################
check_dependencies() {
    local missing_deps=()
    
    # Vérification des commandes
    if ! command -v lscpu >/dev/null 2>&1; then
        missing_deps+=("lscpu")
    fi
    
    # Vérification des fichiers système
    if [[ ! -r /proc/cpuinfo ]]; then
        missing_deps+=("/proc/cpuinfo")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        atomic_error "Dépendances manquantes: ${missing_deps[*]}"
        atomic_info "Installation suggérée: apt install util-linux"
        return 2
    fi
    
    return 0
}

#################################################################
# Collecte les informations CPU via lscpu
# Arguments: Aucun
# Retour: 0 si succès, 3 sinon
#################################################################
get_lscpu_info() {
    local lscpu_output
    
    if ! lscpu_output=$(lscpu 2>/dev/null); then
        atomic_error "Impossible d'exécuter lscpu"
        return 3
    fi
    
    # Extraction des informations clés
    CPU_MODEL=$(echo "$lscpu_output" | grep "Model name:" | cut -d: -f2- | xargs)
    CPU_ARCH=$(echo "$lscpu_output" | grep "Architecture:" | cut -d: -f2- | xargs)
    CPU_CORES=$(echo "$lscpu_output" | grep "Core(s) per socket:" | cut -d: -f2- | xargs)
    CPU_THREADS=$(echo "$lscpu_output" | grep "Thread(s) per core:" | cut -d: -f2- | xargs)
    CPU_SOCKETS=$(echo "$lscpu_output" | grep "Socket(s):" | cut -d: -f2- | xargs)
    CPU_FREQ_MIN=$(echo "$lscpu_output" | grep "CPU min MHz:" | cut -d: -f2- | xargs)
    CPU_FREQ_MAX=$(echo "$lscpu_output" | grep "CPU max MHz:" | cut -d: -f2- | xargs)
    CPU_L1D_CACHE=$(echo "$lscpu_output" | grep "L1d cache:" | cut -d: -f2- | xargs)
    CPU_L1I_CACHE=$(echo "$lscpu_output" | grep "L1i cache:" | cut -d: -f2- | xargs)
    CPU_L2_CACHE=$(echo "$lscpu_output" | grep "L2 cache:" | cut -d: -f2- | xargs)
    CPU_L3_CACHE=$(echo "$lscpu_output" | grep "L3 cache:" | cut -d: -f2- | xargs)
    CPU_FLAGS=$(echo "$lscpu_output" | grep "Flags:" | cut -d: -f2- | xargs)
    
    # Calculs dérivés
    CPU_TOTAL_CORES=$((CPU_CORES * CPU_SOCKETS))
    CPU_TOTAL_THREADS=$((CPU_TOTAL_CORES * CPU_THREADS))
    
    return 0
}

#################################################################
# Collecte les informations additionnelles via /proc/cpuinfo
# Arguments: Aucun
# Retour: 0 si succès, 3 sinon
#################################################################
get_proc_info() {
    local proc_info
    
    if ! proc_info=$(cat /proc/cpuinfo 2>/dev/null); then
        atomic_error "Impossible de lire /proc/cpuinfo"
        return 3
    fi
    
    # Informations additionnelles
    CPU_VENDOR_ID=$(echo "$proc_info" | grep "vendor_id" | head -1 | cut -d: -f2- | xargs)
    CPU_FAMILY=$(echo "$proc_info" | grep "cpu family" | head -1 | cut -d: -f2- | xargs)
    CPU_MODEL_ID=$(echo "$proc_info" | grep "model\s" | head -1 | cut -d: -f2- | xargs)
    CPU_STEPPING=$(echo "$proc_info" | grep "stepping" | head -1 | cut -d: -f2- | xargs)
    CPU_MICROCODE=$(echo "$proc_info" | grep "microcode" | head -1 | cut -d: -f2- | xargs)
    CPU_CACHE_SIZE=$(echo "$proc_info" | grep "cache size" | head -1 | cut -d: -f2- | xargs)
    
    return 0
}

#################################################################
# Formate et affiche les résultats
# Arguments: Aucun
# Retour: 0
#################################################################
output_results() {
    case "$OUTPUT_FORMAT" in
        json)
            cat << EOF
{
  "timestamp": "$(date -Iseconds)",
  "cpu": {
    "model": "${CPU_MODEL:-N/A}",
    "vendor": "${CPU_VENDOR_ID:-N/A}",
    "architecture": "${CPU_ARCH:-N/A}",
    "family": "${CPU_FAMILY:-N/A}",
    "model_id": "${CPU_MODEL_ID:-N/A}",
    "stepping": "${CPU_STEPPING:-N/A}",
    "microcode": "${CPU_MICROCODE:-N/A}",
    "cores": {
      "sockets": ${CPU_SOCKETS:-0},
      "cores_per_socket": ${CPU_CORES:-0},
      "threads_per_core": ${CPU_THREADS:-1},
      "total_cores": ${CPU_TOTAL_CORES:-0},
      "total_threads": ${CPU_TOTAL_THREADS:-0}
    },
    "frequency": {
      "min_mhz": "${CPU_FREQ_MIN:-N/A}",
      "max_mhz": "${CPU_FREQ_MAX:-N/A}"
    },
    "cache": {
      "l1d": "${CPU_L1D_CACHE:-N/A}",
      "l1i": "${CPU_L1I_CACHE:-N/A}",
      "l2": "${CPU_L2_CACHE:-N/A}",
      "l3": "${CPU_L3_CACHE:-N/A}",
      "total_cache": "${CPU_CACHE_SIZE:-N/A}"
    },
    "features": {
      "flags": "${CPU_FLAGS:-N/A}"
    }
  }
}
EOF
            ;;
        text)
            echo "=== Informations CPU ==="
            echo "Modèle: ${CPU_MODEL:-N/A}"
            echo "Fabricant: ${CPU_VENDOR_ID:-N/A}"
            echo "Architecture: ${CPU_ARCH:-N/A}"
            echo "Sockets: ${CPU_SOCKETS:-0}"
            echo "Cœurs par socket: ${CPU_CORES:-0}"
            echo "Threads par cœur: ${CPU_THREADS:-1}"
            echo "Total cœurs: ${CPU_TOTAL_CORES:-0}"
            echo "Total threads: ${CPU_TOTAL_THREADS:-0}"
            echo "Fréquence min: ${CPU_FREQ_MIN:-N/A} MHz"
            echo "Fréquence max: ${CPU_FREQ_MAX:-N/A} MHz"
            echo "Cache L1d: ${CPU_L1D_CACHE:-N/A}"
            echo "Cache L1i: ${CPU_L1I_CACHE:-N/A}"
            echo "Cache L2: ${CPU_L2_CACHE:-N/A}"
            echo "Cache L3: ${CPU_L3_CACHE:-N/A}"
            ;;
        csv)
            echo "timestamp,model,vendor,architecture,sockets,cores_per_socket,threads_per_core,total_cores,total_threads,freq_min_mhz,freq_max_mhz,l1d_cache,l1i_cache,l2_cache,l3_cache"
            echo "$(date -Iseconds),${CPU_MODEL:-N/A},${CPU_VENDOR_ID:-N/A},${CPU_ARCH:-N/A},${CPU_SOCKETS:-0},${CPU_CORES:-0},${CPU_THREADS:-1},${CPU_TOTAL_CORES:-0},${CPU_TOTAL_THREADS:-0},${CPU_FREQ_MIN:-N/A},${CPU_FREQ_MAX:-N/A},${CPU_L1D_CACHE:-N/A},${CPU_L1I_CACHE:-N/A},${CPU_L2_CACHE:-N/A},${CPU_L3_CACHE:-N/A}"
            ;;
        *)
            atomic_error "Format non supporté: $OUTPUT_FORMAT"
            return 1
            ;;
    esac
    return 0
}

#################################################################
# Fonction principale
# Arguments: $@
# Retour: Code d'erreur approprié
#################################################################
main() {
    # Initialisation du logging
    atomic_init_logging "$SCRIPT_NAME" "$QUIET"
    
    # Parse des arguments
    if ! parse_args "$@"; then
        atomic_error "Erreur dans les arguments"
        show_help >&2
        return 1
    fi
    
    # Mode verbeux
    if $VERBOSE; then
        atomic_info "Démarrage de $SCRIPT_NAME"
        atomic_info "Format de sortie: $OUTPUT_FORMAT"
    fi
    
    # Vérification des dépendances
    if ! check_dependencies; then
        return 2
    fi
    
    # Collecte des informations
    if ! get_lscpu_info; then
        return 3
    fi
    
    if ! get_proc_info; then
        atomic_warn "Informations /proc/cpuinfo partielles"
    fi
    
    # Affichage des résultats
    if ! output_results; then
        return 1
    fi
    
    if $VERBOSE; then
        atomic_success "Collecte des informations CPU terminée"
    fi
    
    return 0
}

# === EXÉCUTION ===
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi