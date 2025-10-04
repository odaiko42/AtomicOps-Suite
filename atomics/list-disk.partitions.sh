#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: list-disk.partitions.sh
# Description: Liste toutes les partitions disque avec détails
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-03
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="list-disk.partitions.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
SHOW_UNMOUNTED=${SHOW_UNMOUNTED:-0}
SHOW_SIZE_HUMAN=${SHOW_SIZE_HUMAN:-1}
FILTER_TYPE=""
MIN_SIZE_MB=""

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
    Liste toutes les partitions disque disponibles avec informations détaillées
    incluant taille, système de fichiers, point de montage et utilisation.

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)
    -u, --show-unmounted   Inclure les partitions non montées
    -r, --raw-size         Afficher tailles en octets (pas human-readable)
    -t, --type TYPE        Filtrer par type de système de fichiers
    -m, --min-size SIZE    Taille minimale en MB pour filtrage
    
Sortie JSON:
    {
      "status": "success|error",
      "code": 0,
      "timestamp": "ISO8601",
      "script": "$SCRIPT_NAME",
      "message": "Description",
      "data": {
        "partitions": [
          {
            "device": "/dev/sda1",
            "filesystem": "ext4",
            "size_bytes": 1073741824,
            "size_human": "1.0G",
            "used_bytes": 536870912,
            "used_human": "512M",
            "available_bytes": 536870912,
            "available_human": "512M",
            "usage_percent": 50,
            "mountpoint": "/",
            "is_mounted": true,
            "mount_options": "rw,relatime",
            "uuid": "12345678-1234-1234-1234-123456789abc",
            "label": "root"
          }
        ],
        "total_partitions": 5,
        "mounted_count": 3,
        "unmounted_count": 2,
        "total_size_bytes": 107374182400,
        "total_used_bytes": 53687091200
      },
      "errors": [],
      "warnings": []
    }

Codes de sortie:
    0 - Succès
    1 - Erreur générale
    2 - Erreur de paramètres
    3 - Commandes requises manquantes
    4 - Aucune partition trouvée

Exemples:
    $SCRIPT_NAME                                   # Lister toutes partitions montées
    $SCRIPT_NAME --show-unmounted                  # Inclure partitions non montées
    $SCRIPT_NAME --type ext4                       # Filtrer par système fichiers
    $SCRIPT_NAME --min-size 1000 --json-only      # Partitions >1GB en JSON
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
            -u|--show-unmounted)
                SHOW_UNMOUNTED=1
                shift
                ;;
            -r|--raw-size)
                SHOW_SIZE_HUMAN=0
                shift
                ;;
            -t|--type)
                if [[ -n "${2:-}" ]]; then
                    FILTER_TYPE="$2"
                    shift 2
                else
                    die "Option --type nécessite un argument" 2
                fi
                ;;
            -m|--min-size)
                if [[ -n "${2:-}" && "$2" =~ ^[0-9]+$ ]]; then
                    MIN_SIZE_MB="$2"
                    shift 2
                else
                    die "Option --min-size nécessite un nombre entier en MB" 2
                fi
                ;;
            -*)
                die "Option inconnue: $1. Utilisez -h pour l'aide." 2
                ;;
            *)
                die "Paramètres supplémentaires non attendus: $1" 2
                ;;
        esac
    done
}

# =============================================================================
# Fonctions Métier
# =============================================================================

check_dependencies() {
    local missing=()
    
    if ! command -v lsblk >/dev/null 2>&1; then
        missing+=("lsblk")
    fi
    
    if ! command -v df >/dev/null 2>&1; then
        missing+=("df")
    fi
    
    # Optionnelles mais recommandées
    if ! command -v blkid >/dev/null 2>&1; then
        log_warn "blkid non disponible - UUID/label non disponibles"
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Commandes manquantes: ${missing[*]}" 3
    fi
    
    log_debug "Dépendances vérifiées avec succès"
}

human_readable_size() {
    local bytes="$1"
    
    if [[ $SHOW_SIZE_HUMAN -eq 0 ]]; then
        echo "$bytes"
        return
    fi
    
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
        # Calculer avec décimale pour plus de précision
        local decimal_size
        decimal_size=$(echo "scale=1; $bytes / (1024^$unit_index)" | bc 2>/dev/null || echo "$size")
        echo "${decimal_size}${units[$unit_index]}"
    fi
}

get_partition_uuid() {
    local device="$1"
    
    if command -v blkid >/dev/null 2>&1; then
        blkid -s UUID -o value "$device" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

get_partition_label() {
    local device="$1"
    
    if command -v blkid >/dev/null 2>&1; then
        blkid -s LABEL -o value "$device" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

get_mount_info() {
    local device="$1"
    local mountpoint=""
    local mount_options=""
    local is_mounted=false
    
    # Chercher dans /proc/mounts
    if [[ -f /proc/mounts ]]; then
        while IFS=' ' read -r dev mp fs opts _; do
            if [[ "$dev" == "$device" ]]; then
                mountpoint="$mp"
                mount_options="$opts"
                is_mounted=true
                break
            fi
        done < /proc/mounts
    fi
    
    echo "$is_mounted|$mountpoint|$mount_options"
}

get_usage_info() {
    local mountpoint="$1"
    local size_bytes=0 used_bytes=0 available_bytes=0 usage_percent=0
    
    if [[ -n "$mountpoint" && -d "$mountpoint" ]]; then
        if command -v df >/dev/null 2>&1; then
            local df_output
            df_output=$(df -B1 "$mountpoint" 2>/dev/null | tail -n 1)
            if [[ -n "$df_output" ]]; then
                read -r _ size_bytes used_bytes available_bytes usage_percent _ <<< "$df_output"
                # Nettoyer le pourcentage (enlever le %)
                usage_percent=${usage_percent%\%}
            fi
        fi
    fi
    
    echo "$size_bytes|$used_bytes|$available_bytes|$usage_percent"
}

filter_partition() {
    local device="$1"
    local filesystem="$2"
    local size_bytes="$3"
    
    # Filtrage par type de système de fichiers
    if [[ -n "$FILTER_TYPE" && "$filesystem" != "$FILTER_TYPE" ]]; then
        return 1
    fi
    
    # Filtrage par taille minimale
    if [[ -n "$MIN_SIZE_MB" ]]; then
        local size_mb=$((size_bytes / 1024 / 1024))
        if [[ $size_mb -lt $MIN_SIZE_MB ]]; then
            return 1
        fi
    fi
    
    return 0
}

list_disk_partitions() {
    log_debug "Début de l'analyse des partitions disque"
    
    local partitions_json=""
    local partition_count=0
    local mounted_count=0
    local unmounted_count=0
    local total_size_bytes=0
    local total_used_bytes=0
    
    # Utiliser lsblk pour obtenir la liste des partitions
    local lsblk_output
    if ! lsblk_output=$(lsblk -J -o NAME,FSTYPE,SIZE,TYPE 2>/dev/null); then
        die "Impossible d'obtenir la liste des périphériques de bloc" 4
    fi
    
    log_debug "lsblk exécuté avec succès"
    
    # Parser le JSON de lsblk avec une approche compatible
    local devices
    devices=$(echo "$lsblk_output" | grep '"name"' | sed 's/.*"name": *"\([^"]*\)".*/\1/')
    
    while IFS= read -r device_name; do
        [[ -z "$device_name" ]] && continue
        
        local device="/dev/$device_name"
        
        # Vérifier que c'est bien un périphérique de partition
        if [[ ! -b "$device" ]]; then
            continue
        fi
        
        log_debug "Analyse de la partition: $device"
        
        # Obtenir le type de système de fichiers
        local filesystem
        filesystem=$(lsblk -no FSTYPE "$device" 2>/dev/null | head -n1 | tr -d ' ')
        [[ -z "$filesystem" ]] && filesystem="unknown"
        
        # Obtenir la taille de la partition
        local size_bytes
        size_bytes=$(lsblk -bno SIZE "$device" 2>/dev/null | head -n1 | tr -d ' ')
        [[ -z "$size_bytes" || ! "$size_bytes" =~ ^[0-9]+$ ]] && size_bytes=0
        
        # Obtenir les informations de montage
        local mount_info is_mounted mountpoint mount_options
        mount_info=$(get_mount_info "$device")
        IFS='|' read -r is_mounted mountpoint mount_options <<< "$mount_info"
        
        # Filtrer les partitions non montées si nécessaire
        if [[ "$is_mounted" == "false" && $SHOW_UNMOUNTED -eq 0 ]]; then
            continue
        fi
        
        # Appliquer les filtres
        if ! filter_partition "$device" "$filesystem" "$size_bytes"; then
            continue
        fi
        
        # Obtenir les informations d'usage
        local usage_info used_bytes available_bytes usage_percent
        usage_info=$(get_usage_info "$mountpoint")
        IFS='|' read -r size_from_df used_bytes available_bytes usage_percent <<< "$usage_info"
        
        # Si df donne une taille différente, utiliser celle-ci (plus précise pour les montées)
        if [[ $size_from_df -gt 0 ]]; then
            size_bytes=$size_from_df
        fi
        
        # Obtenir UUID et label
        local uuid label
        uuid=$(get_partition_uuid "$device")
        label=$(get_partition_label "$device")
        
        # Calculer les tailles human-readable
        local size_human used_human available_human
        size_human=$(human_readable_size "$size_bytes")
        used_human=$(human_readable_size "$used_bytes")
        available_human=$(human_readable_size "$available_bytes")
        
        # Échapper les caractères spéciaux pour JSON
        local device_escaped mountpoint_escaped mount_options_escaped
        device_escaped=$(echo "$device" | sed 's/\\/\\\\/g; s/"/\\"/g')
        mountpoint_escaped=$(echo "$mountpoint" | sed 's/\\/\\\\/g; s/"/\\"/g')
        mount_options_escaped=$(echo "$mount_options" | sed 's/\\/\\\\/g; s/"/\\"/g')
        
        # Construire l'entrée JSON pour cette partition
        local partition_json
        partition_json=$(cat << EOF
        {
          "device": "$device_escaped",
          "filesystem": "$filesystem",
          "size_bytes": $size_bytes,
          "size_human": "$size_human",
          "used_bytes": $used_bytes,
          "used_human": "$used_human",
          "available_bytes": $available_bytes,
          "available_human": "$available_human",
          "usage_percent": $usage_percent,
          "mountpoint": "$mountpoint_escaped",
          "is_mounted": $is_mounted,
          "mount_options": "$mount_options_escaped",
          "uuid": "$uuid",
          "label": "$label"
        }
EOF
        )
        
        # Ajouter à la liste des partitions
        if [[ $partition_count -eq 0 ]]; then
            partitions_json="$partition_json"
        else
            partitions_json="$partitions_json,$partition_json"
        fi
        
        # Mettre à jour les compteurs
        ((partition_count++))
        if [[ "$is_mounted" == "true" ]]; then
            ((mounted_count++))
        else
            ((unmounted_count++))
        fi
        
        # Ajouter aux totaux
        ((total_size_bytes += size_bytes))
        ((total_used_bytes += used_bytes))
        
        log_debug "Partition $device analysée: ${size_human}, montée=$is_mounted"
        
    done <<< "$devices"
    
    if [[ $partition_count -eq 0 ]]; then
        log_warn "Aucune partition trouvée correspondant aux critères"
    fi
    
    log_debug "Analyse terminée: $partition_count partitions trouvées"
    
    # Générer la réponse JSON complète
    cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Disk partitions listed successfully",
  "data": {
    "partitions": [
      $partitions_json
    ],
    "total_partitions": $partition_count,
    "mounted_count": $mounted_count,
    "unmounted_count": $unmounted_count,
    "total_size_bytes": $total_size_bytes,
    "total_used_bytes": $total_used_bytes,
    "total_size_human": "$(human_readable_size $total_size_bytes)",
    "total_used_human": "$(human_readable_size $total_used_bytes)",
    "filters_applied": {
      "filesystem_type": "$FILTER_TYPE",
      "min_size_mb": "$MIN_SIZE_MB",
      "show_unmounted": $([ $SHOW_UNMOUNTED -eq 1 ] && echo "true" || echo "false")
    },
    "scan_time": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  },
  "errors": [],
  "warnings": []
}
EOF
}

# =============================================================================
# Fonction Principale
# =============================================================================

main() {
    log_debug "Démarrage de $SCRIPT_NAME v$SCRIPT_VERSION"
    
    parse_args "$@"
    check_dependencies
    list_disk_partitions
    
    log_info "Script completed successfully"
}

# =============================================================================
# Point d'Entrée
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi