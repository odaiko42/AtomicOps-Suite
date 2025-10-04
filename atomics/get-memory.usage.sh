#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: get-memory.usage.sh
# Description: Récupère les statistiques d'utilisation de la mémoire
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-01-03
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="get-memory.usage.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
SIZE_FORMAT=${SIZE_FORMAT:-"mb"}

# =============================================================================
# Fonctions Utilitaires et Logging
# =============================================================================

log_debug() {
    [[ $DEBUG -eq 0 ]] && return 0
    echo "[DEBUG] $*" >&2
}

log_info() {
    [[ $QUIET -eq 1 ]] && return 0
    [[ $JSON_ONLY -eq 1 ]] && return 0
    echo "[INFO] $*" >&2
}

log_warn() {
    [[ $QUIET -eq 1 ]] && return 0
    [[ $JSON_ONLY -eq 1 ]] && return 0
    echo "[WARN] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

die() {
    log_error "$1"
    exit "${2:-1}"
}

# =============================================================================
# Fonctions d'Aide et de Parsing
# =============================================================================

show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Description:
    Récupère les statistiques d'utilisation de la mémoire système
    incluant RAM, swap, buffers, cache avec différents formats de sortie.

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)
    -s, --size-format FMT  Format de taille: bytes|kb|mb|gb|human (défaut: mb)
    
Formats de taille supportés:
    bytes      Taille en octets
    kb         Taille en kilooctets  
    mb         Taille en mégaoctets
    gb         Taille en gigaoctets
    human      Taille lisible (ex: 1.2G, 512M)

Sortie JSON:
    {
      "status": "success|error",
      "code": 0,
      "timestamp": "ISO8601",
      "script": "$SCRIPT_NAME",
      "message": "Description",
      "data": {
        "memory": {
          "total": "2048MB",
          "used": "1024MB",
          "free": "512MB",
          "available": "1536MB",
          "buffers": "128MB",
          "cached": "256MB",
          "usage_percent": 50
        },
        "swap": {
          "total": "1024MB", 
          "used": "256MB",
          "free": "768MB",
          "usage_percent": 25
        },
        "format": "mb"
      },
      "errors": [],
      "warnings": []
    }

Codes de sortie:
    0 - Succès
    1 - Erreur générale
    2 - Erreur de paramètres
    3 - Commande non disponible
    4 - Erreur de parsing

Exemples:
    $SCRIPT_NAME                           # Usage basique (MB)
    $SCRIPT_NAME --json-only               # Sortie JSON uniquement
    $SCRIPT_NAME --size-format human       # Tailles lisibles
    $SCRIPT_NAME --size-format gb          # Tailles en GB
    $SCRIPT_NAME --debug                   # Mode debug
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -d|--debug)
                DEBUG=1
                VERBOSE=1
                shift
                ;;
            -q|--quiet)
                QUIET=1
                shift
                ;;
            -j|--json-only)
                JSON_ONLY=1
                QUIET=1
                shift
                ;;
            -s|--size-format)
                if [[ -n "${2:-}" ]]; then
                    SIZE_FORMAT="$2"
                    shift 2
                else
                    die "Option --size-format requiert une valeur" 2
                fi
                ;;
            *)
                die "Option inconnue: $1. Utilisez -h pour l'aide." 2
                ;;
        esac
    done

    # Validation du format de taille
    case "$SIZE_FORMAT" in
        bytes|kb|mb|gb|human) ;;
        *) die "Format de taille invalide: $SIZE_FORMAT" 2 ;;
    esac
}

# =============================================================================
# Fonctions Métier
# =============================================================================

check_dependencies() {
    local missing=()
    
    if ! [[ -r /proc/meminfo ]]; then
        missing+=("/proc/meminfo")
    fi
    
    if ! command -v awk >/dev/null 2>&1; then
        missing+=("awk")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Dépendances manquantes: ${missing[*]}" 3
    fi
    
    log_debug "Toutes les dépendances sont disponibles"
}

convert_size() {
    local size_kb="$1"
    local format="$2"
    
    case "$format" in
        bytes)
            echo $((size_kb * 1024))
            ;;
        kb)
            echo "$size_kb"
            ;;
        mb)
            awk "BEGIN {printf \"%.1f\", $size_kb / 1024}"
            ;;
        gb)
            awk "BEGIN {printf \"%.2f\", $size_kb / 1048576}"
            ;;
        human)
            # Conversion intelligente en format lisible
            local bytes=$((size_kb * 1024))
            if [[ $bytes -lt 1024 ]]; then
                echo "${bytes}B"
            elif [[ $bytes -lt 1048576 ]]; then
                awk "BEGIN {printf \"%.1fK\", $bytes / 1024}"
            elif [[ $bytes -lt 1073741824 ]]; then
                awk "BEGIN {printf \"%.1fM\", $bytes / 1048576}"
            else
                awk "BEGIN {printf \"%.2fG\", $bytes / 1073741824}"
            fi
            ;;
        *)
            echo "$size_kb"
            ;;
    esac
}

format_size_with_unit() {
    local size_kb="$1"
    local format="$2"
    local converted
    converted=$(convert_size "$size_kb" "$format")
    
    case "$format" in
        bytes) echo "${converted}B" ;;
        kb) echo "${converted}K" ;;
        mb) echo "${converted}M" ;;
        gb) echo "${converted}G" ;;
        human) echo "$converted" ;;
        *) echo "$converted" ;;
    esac
}

get_memory_usage() {
    log_debug "Récupération des informations de mémoire"
    
    # Lecture des informations de /proc/meminfo
    local meminfo
    meminfo=$(cat /proc/meminfo)
    
    # Extraction des valeurs en kB
    local mem_total mem_free mem_available mem_buffers mem_cached
    local swap_total swap_free
    
    mem_total=$(echo "$meminfo" | awk '/^MemTotal:/ {print $2}')
    mem_free=$(echo "$meminfo" | awk '/^MemFree:/ {print $2}')
    mem_available=$(echo "$meminfo" | awk '/^MemAvailable:/ {print $2}')
    mem_buffers=$(echo "$meminfo" | awk '/^Buffers:/ {print $2}')
    mem_cached=$(echo "$meminfo" | awk '/^Cached:/ {print $2}')
    swap_total=$(echo "$meminfo" | awk '/^SwapTotal:/ {print $2}')
    swap_free=$(echo "$meminfo" | awk '/^SwapFree:/ {print $2}')
    
    # Valeurs par défaut si non trouvées
    mem_total=${mem_total:-0}
    mem_free=${mem_free:-0}
    mem_available=${mem_available:-$mem_free}
    mem_buffers=${mem_buffers:-0}
    mem_cached=${mem_cached:-0}
    swap_total=${swap_total:-0}
    swap_free=${swap_free:-0}
    
    log_debug "Mémoire totale: ${mem_total}K, libre: ${mem_free}K, disponible: ${mem_available}K"
    log_debug "Swap total: ${swap_total}K, libre: ${swap_free}K"
    
    # Calculs dérivés
    local mem_used swap_used
    mem_used=$((mem_total - mem_free - mem_buffers - mem_cached))
    swap_used=$((swap_total - swap_free))
    
    # Pourcentages d'utilisation
    local mem_usage_percent swap_usage_percent
    if [[ $mem_total -gt 0 ]]; then
        mem_usage_percent=$(awk "BEGIN {printf \"%.1f\", ($mem_used * 100) / $mem_total}")
    else
        mem_usage_percent="0.0"
    fi
    
    if [[ $swap_total -gt 0 ]]; then
        swap_usage_percent=$(awk "BEGIN {printf \"%.1f\", ($swap_used * 100) / $swap_total}")
    else
        swap_usage_percent="0.0"
    fi
    
    # Conversion des tailles selon le format demandé
    local mem_total_fmt mem_used_fmt mem_free_fmt mem_available_fmt
    local mem_buffers_fmt mem_cached_fmt swap_total_fmt swap_used_fmt swap_free_fmt
    
    mem_total_fmt=$(format_size_with_unit "$mem_total" "$SIZE_FORMAT")
    mem_used_fmt=$(format_size_with_unit "$mem_used" "$SIZE_FORMAT")
    mem_free_fmt=$(format_size_with_unit "$mem_free" "$SIZE_FORMAT")
    mem_available_fmt=$(format_size_with_unit "$mem_available" "$SIZE_FORMAT")
    mem_buffers_fmt=$(format_size_with_unit "$mem_buffers" "$SIZE_FORMAT")
    mem_cached_fmt=$(format_size_with_unit "$mem_cached" "$SIZE_FORMAT")
    swap_total_fmt=$(format_size_with_unit "$swap_total" "$SIZE_FORMAT")
    swap_used_fmt=$(format_size_with_unit "$swap_used" "$SIZE_FORMAT")
    swap_free_fmt=$(format_size_with_unit "$swap_free" "$SIZE_FORMAT")
    
    # Réponse JSON
    cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Memory usage information retrieved successfully",
  "data": {
    "memory": {
      "total": "$mem_total_fmt",
      "used": "$mem_used_fmt",
      "free": "$mem_free_fmt",
      "available": "$mem_available_fmt",
      "buffers": "$mem_buffers_fmt",
      "cached": "$mem_cached_fmt",
      "usage_percent": $mem_usage_percent,
      "total_bytes": $((mem_total * 1024)),
      "used_bytes": $((mem_used * 1024)),
      "free_bytes": $((mem_free * 1024)),
      "available_bytes": $((mem_available * 1024)),
      "buffers_bytes": $((mem_buffers * 1024)),
      "cached_bytes": $((mem_cached * 1024))
    },
    "swap": {
      "total": "$swap_total_fmt",
      "used": "$swap_used_fmt",
      "free": "$swap_free_fmt",
      "usage_percent": $swap_usage_percent,
      "total_bytes": $((swap_total * 1024)),
      "used_bytes": $((swap_used * 1024)),
      "free_bytes": $((swap_free * 1024))
    },
    "format": "$SIZE_FORMAT",
    "source": "/proc/meminfo",
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  },
  "errors": [],
  "warnings": []
}
EOF
    
    log_debug "Informations mémoire récupérées avec succès"
}

# =============================================================================
# Fonction Principale
# =============================================================================

main() {
    log_debug "Démarrage de $SCRIPT_NAME v$SCRIPT_VERSION"
    
    parse_args "$@"
    check_dependencies
    get_memory_usage
    
    log_info "Script completed successfully"
}

# =============================================================================
# Point d'Entrée
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi