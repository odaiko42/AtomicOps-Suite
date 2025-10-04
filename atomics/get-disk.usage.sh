#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: get-disk.usage.sh
# Description: Récupère les informations d'utilisation des disques/partitions
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-01-03
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="get-disk.usage.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
INCLUDE_TMPFS=${INCLUDE_TMPFS:-0}
SIZE_FORMAT=${SIZE_FORMAT:-"human"}

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
    Récupère les informations d'utilisation des disques et partitions
    du système avec support pour différents formats de sortie.

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)
    -t, --include-tmpfs    Inclure les systèmes de fichiers tmpfs/devtmpfs
    -s, --size-format FMT  Format de taille: human|bytes|kb|mb|gb (défaut: human)
    
Formats de taille supportés:
    human      Taille lisible (ex: 1.2G, 512M)
    bytes      Taille en octets
    kb         Taille en kilooctets
    mb         Taille en mégaoctets
    gb         Taille en gigaoctets

Sortie JSON:
    {
      "status": "success|error",
      "code": 0,
      "timestamp": "ISO8601",
      "script": "$SCRIPT_NAME",
      "message": "Description",
      "data": {
        "filesystems": [
          {
            "filesystem": "/dev/sda1",
            "size": "10G",
            "used": "5.2G",
            "available": "4.3G",
            "use_percent": 55,
            "mount_point": "/",
            "fs_type": "ext4"
          }
        ],
        "count": 1,
        "total_size": "10G",
        "total_used": "5.2G",
        "total_available": "4.3G",
        "format": "human"
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
    $SCRIPT_NAME                           # Usage basique
    $SCRIPT_NAME --json-only               # Sortie JSON uniquement
    $SCRIPT_NAME --include-tmpfs           # Inclure tmpfs
    $SCRIPT_NAME --size-format bytes       # Tailles en octets
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
            -t|--include-tmpfs)
                INCLUDE_TMPFS=1
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
        human|bytes|kb|mb|gb) ;;
        *) die "Format de taille invalide: $SIZE_FORMAT" 2 ;;
    esac
}

# =============================================================================
# Fonctions Métier
# =============================================================================

check_dependencies() {
    local missing=()
    
    if ! command -v df >/dev/null 2>&1; then
        missing+=("df")
    fi
    
    if ! command -v awk >/dev/null 2>&1; then
        missing+=("awk")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Commandes manquantes: ${missing[*]}" 3
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
            # Utiliser numfmt si disponible, sinon conversion manuelle
            if command -v numfmt >/dev/null 2>&1; then
                numfmt --to=iec --suffix=B <<< $((size_kb * 1024)) | sed 's/B$//'
            else
                # Conversion manuelle pour human readable
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
            fi
            ;;
        *)
            echo "$size_kb"
            ;;
    esac
}

get_filesystem_type() {
    local mount_point="$1"
    
    # Essayer avec findmnt d'abord (plus moderne)
    if command -v findmnt >/dev/null 2>&1; then
        local fstype
        fstype=$(findmnt -n -o FSTYPE "$mount_point" 2>/dev/null)
        [[ -n "$fstype" ]] && echo "$fstype" || echo "unknown"
    else
        # Fallback avec mount et grep
        local fstype
        fstype=$(mount | awk -v mp="$mount_point" '$3 == mp {gsub(/[()]/,"",$5); print $5; exit}' 2>/dev/null)
        [[ -n "$fstype" ]] && echo "$fstype" || echo "unknown"
    fi
}

get_disk_usage() {
    log_debug "Récupération des informations d'utilisation disque"
    
    local df_options="-P"  # Format POSIX pour parsing consistent
    
    # Note: Les options -x ne sont pas supportées sur tous les systèmes
    # On filtrera manuellement les systèmes de fichiers non désirés
    
    log_debug "Options df utilisées: $df_options"
    
    # Exécuter df et traiter les résultats
    local filesystems=()
    local total_size_kb=0
    local total_used_kb=0
    local total_avail_kb=0
    
    # Lire ligne par ligne le résultat de df
    while IFS= read -r line; do
        # Ignorer la ligne d'en-tête
        [[ "$line" =~ ^Filesystem ]] && continue
        
        log_debug "Traitement ligne df: $line"
        
        # Parser la ligne (format POSIX garanti par -P)
        local filesystem size_kb used_kb avail_kb use_percent mount_point
        read -r filesystem size_kb used_kb avail_kb use_percent mount_point <<< "$line"
        
        # Vérifier que nous avons des données valides
        [[ -z "$filesystem" || -z "$mount_point" ]] && continue
        [[ ! "$size_kb" =~ ^[0-9]+$ ]] && continue
        
        # Filtrer les systèmes de fichiers non désirés si demandé
        if [[ $INCLUDE_TMPFS -eq 0 ]]; then
            # Filtrage basique par nom de mount point et filesystem
            case "$filesystem" in
                tmpfs|devtmpfs|sysfs|proc|devpts|udev) 
                    log_debug "Filtrage du système de fichiers: $filesystem"
                    continue 
                    ;;
            esac
            case "$mount_point" in
                /dev|/dev/*|/sys|/sys/*|/proc|/proc/*|/run|/run/*)
                    log_debug "Filtrage du point de montage: $mount_point"
                    continue 
                    ;;
            esac
        fi
        
        log_debug "Filesystem: $filesystem, Mount: $mount_point, Size: $size_kb KB"
        
        # Convertir les tailles selon le format demandé
        local size_formatted used_formatted avail_formatted
        size_formatted=$(convert_size "$size_kb" "$SIZE_FORMAT")
        used_formatted=$(convert_size "$used_kb" "$SIZE_FORMAT")
        avail_formatted=$(convert_size "$avail_kb" "$SIZE_FORMAT")
        
        # Extraire le pourcentage numérique
        local use_percent_num="${use_percent%\%}"
        [[ ! "$use_percent_num" =~ ^[0-9]+$ ]] && use_percent_num=0
        
        # Obtenir le type de système de fichiers (avec protection d'erreur)
        local fs_type="unknown"
        if fs_type=$(get_filesystem_type "$mount_point" 2>/dev/null); then
            [[ -n "$fs_type" ]] || fs_type="unknown"
        fi
        
        # Échapper les caractères spéciaux pour JSON
        local filesystem_escaped mount_point_escaped fs_type_escaped
        filesystem_escaped=$(echo "$filesystem" | sed 's/\\/\\\\/g; s/"/\\"/g')
        mount_point_escaped=$(echo "$mount_point" | sed 's/\\/\\\\/g; s/"/\\"/g')
        fs_type_escaped=$(echo "$fs_type" | sed 's/\\/\\\\/g; s/"/\\"/g')
        
        # Construire l'objet filesystem
        local filesystem_json
        filesystem_json=$(cat << EOF
{
  "filesystem": "$filesystem_escaped",
  "size": "$size_formatted",
  "used": "$used_formatted",
  "available": "$avail_formatted",
  "use_percent": $use_percent_num,
  "mount_point": "$mount_point_escaped",
  "fs_type": "$fs_type_escaped",
  "size_bytes": $((size_kb * 1024)),
  "used_bytes": $((used_kb * 1024)),
  "available_bytes": $((avail_kb * 1024))
}
EOF
        )
        
        filesystems+=("$filesystem_json")
        
        # Accumuler les totaux
        ((total_size_kb += size_kb))
        ((total_used_kb += used_kb))
        ((total_avail_kb += avail_kb))
        
    done < <(df $df_options 2>/dev/null || die "Erreur lors de l'exécution de df" 4)
    
    # Convertir les totaux
    local total_size_formatted total_used_formatted total_avail_formatted
    total_size_formatted=$(convert_size "$total_size_kb" "$SIZE_FORMAT")
    total_used_formatted=$(convert_size "$total_used_kb" "$SIZE_FORMAT")
    total_avail_formatted=$(convert_size "$total_avail_kb" "$SIZE_FORMAT")
    
    # Construire la réponse JSON
    local filesystems_json
    if [[ ${#filesystems[@]} -gt 0 ]]; then
        # Joindre les éléments avec des virgules
        filesystems_json=$(IFS=','; echo "${filesystems[*]}")
    else
        filesystems_json=""
    fi
    
    # Réponse JSON finale
    cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Disk usage information retrieved successfully",
  "data": {
    "filesystems": [
      $filesystems_json
    ],
    "count": ${#filesystems[@]},
    "total_size": "$total_size_formatted",
    "total_used": "$total_used_formatted",
    "total_available": "$total_avail_formatted",
    "total_size_bytes": $((total_size_kb * 1024)),
    "total_used_bytes": $((total_used_kb * 1024)),
    "total_available_bytes": $((total_avail_kb * 1024)),
    "format": "$SIZE_FORMAT",
    "include_tmpfs": $([ $INCLUDE_TMPFS -eq 1 ] && echo "true" || echo "false")
  },
  "errors": [],
  "warnings": []
}
EOF
    
    log_debug "Informations disque récupérées avec succès: ${#filesystems[@]} systèmes de fichiers"
}

# =============================================================================
# Fonction Principale
# =============================================================================

main() {
    log_debug "Démarrage de $SCRIPT_NAME v$SCRIPT_VERSION"
    
    parse_args "$@"
    check_dependencies
    get_disk_usage
    
    log_info "Script completed successfully"
}

# =============================================================================
# Point d'Entrée
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi