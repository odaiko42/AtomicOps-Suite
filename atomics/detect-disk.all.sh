#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: detect-disk.all.sh
# Description: Détecte tous les disques disponibles sur le système
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-03
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="detect-disk.all.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
INCLUDE_REMOVABLE=${INCLUDE_REMOVABLE:-1}
INCLUDE_VIRTUAL=${INCLUDE_VIRTUAL:-0}
MIN_SIZE_GB=${MIN_SIZE_GB:-0}
DETAILED_INFO=${DETAILED_INFO:-0}

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
    Détecte et liste tous les disques physiques disponibles sur le système
    avec informations détaillées sur la géométrie, capacité et état.

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)
    --no-removable         Exclure disques amovibles (USB, etc.)
    --include-virtual      Inclure disques virtuels (loop, etc.)
    --min-size SIZE        Taille minimale en GB pour filtrage
    --detailed             Informations détaillées (SMART, température)
    
Sortie JSON:
    {
      "status": "success|error",
      "code": 0,
      "timestamp": "ISO8601",
      "script": "$SCRIPT_NAME",
      "message": "Description",
      "data": {
        "disks": [
          {
            "device": "/dev/sda",
            "model": "Samsung SSD 970 EVO",
            "serial": "S467NX0M123456",
            "size_bytes": 1000204886016,
            "size_human": "931.5G",
            "sector_size": 512,
            "type": "SSD",
            "interface": "nvme",
            "vendor": "Samsung",
            "firmware": "2B2QEXM7",
            "is_removable": false,
            "is_rotational": false,
            "partitions": ["/dev/sda1", "/dev/sda2"],
            "partition_count": 2,
            "health_status": "PASSED",
            "temperature_celsius": 45,
            "power_on_hours": 1234,
            "read_only": false
          }
        ],
        "total_disks": 2,
        "total_capacity_bytes": 2000409772032,
        "disk_types": {"SSD": 1, "HDD": 1},
        "interfaces": {"sata": 1, "nvme": 1}
      },
      "errors": [],
      "warnings": []
    }

Codes de sortie:
    0 - Succès
    1 - Erreur générale
    2 - Erreur de paramètres
    3 - Commandes requises manquantes
    4 - Aucun disque trouvé

Exemples:
    $SCRIPT_NAME                                   # Détecter tous disques
    $SCRIPT_NAME --no-removable                    # Exclure USB/amovibles
    $SCRIPT_NAME --min-size 100 --detailed        # Disques >100GB avec détails
    $SCRIPT_NAME --include-virtual --json-only    # Tout inclure en JSON
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
            --no-removable)
                INCLUDE_REMOVABLE=0
                shift
                ;;
            --include-virtual)
                INCLUDE_VIRTUAL=1
                shift
                ;;
            --detailed)
                DETAILED_INFO=1
                shift
                ;;
            --min-size)
                if [[ -n "${2:-}" && "$2" =~ ^[0-9]+$ ]]; then
                    MIN_SIZE_GB="$2"
                    shift 2
                else
                    die "Option --min-size nécessite un nombre entier en GB" 2
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
    
    # Optionnelles pour informations détaillées
    if [[ $DETAILED_INFO -eq 1 ]]; then
        if ! command -v smartctl >/dev/null 2>&1; then
            log_warn "smartctl non disponible - informations SMART non disponibles"
        fi
        if ! command -v hdparm >/dev/null 2>&1; then
            log_warn "hdparm non disponible - certaines informations matérielles limitées"
        fi
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Commandes manquantes: ${missing[*]}" 3
    fi
    
    log_debug "Dépendances vérifiées avec succès"
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
        # Calculer avec décimale pour plus de précision
        local decimal_size
        decimal_size=$(echo "scale=1; $bytes / (1024^$unit_index)" | bc 2>/dev/null || echo "$size")
        echo "${decimal_size}${units[$unit_index]}"
    fi
}

is_disk_virtual() {
    local device="$1"
    local device_name
    device_name=$(basename "$device")
    
    # Vérifier les types de disques virtuels courants
    case "$device_name" in
        loop*|dm-*|md*|ram*|zram*)
            return 0
            ;;
        *)
            # Vérifier dans /sys si c'est un disque virtuel
            if [[ -f "/sys/block/$device_name/queue/rotational" ]]; then
                local rotational
                rotational=$(cat "/sys/block/$device_name/queue/rotational" 2>/dev/null || echo "1")
                if [[ -d "/sys/block/$device_name/device/virtual" ]]; then
                    return 0
                fi
            fi
            return 1
            ;;
    esac
}

is_disk_removable() {
    local device="$1"
    local device_name
    device_name=$(basename "$device")
    
    # Vérifier le flag removable dans /sys
    if [[ -f "/sys/block/$device_name/removable" ]]; then
        local removable
        removable=$(cat "/sys/block/$device_name/removable" 2>/dev/null || echo "0")
        [[ "$removable" == "1" ]]
    else
        # Fallback: détecter par type d'interface
        case "$device_name" in
            sd[a-z]*|mmcblk*|nvme*)
                # Vérifier si c'est USB via udevadm
                if command -v udevadm >/dev/null 2>&1; then
                    local id_bus
                    id_bus=$(udevadm info --query=property --name="$device" 2>/dev/null | grep "ID_BUS=" | cut -d'=' -f2)
                    [[ "$id_bus" == "usb" ]]
                else
                    return 1
                fi
                ;;
            *)
                return 1
                ;;
        esac
    fi
}

get_disk_info() {
    local device="$1"
    local device_name
    device_name=$(basename "$device")
    
    local model="" serial="" size_bytes=0 vendor="" firmware=""
    local is_rotational=true interface="" sector_size=512
    
    # Obtenir la taille
    if [[ -f "/sys/block/$device_name/size" ]]; then
        local sectors
        sectors=$(cat "/sys/block/$device_name/size" 2>/dev/null || echo "0")
        size_bytes=$((sectors * 512))
    fi
    
    # Obtenir les informations via lsblk
    if command -v lsblk >/dev/null 2>&1; then
        local lsblk_info
        lsblk_info=$(lsblk -dno MODEL,SERIAL,VENDOR "$device" 2>/dev/null | head -n1)
        if [[ -n "$lsblk_info" ]]; then
            read -r model serial vendor <<< "$lsblk_info"
        fi
    fi
    
    # Déterminer si c'est rotatif (HDD vs SSD)
    if [[ -f "/sys/block/$device_name/queue/rotational" ]]; then
        local rotational
        rotational=$(cat "/sys/block/$device_name/queue/rotational" 2>/dev/null || echo "1")
        [[ "$rotational" == "0" ]] && is_rotational=false
    fi
    
    # Déterminer l'interface
    case "$device_name" in
        nvme*)
            interface="nvme"
            ;;
        sd*)
            interface="sata"
            ;;
        hd*)
            interface="pata"
            ;;
        mmcblk*)
            interface="mmc"
            ;;
        vd*)
            interface="virtio"
            ;;
        *)
            interface="unknown"
            ;;
    esac
    
    # Nettoyer les valeurs (enlever espaces)
    model=$(echo "$model" | tr -d '[:space:]' | sed 's/^$/unknown/')
    serial=$(echo "$serial" | tr -d '[:space:]' | sed 's/^$/unknown/')
    vendor=$(echo "$vendor" | tr -d '[:space:]' | sed 's/^$/unknown/')
    
    echo "$model|$serial|$size_bytes|$vendor|$firmware|$is_rotational|$interface|$sector_size"
}

get_disk_partitions() {
    local device="$1"
    local partitions=()
    
    # Lister les partitions via lsblk
    if command -v lsblk >/dev/null 2>&1; then
        while IFS= read -r partition; do
            [[ -n "$partition" ]] && partitions+=("$partition")
        done < <(lsblk -lno NAME "$device" 2>/dev/null | tail -n +2 | sed "s|^|/dev/|")
    fi
    
    # Format JSON pour les partitions
    local partitions_json=""
    for i in "${!partitions[@]}"; do
        local partition_escaped
        partition_escaped=$(echo "${partitions[$i]}" | sed 's/\\/\\\\/g; s/"/\\"/g')
        if [[ $i -eq 0 ]]; then
            partitions_json="\"$partition_escaped\""
        else
            partitions_json="$partitions_json,\"$partition_escaped\""
        fi
    done
    
    echo "${#partitions[@]}|[$partitions_json]"
}

get_smart_info() {
    local device="$1"
    local health_status="UNKNOWN" temperature=0 power_on_hours=0
    
    if [[ $DETAILED_INFO -eq 1 ]] && command -v smartctl >/dev/null 2>&1; then
        local smart_output
        if smart_output=$(smartctl -H "$device" 2>/dev/null); then
            if echo "$smart_output" | grep -q "PASSED"; then
                health_status="PASSED"
            elif echo "$smart_output" | grep -q "FAILED"; then
                health_status="FAILED"
            fi
        fi
        
        # Obtenir température et heures d'utilisation
        if smart_output=$(smartctl -A "$device" 2>/dev/null); then
            temperature=$(echo "$smart_output" | grep -i temperature | awk '{print $10}' | head -n1 | grep -o '[0-9]*' | head -n1)
            power_on_hours=$(echo "$smart_output" | grep -i "power.*on.*hours" | awk '{print $10}' | head -n1)
            
            [[ -z "$temperature" ]] && temperature=0
            [[ -z "$power_on_hours" ]] && power_on_hours=0
        fi
    fi
    
    echo "$health_status|$temperature|$power_on_hours"
}

is_disk_readonly() {
    local device="$1"
    local device_name
    device_name=$(basename "$device")
    
    if [[ -f "/sys/block/$device_name/ro" ]]; then
        local readonly
        readonly=$(cat "/sys/block/$device_name/ro" 2>/dev/null || echo "0")
        [[ "$readonly" == "1" ]]
    else
        return 1
    fi
}

filter_disk() {
    local size_bytes="$1"
    local is_removable="$2"
    local is_virtual="$3"
    
    # Filtrage par taille minimale
    if [[ $MIN_SIZE_GB -gt 0 ]]; then
        local size_gb=$((size_bytes / 1024 / 1024 / 1024))
        if [[ $size_gb -lt $MIN_SIZE_GB ]]; then
            return 1
        fi
    fi
    
    # Filtrage des disques amovibles
    if [[ $INCLUDE_REMOVABLE -eq 0 && "$is_removable" == "true" ]]; then
        return 1
    fi
    
    # Filtrage des disques virtuels
    if [[ $INCLUDE_VIRTUAL -eq 0 && "$is_virtual" == "true" ]]; then
        return 1
    fi
    
    return 0
}

detect_all_disks() {
    log_debug "Début de la détection des disques"
    
    local disks_json=""
    local disk_count=0
    local total_capacity_bytes=0
    declare -A disk_types interfaces
    
    # Obtenir la liste des disques via lsblk
    local disks
    if ! disks=$(lsblk -dno NAME 2>/dev/null | grep -v "^$"); then
        die "Impossible d'obtenir la liste des disques" 4
    fi
    
    while IFS= read -r disk_name; do
        [[ -z "$disk_name" ]] && continue
        
        local device="/dev/$disk_name"
        
        # Vérifier que c'est bien un périphérique de bloc
        if [[ ! -b "$device" ]]; then
            log_debug "Ignoré (pas un périphérique de bloc): $device"
            continue
        fi
        
        log_debug "Analyse du disque: $device"
        
        # Déterminer le type de disque
        local is_virtual is_removable
        is_virtual=$(is_disk_virtual "$device" && echo "true" || echo "false")
        is_removable=$(is_disk_removable "$device" && echo "true" || echo "false")
        
        # Obtenir les informations de base
        local disk_info model serial size_bytes vendor firmware is_rotational interface sector_size
        disk_info=$(get_disk_info "$device")
        IFS='|' read -r model serial size_bytes vendor firmware is_rotational interface sector_size <<< "$disk_info"
        
        # Appliquer les filtres
        if ! filter_disk "$size_bytes" "$is_removable" "$is_virtual"; then
            log_debug "Disque filtré: $device"
            continue
        fi
        
        # Déterminer le type (SSD/HDD)
        local disk_type
        if [[ "$is_rotational" == "true" ]]; then
            disk_type="HDD"
        else
            disk_type="SSD"
        fi
        
        # Obtenir les partitions
        local partition_info partition_count partitions_json
        partition_info=$(get_disk_partitions "$device")
        IFS='|' read -r partition_count partitions_json <<< "$partition_info"
        
        # Obtenir les informations SMART si demandées
        local smart_info health_status temperature power_on_hours
        smart_info=$(get_smart_info "$device")
        IFS='|' read -r health_status temperature power_on_hours <<< "$smart_info"
        
        # Vérifier si le disque est en lecture seule
        local read_only
        read_only=$(is_disk_readonly "$device" && echo "true" || echo "false")
        
        # Calculer la taille human-readable
        local size_human
        size_human=$(human_readable_size "$size_bytes")
        
        # Échapper les caractères spéciaux pour JSON
        local device_escaped model_escaped serial_escaped vendor_escaped
        device_escaped=$(echo "$device" | sed 's/\\/\\\\/g; s/"/\\"/g')
        model_escaped=$(echo "$model" | sed 's/\\/\\\\/g; s/"/\\"/g')
        serial_escaped=$(echo "$serial" | sed 's/\\/\\\\/g; s/"/\\"/g')
        vendor_escaped=$(echo "$vendor" | sed 's/\\/\\\\/g; s/"/\\"/g')
        
        # Construire l'entrée JSON pour ce disque
        local disk_json
        disk_json=$(cat << EOF
        {
          "device": "$device_escaped",
          "model": "$model_escaped",
          "serial": "$serial_escaped",
          "size_bytes": $size_bytes,
          "size_human": "$size_human",
          "sector_size": $sector_size,
          "type": "$disk_type",
          "interface": "$interface",
          "vendor": "$vendor_escaped",
          "firmware": "$firmware",
          "is_removable": $is_removable,
          "is_rotational": $is_rotational,
          "is_virtual": $is_virtual,
          "partitions": $partitions_json,
          "partition_count": $partition_count,
          "health_status": "$health_status",
          "temperature_celsius": $temperature,
          "power_on_hours": $power_on_hours,
          "read_only": $read_only
        }
EOF
        )
        
        # Ajouter à la liste des disques
        if [[ $disk_count -eq 0 ]]; then
            disks_json="$disk_json"
        else
            disks_json="$disks_json,$disk_json"
        fi
        
        # Mettre à jour les compteurs et statistiques
        ((disk_count++))
        ((total_capacity_bytes += size_bytes))
        ((disk_types["$disk_type"]++))
        ((interfaces["$interface"]++))
        
        log_debug "Disque $device analysé: ${model} (${size_human})"
        
    done <<< "$disks"
    
    if [[ $disk_count -eq 0 ]]; then
        log_warn "Aucun disque trouvé correspondant aux critères"
    fi
    
    # Construire les statistiques de types et interfaces
    local disk_types_json=""
    for type in "${!disk_types[@]}"; do
        if [[ -z "$disk_types_json" ]]; then
            disk_types_json="\"$type\": ${disk_types[$type]}"
        else
            disk_types_json="$disk_types_json, \"$type\": ${disk_types[$type]}"
        fi
    done
    
    local interfaces_json=""
    for iface in "${!interfaces[@]}"; do
        if [[ -z "$interfaces_json" ]]; then
            interfaces_json="\"$iface\": ${interfaces[$iface]}"
        else
            interfaces_json="$interfaces_json, \"$iface\": ${interfaces[$iface]}"
        fi
    done
    
    log_debug "Détection terminée: $disk_count disques trouvés"
    
    # Générer la réponse JSON complète
    cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Disk detection completed successfully",
  "data": {
    "disks": [
      $disks_json
    ],
    "total_disks": $disk_count,
    "total_capacity_bytes": $total_capacity_bytes,
    "total_capacity_human": "$(human_readable_size $total_capacity_bytes)",
    "disk_types": {$disk_types_json},
    "interfaces": {$interfaces_json},
    "filters_applied": {
      "include_removable": $([ $INCLUDE_REMOVABLE -eq 1 ] && echo "true" || echo "false"),
      "include_virtual": $([ $INCLUDE_VIRTUAL -eq 1 ] && echo "true" || echo "false"),
      "min_size_gb": $MIN_SIZE_GB,
      "detailed_info": $([ $DETAILED_INFO -eq 1 ] && echo "true" || echo "false")
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
    detect_all_disks
    
    log_info "Script completed successfully"
}

# =============================================================================
# Point d'Entrée
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi