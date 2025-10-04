#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: format-disk.ext4.sh
# Description: Formate un disque/partition en système de fichiers ext4
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-03
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="format-disk.ext4.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
FORCE=${FORCE:-0}
DRY_RUN=${DRY_RUN:-0}
DEVICE=""
LABEL=""
BLOCK_SIZE=4096
INODE_RATIO=16384
RESERVED_BLOCKS=5
FEATURES=""

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
Usage: $SCRIPT_NAME [OPTIONS] <device>

Description:
    Formate un disque ou une partition avec le système de fichiers ext4
    en incluant validation de sécurité et options avancées de formatage.

Arguments:
    <device>                Périphérique à formater (/dev/sdb, /dev/sdb1, etc.)

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)
    -f, --force            Forcer le formatage sans confirmation
    -n, --dry-run          Test sans formatage réel
    -l, --label LABEL      Étiquette du système de fichiers
    -b, --block-size SIZE  Taille de bloc en octets (1024, 2048, 4096)
    -i, --inode-ratio N    Ratio octets par inode (défaut: 16384)
    -r, --reserved N       Pourcentage blocs réservés (0-50, défaut: 5)
    --features FEATURES    Fonctionnalités ext4 spécifiques
    
Sortie JSON:
    {
      "status": "success|error",
      "code": 0,
      "timestamp": "ISO8601",
      "script": "$SCRIPT_NAME",
      "message": "Description",
      "data": {
        "device": "/dev/sdb1",
        "filesystem": "ext4",
        "label": "data",
        "size_bytes": 1073741824,
        "size_human": "1.0G",
        "block_size": 4096,
        "block_count": 262144,
        "inode_count": 65536,
        "reserved_blocks_percent": 5,
        "uuid": "12345678-1234-1234-1234-123456789abc",
        "format_time_seconds": 15,
        "dry_run": false,
        "previous_filesystem": "ntfs",
        "warnings": ["Previous data will be lost"]
      },
      "errors": [],
      "warnings": []
    }

Codes de sortie:
    0 - Succès
    1 - Erreur générale
    2 - Erreur de paramètres
    3 - Périphérique non trouvé
    4 - Permissions insuffisantes
    5 - Périphérique occupé/monté
    6 - Formatage annulé par l'utilisateur

Exemples:
    $SCRIPT_NAME /dev/sdb1                         # Format simple
    $SCRIPT_NAME --label "data" /dev/sdb1          # Avec étiquette
    $SCRIPT_NAME --force --block-size 2048 /dev/sdb # Formatage forcé
    $SCRIPT_NAME --dry-run /dev/sdb1               # Test sans formatage

ATTENTION: Cette opération détruit toutes les données sur le périphérique !
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
            -f|--force)
                FORCE=1
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=1
                shift
                ;;
            -l|--label)
                if [[ -n "${2:-}" ]]; then
                    LABEL="$2"
                    shift 2
                else
                    die "Option --label nécessite un argument" 2
                fi
                ;;
            -b|--block-size)
                if [[ -n "${2:-}" && "$2" =~ ^(1024|2048|4096)$ ]]; then
                    BLOCK_SIZE="$2"
                    shift 2
                else
                    die "Option --block-size doit être 1024, 2048 ou 4096" 2
                fi
                ;;
            -i|--inode-ratio)
                if [[ -n "${2:-}" && "$2" =~ ^[0-9]+$ && "$2" -ge 1024 ]]; then
                    INODE_RATIO="$2"
                    shift 2
                else
                    die "Option --inode-ratio doit être un nombre ≥ 1024" 2
                fi
                ;;
            -r|--reserved)
                if [[ -n "${2:-}" && "$2" =~ ^[0-9]+$ && "$2" -le 50 ]]; then
                    RESERVED_BLOCKS="$2"
                    shift 2
                else
                    die "Option --reserved doit être un pourcentage entre 0 et 50" 2
                fi
                ;;
            --features)
                if [[ -n "${2:-}" ]]; then
                    FEATURES="$2"
                    shift 2
                else
                    die "Option --features nécessite un argument" 2
                fi
                ;;
            -*)
                die "Option inconnue: $1. Utilisez -h pour l'aide." 2
                ;;
            *)
                if [[ -z "$DEVICE" ]]; then
                    DEVICE="$1"
                else
                    die "Trop d'arguments. Périphérique déjà spécifié: $DEVICE" 2
                fi
                shift
                ;;
        esac
    done

    # Validation des paramètres obligatoires
    if [[ -z "$DEVICE" ]]; then
        die "Périphérique obligatoire manquant. Utilisez -h pour l'aide." 2
    fi
}

# =============================================================================
# Fonctions Métier
# =============================================================================

check_dependencies() {
    local missing=()
    
    if ! command -v mkfs.ext4 >/dev/null 2>&1; then
        missing+=("mkfs.ext4")
    fi
    
    if ! command -v blkid >/dev/null 2>&1; then
        missing+=("blkid")
    fi
    
    if ! command -v lsblk >/dev/null 2>&1; then
        missing+=("lsblk")
    fi
    
    # Vérification des permissions
    if [[ $EUID -ne 0 ]]; then
        die "Ce script nécessite les privilèges root pour formater des périphériques" 4
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Commandes manquantes: ${missing[*]}" 3
    fi
    
    log_debug "Dépendances vérifiées avec succès"
}

validate_device() {
    local device="$1"
    
    log_debug "Validation du périphérique: $device"
    
    # Vérifier que le périphérique existe
    if [[ ! -e "$device" ]]; then
        die "Le périphérique n'existe pas: $device" 3
    fi
    
    # Vérifier que c'est un périphérique de bloc
    if [[ ! -b "$device" ]]; then
        die "N'est pas un périphérique de bloc valide: $device" 3
    fi
    
    # Vérifier que le périphérique n'est pas monté
    if mount | grep -q "^$device "; then
        die "Le périphérique est actuellement monté: $device. Démontez-le d'abord." 5
    fi
    
    # Vérifier les partitions montées si c'est un disque entier
    if lsblk -ln "$device" | grep -q "part.*\/"; then
        die "Des partitions de ce disque sont montées. Démontez toutes les partitions d'abord." 5
    fi
    
    log_debug "Périphérique validé avec succès"
}

get_device_info() {
    local device="$1"
    local size_bytes=0 previous_fs=""
    
    # Obtenir la taille
    if command -v lsblk >/dev/null 2>&1; then
        size_bytes=$(lsblk -bno SIZE "$device" 2>/dev/null | head -n1 | tr -d ' ')
        [[ -z "$size_bytes" || ! "$size_bytes" =~ ^[0-9]+$ ]] && size_bytes=0
    fi
    
    # Obtenir le système de fichiers actuel
    if command -v blkid >/dev/null 2>&1; then
        previous_fs=$(blkid -s TYPE -o value "$device" 2>/dev/null || echo "")
        [[ -z "$previous_fs" ]] && previous_fs="none"
    fi
    
    echo "$size_bytes|$previous_fs"
}

human_readable_size() {
    local bytes="$1"
    
    if [[ $bytes -eq 0 ]]; then
        echo "0B"
        return
    fi
    
    local units=("B" "K" "M" "G" "T" "P")
    local unit_index=0
    local size=$bytes
    
    while [[ $size -gt 1024 && $unit_index -lt 5 ]]; do
        size=$((size / 1024))
        ((unit_index++))
    done
    
    if [[ $unit_index -eq 0 ]]; then
        echo "${size}${units[$unit_index]}"
    else
        local decimal_size
        decimal_size=$(echo "scale=1; $bytes / (1024^$unit_index)" | bc 2>/dev/null || echo "$size")
        echo "${decimal_size}${units[$unit_index]}"
    fi
}

confirm_format() {
    local device="$1"
    local size_human="$2"
    local previous_fs="$3"
    
    if [[ $FORCE -eq 1 || $JSON_ONLY -eq 1 ]]; then
        return 0
    fi
    
    echo "==================== ATTENTION ===================="
    echo "Vous êtes sur le point de formater:"
    echo "  Périphérique: $device"
    echo "  Taille: $size_human"
    echo "  Système de fichiers actuel: $previous_fs"
    echo "  Nouveau système: ext4"
    echo ""
    echo "TOUTES LES DONNÉES SERONT DÉFINITIVEMENT PERDUES!"
    echo "===================================================="
    echo ""
    read -p "Êtes-vous sûr de vouloir continuer? (tapez 'OUI' pour confirmer): " confirmation
    
    if [[ "$confirmation" != "OUI" ]]; then
        die "Formatage annulé par l'utilisateur" 6
    fi
}

format_ext4() {
    local device="$1"
    
    log_debug "Début du formatage ext4 pour: $device"
    
    # Validation du périphérique
    validate_device "$device"
    
    # Obtenir les informations du périphérique
    local device_info size_bytes previous_fs
    device_info=$(get_device_info "$device")
    IFS='|' read -r size_bytes previous_fs <<< "$device_info"
    
    local size_human
    size_human=$(human_readable_size "$size_bytes")
    
    log_debug "Taille du périphérique: $size_bytes octets ($size_human)"
    log_debug "Système de fichiers actuel: $previous_fs"
    
    # Demander confirmation (sauf si force ou dry-run)
    if [[ $DRY_RUN -eq 0 ]]; then
        confirm_format "$device" "$size_human" "$previous_fs"
    fi
    
    # Calculer les paramètres du système de fichiers
    local block_count inode_count
    block_count=$((size_bytes / BLOCK_SIZE))
    inode_count=$((size_bytes / INODE_RATIO))
    
    # Construire la commande mkfs.ext4
    local mkfs_cmd="mkfs.ext4"
    local mkfs_args=()
    
    # Options de base
    mkfs_args+=("-b" "$BLOCK_SIZE")
    mkfs_args+=("-m" "$RESERVED_BLOCKS")
    mkfs_args+=("-i" "$INODE_RATIO")
    
    # Label si spécifié
    if [[ -n "$LABEL" ]]; then
        mkfs_args+=("-L" "$LABEL")
    fi
    
    # Fonctionnalités spécifiques si spécifiées
    if [[ -n "$FEATURES" ]]; then
        mkfs_args+=("-O" "$FEATURES")
    fi
    
    # Mode quiet si demandé
    if [[ $QUIET -eq 1 || $JSON_ONLY -eq 1 ]]; then
        mkfs_args+=("-q")
    fi
    
    # Le périphérique
    mkfs_args+=("$device")
    
    log_debug "Commande de formatage: $mkfs_cmd ${mkfs_args[*]}"
    
    # Exécuter le formatage (ou simulation)
    local format_start format_end format_time uuid
    format_start=$(date +%s)
    
    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY-RUN] Simulation du formatage: $mkfs_cmd ${mkfs_args[*]}"
        uuid="00000000-0000-0000-0000-000000000000"
        format_time=0
    else
        log_info "Formatage en cours de $device..."
        
        if ! "$mkfs_cmd" "${mkfs_args[@]}" 2>/dev/null; then
            die "Échec du formatage de $device" 1
        fi
        
        format_end=$(date +%s)
        format_time=$((format_end - format_start))
        
        # Obtenir l'UUID généré
        sleep 1  # Petite pause pour que le système de fichiers soit reconnu
        uuid=$(blkid -s UUID -o value "$device" 2>/dev/null || echo "unknown")
        
        log_info "Formatage terminé avec succès en ${format_time}s"
    fi
    
    # Construire les avertissements
    local warnings_json=""
    if [[ "$previous_fs" != "none" && "$previous_fs" != "" ]]; then
        warnings_json="\"Previous filesystem ($previous_fs) data has been destroyed\""
    fi
    
    # Échapper les caractères spéciaux pour JSON
    local device_escaped label_escaped
    device_escaped=$(echo "$device" | sed 's/\\/\\\\/g; s/"/\\"/g')
    label_escaped=$(echo "$LABEL" | sed 's/\\/\\\\/g; s/"/\\"/g')
    
    # Générer la réponse JSON
    cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Device ${DRY_RUN:+would be }formatted successfully as ext4",
  "data": {
    "device": "$device_escaped",
    "filesystem": "ext4",
    "label": "$label_escaped",
    "size_bytes": $size_bytes,
    "size_human": "$size_human",
    "block_size": $BLOCK_SIZE,
    "block_count": $block_count,
    "inode_count": $inode_count,
    "inode_ratio": $INODE_RATIO,
    "reserved_blocks_percent": $RESERVED_BLOCKS,
    "uuid": "$uuid",
    "format_time_seconds": $format_time,
    "dry_run": $([ $DRY_RUN -eq 1 ] && echo "true" || echo "false"),
    "previous_filesystem": "$previous_fs",
    "format_options": {
      "block_size": $BLOCK_SIZE,
      "inode_ratio": $INODE_RATIO,
      "reserved_percent": $RESERVED_BLOCKS,
      "features": "$FEATURES"
    },
    "completion_time": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  },
  "errors": [],
  "warnings": [$warnings_json]
}
EOF
    
    log_debug "Formatage terminé avec succès"
}

# =============================================================================
# Fonction Principale
# =============================================================================

main() {
    log_debug "Démarrage de $SCRIPT_NAME v$SCRIPT_VERSION"
    
    parse_args "$@"
    check_dependencies
    format_ext4 "$DEVICE"
    
    log_info "Script completed successfully"
}

# =============================================================================
# Point d'Entrée
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi