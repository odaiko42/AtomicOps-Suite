#!/usr/bin/env bash

# ===================================================================
# Script: get-memory.info.sh
# Description: Récupère les informations mémoire détaillées
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
UNIT="MB"

# === FONCTIONS ===

#################################################################
# Affiche l'aide du script
# Arguments: Aucun
# Retour: 0
#################################################################
show_help() {
    cat << 'EOF'
get-memory.info.sh - Récupère les informations mémoire détaillées

SYNOPSIS:
    get-memory.info.sh [OPTIONS]

DESCRIPTION:
    Ce script collecte des informations détaillées sur la mémoire :
    - Informations physiques (DMI)
    - Capacité totale, type, vitesse
    - Nombre de slots et modules installés
    - Utilisation actuelle détaillée
    - Statistiques des caches
    
DÉPENDANCES:
    - dmidecode (dmi-utils)
    - free (procps)
    - /proc/meminfo
    
OPTIONS:
    -f, --format FORMAT    Format de sortie (json|text|csv) [défaut: json]
    -u, --unit UNIT        Unité (B|KB|MB|GB) [défaut: MB]
    -v, --verbose          Mode verbeux
    -q, --quiet            Mode silencieux
    -h, --help             Affiche cette aide

SORTIE:
    JSON avec les informations mémoire complètes

EXEMPLES:
    # Informations mémoire en JSON
    ./get-memory.info.sh
    
    # Format texte en GB
    ./get-memory.info.sh --format text --unit GB
    
    # Mode verbeux
    ./get-memory.info.sh -v

CODES DE RETOUR:
    0    Succès
    1    Erreur générale
    2    Dépendance manquante
    3    Erreur de lecture des informations
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
            -u|--unit)
                if [[ -z "${2:-}" ]]; then
                    atomic_error "Unité requise pour l'option --unit"
                    return 1
                fi
                case "$2" in
                    B|KB|MB|GB)
                        UNIT="$2"
                        ;;
                    *)
                        atomic_error "Unité invalide: $2 (B|KB|MB|GB)"
                        return 1
                        ;;
                esac
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
# Convertit les bytes selon l'unité demandée
# Arguments: $1 (valeur en bytes)
# Retour: valeur convertie
#################################################################
convert_bytes() {
    local bytes="$1"
    
    if [[ ! "$bytes" =~ ^[0-9]+$ ]]; then
        echo "N/A"
        return
    fi
    
    case "$UNIT" in
        B)
            echo "$bytes"
            ;;
        KB)
            echo $((bytes / 1024))
            ;;
        MB)
            echo $((bytes / 1024 / 1024))
            ;;
        GB)
            echo "scale=2; $bytes / 1024 / 1024 / 1024" | bc -l
            ;;
        *)
            echo "$bytes"
            ;;
    esac
}

#################################################################
# Vérifie les dépendances nécessaires
# Arguments: Aucun
# Retour: 0 si toutes présentes, 2 sinon
#################################################################
check_dependencies() {
    local missing_deps=()
    
    # Vérification des commandes
    if ! command -v free >/dev/null 2>&1; then
        missing_deps+=("free")
    fi
    
    # dmidecode est optionnel mais recommandé
    if ! command -v dmidecode >/dev/null 2>&1; then
        atomic_warn "dmidecode non trouvé - informations physiques limitées"
    fi
    
    # Vérification des fichiers système
    if [[ ! -r /proc/meminfo ]]; then
        missing_deps+=("/proc/meminfo")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        atomic_error "Dépendances manquantes: ${missing_deps[*]}"
        atomic_info "Installation suggérée: apt install procps dmidecode"
        return 2
    fi
    
    return 0
}

#################################################################
# Collecte les informations via dmidecode
# Arguments: Aucun
# Retour: 0 si succès, 1 sinon
#################################################################
get_dmi_info() {
    local dmi_output
    
    # Initialisation des variables
    MEMORY_SLOTS_TOTAL=0
    MEMORY_SLOTS_USED=0
    MEMORY_MODULES=()
    MEMORY_TOTAL_INSTALLED=0
    MEMORY_MAX_CAPACITY=""
    MEMORY_SPEED=""
    MEMORY_TYPE=""
    
    if ! command -v dmidecode >/dev/null 2>&1; then
        if $VERBOSE; then
            atomic_warn "dmidecode non disponible - informations physiques non collectées"
        fi
        return 1
    fi
    
    if ! dmi_output=$(dmidecode -t memory 2>/dev/null); then
        if $VERBOSE; then
            atomic_warn "Erreur dmidecode - peut nécessiter des permissions root"
        fi
        return 1
    fi
    
    # Parsing des informations de slots
    local in_memory_device=false
    local slot_size=""
    local slot_speed=""
    local slot_type=""
    local slot_locator=""
    
    while IFS= read -r line; do
        line=$(echo "$line" | xargs) # Trim whitespace
        
        if [[ "$line" == "Memory Device" ]]; then
            # Nouveau device, sauver le précédent si valide
            if $in_memory_device && [[ -n "$slot_size" && "$slot_size" != "No Module Installed" ]]; then
                MEMORY_MODULES+=("$slot_locator|$slot_size|$slot_type|$slot_speed")
                ((MEMORY_SLOTS_USED++))
                
                # Conversion de la taille en bytes
                if [[ "$slot_size" =~ ([0-9]+).*MB ]]; then
                    local size_mb="${BASH_REMATCH[1]}"
                    MEMORY_TOTAL_INSTALLED=$((MEMORY_TOTAL_INSTALLED + size_mb * 1024 * 1024))
                elif [[ "$slot_size" =~ ([0-9]+).*GB ]]; then
                    local size_gb="${BASH_REMATCH[1]}"
                    MEMORY_TOTAL_INSTALLED=$((MEMORY_TOTAL_INSTALLED + size_gb * 1024 * 1024 * 1024))
                fi
            fi
            
            # Reset pour le nouveau device
            in_memory_device=true
            slot_size=""
            slot_speed=""
            slot_type=""
            slot_locator=""
            ((MEMORY_SLOTS_TOTAL++))
            
        elif $in_memory_device; then
            if [[ "$line" =~ ^Size:\ (.+) ]]; then
                slot_size="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^Type:\ (.+) ]]; then
                slot_type="${BASH_REMATCH[1]}"
                if [[ -z "$MEMORY_TYPE" ]]; then
                    MEMORY_TYPE="$slot_type"
                fi
            elif [[ "$line" =~ ^Speed:\ (.+) ]]; then
                slot_speed="${BASH_REMATCH[1]}"
                if [[ -z "$MEMORY_SPEED" ]]; then
                    MEMORY_SPEED="$slot_speed"
                fi
            elif [[ "$line" =~ ^Locator:\ (.+) ]]; then
                slot_locator="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^Maximum\ Capacity:\ (.+) ]]; then
                MEMORY_MAX_CAPACITY="${BASH_REMATCH[1]}"
            fi
        fi
    done <<< "$dmi_output"
    
    # Traiter le dernier device
    if $in_memory_device && [[ -n "$slot_size" && "$slot_size" != "No Module Installed" ]]; then
        MEMORY_MODULES+=("$slot_locator|$slot_size|$slot_type|$slot_speed")
        ((MEMORY_SLOTS_USED++))
        
        if [[ "$slot_size" =~ ([0-9]+).*MB ]]; then
            local size_mb="${BASH_REMATCH[1]}"
            MEMORY_TOTAL_INSTALLED=$((MEMORY_TOTAL_INSTALLED + size_mb * 1024 * 1024))
        elif [[ "$slot_size" =~ ([0-9]+).*GB ]]; then
            local size_gb="${BASH_REMATCH[1]}"
            MEMORY_TOTAL_INSTALLED=$((MEMORY_TOTAL_INSTALLED + size_gb * 1024 * 1024 * 1024))
        fi
    fi
    
    return 0
}

#################################################################
# Collecte les informations via /proc/meminfo
# Arguments: Aucun
# Retour: 0 si succès, 3 sinon
#################################################################
get_meminfo() {
    local meminfo_output
    
    if ! meminfo_output=$(cat /proc/meminfo 2>/dev/null); then
        atomic_error "Impossible de lire /proc/meminfo"
        return 3
    fi
    
    # Extraction des valeurs (en kB)
    MEM_TOTAL=$(echo "$meminfo_output" | grep "MemTotal:" | awk '{print $2}')
    MEM_FREE=$(echo "$meminfo_output" | grep "MemFree:" | awk '{print $2}')
    MEM_AVAILABLE=$(echo "$meminfo_output" | grep "MemAvailable:" | awk '{print $2}')
    MEM_BUFFERS=$(echo "$meminfo_output" | grep "Buffers:" | awk '{print $2}')
    MEM_CACHED=$(echo "$meminfo_output" | grep "^Cached:" | awk '{print $2}')
    MEM_SLAB=$(echo "$meminfo_output" | grep "Slab:" | awk '{print $2}')
    MEM_ACTIVE=$(echo "$meminfo_output" | grep "Active:" | awk '{print $2}')
    MEM_INACTIVE=$(echo "$meminfo_output" | grep "Inactive:" | awk '{print $2}')
    MEM_DIRTY=$(echo "$meminfo_output" | grep "Dirty:" | awk '{print $2}')
    MEM_WRITEBACK=$(echo "$meminfo_output" | grep "Writeback:" | awk '{print $2}')
    
    # Conversion en bytes
    MEM_TOTAL=$((MEM_TOTAL * 1024))
    MEM_FREE=$((MEM_FREE * 1024))
    MEM_AVAILABLE=$((MEM_AVAILABLE * 1024))
    MEM_BUFFERS=$((MEM_BUFFERS * 1024))
    MEM_CACHED=$((MEM_CACHED * 1024))
    MEM_SLAB=$((MEM_SLAB * 1024))
    MEM_ACTIVE=$((MEM_ACTIVE * 1024))
    MEM_INACTIVE=$((MEM_INACTIVE * 1024))
    MEM_DIRTY=$((MEM_DIRTY * 1024))
    MEM_WRITEBACK=$((MEM_WRITEBACK * 1024))
    
    # Calculs dérivés
    MEM_USED=$((MEM_TOTAL - MEM_FREE - MEM_BUFFERS - MEM_CACHED))
    MEM_USAGE_PERCENT=$(echo "scale=1; ($MEM_USED * 100) / $MEM_TOTAL" | bc -l 2>/dev/null || echo "0")
    
    return 0
}

#################################################################
# Collecte les informations via free
# Arguments: Aucun
# Retour: 0 si succès, 3 sinon
#################################################################
get_free_info() {
    local free_output
    
    if ! free_output=$(free -b 2>/dev/null); then
        atomic_error "Erreur lors de l'exécution de free"
        return 3
    fi
    
    # Parse de la sortie free (ligne Mem:)
    local mem_line
    mem_line=$(echo "$free_output" | grep "Mem:")
    
    if [[ -n "$mem_line" ]]; then
        read -r _ FREE_TOTAL FREE_USED FREE_FREE FREE_SHARED FREE_BUFF_CACHE FREE_AVAILABLE <<< "$mem_line"
        
        # Validation des valeurs
        FREE_TOTAL=${FREE_TOTAL:-0}
        FREE_USED=${FREE_USED:-0}
        FREE_FREE=${FREE_FREE:-0}
        FREE_SHARED=${FREE_SHARED:-0}
        FREE_BUFF_CACHE=${FREE_BUFF_CACHE:-0}
        FREE_AVAILABLE=${FREE_AVAILABLE:-0}
    fi
    
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
            echo "{"
            echo "  \"timestamp\": \"$(date -Iseconds)\","
            echo "  \"unit\": \"$UNIT\","
            echo "  \"memory\": {"
            
            # Informations physiques
            echo "    \"physical\": {"
            if [[ -n "${MEMORY_TYPE:-}" ]]; then
                echo "      \"type\": \"$MEMORY_TYPE\","
            fi
            if [[ -n "${MEMORY_SPEED:-}" ]]; then
                echo "      \"speed\": \"$MEMORY_SPEED\","
            fi
            if [[ -n "${MEMORY_MAX_CAPACITY:-}" ]]; then
                echo "      \"max_capacity\": \"$MEMORY_MAX_CAPACITY\","
            fi
            echo "      \"slots_total\": $MEMORY_SLOTS_TOTAL,"
            echo "      \"slots_used\": $MEMORY_SLOTS_USED,"
            
            if [[ ${#MEMORY_MODULES[@]} -gt 0 ]]; then
                echo "      \"modules\": ["
                local first=true
                for module in "${MEMORY_MODULES[@]}"; do
                    IFS='|' read -r locator size type speed <<< "$module"
                    
                    if $first; then
                        first=false
                    else
                        echo ","
                    fi
                    
                    echo "        {"
                    echo "          \"locator\": \"$locator\","
                    echo "          \"size\": \"$size\","
                    echo "          \"type\": \"$type\","
                    echo "          \"speed\": \"$speed\""
                    echo -n "        }"
                done
                echo ""
                echo "      ],"
            fi
            
            if [[ $MEMORY_TOTAL_INSTALLED -gt 0 ]]; then
                echo "      \"installed_$(echo "$UNIT" | tr '[:upper:]' '[:lower:]')\": $(convert_bytes "$MEMORY_TOTAL_INSTALLED"),"
            fi
            echo "      \"installed\": true"
            echo "    },"
            
            # Utilisation actuelle
            echo "    \"usage\": {"
            echo "      \"total_$(echo "$UNIT" | tr '[:upper:]' '[:lower:]')\": $(convert_bytes "$MEM_TOTAL"),"
            echo "      \"used_$(echo "$UNIT" | tr '[:upper:]' '[:lower:]')\": $(convert_bytes "$MEM_USED"),"
            echo "      \"free_$(echo "$UNIT" | tr '[:upper:]' '[:lower:]')\": $(convert_bytes "$MEM_FREE"),"
            echo "      \"available_$(echo "$UNIT" | tr '[:upper:]' '[:lower:]')\": $(convert_bytes "$MEM_AVAILABLE"),"
            echo "      \"usage_percent\": $MEM_USAGE_PERCENT,"
            echo "      \"buffers_$(echo "$UNIT" | tr '[:upper:]' '[:lower:]')\": $(convert_bytes "$MEM_BUFFERS"),"
            echo "      \"cached_$(echo "$UNIT" | tr '[:upper:]' '[:lower:]')\": $(convert_bytes "$MEM_CACHED"),"
            echo "      \"slab_$(echo "$UNIT" | tr '[:upper:]' '[:lower:]')\": $(convert_bytes "$MEM_SLAB"),"
            echo "      \"active_$(echo "$UNIT" | tr '[:upper:]' '[:lower:]')\": $(convert_bytes "$MEM_ACTIVE"),"
            echo "      \"inactive_$(echo "$UNIT" | tr '[:upper:]' '[:lower:]')\": $(convert_bytes "$MEM_INACTIVE")"
            echo "    }"
            
            echo "  }"
            echo "}"
            ;;
        text)
            echo "=== Informations Mémoire ==="
            
            # Informations physiques
            if [[ -n "${MEMORY_TYPE:-}" ]]; then
                echo "Type: $MEMORY_TYPE"
            fi
            if [[ -n "${MEMORY_SPEED:-}" ]]; then
                echo "Vitesse: $MEMORY_SPEED"
            fi
            echo "Slots: $MEMORY_SLOTS_USED/$MEMORY_SLOTS_TOTAL utilisés"
            
            if [[ ${#MEMORY_MODULES[@]} -gt 0 ]]; then
                echo ""
                echo "Modules installés:"
                for module in "${MEMORY_MODULES[@]}"; do
                    IFS='|' read -r locator size type speed <<< "$module"
                    echo "  $locator: $size ($type, $speed)"
                done
            fi
            
            echo ""
            echo "=== Utilisation Actuelle ==="
            echo "Total: $(convert_bytes "$MEM_TOTAL") $UNIT"
            echo "Utilisé: $(convert_bytes "$MEM_USED") $UNIT ($MEM_USAGE_PERCENT%)"
            echo "Libre: $(convert_bytes "$MEM_FREE") $UNIT"
            echo "Disponible: $(convert_bytes "$MEM_AVAILABLE") $UNIT"
            echo "Buffers: $(convert_bytes "$MEM_BUFFERS") $UNIT"
            echo "Cache: $(convert_bytes "$MEM_CACHED") $UNIT"
            echo "Slab: $(convert_bytes "$MEM_SLAB") $UNIT"
            ;;
        csv)
            echo "timestamp,unit,total_${UNIT,,},used_${UNIT,,},free_${UNIT,,},available_${UNIT,,},usage_percent,buffers_${UNIT,,},cached_${UNIT,,},slots_used,slots_total,memory_type"
            echo "$(date -Iseconds),$UNIT,$(convert_bytes "$MEM_TOTAL"),$(convert_bytes "$MEM_USED"),$(convert_bytes "$MEM_FREE"),$(convert_bytes "$MEM_AVAILABLE"),$MEM_USAGE_PERCENT,$(convert_bytes "$MEM_BUFFERS"),$(convert_bytes "$MEM_CACHED"),$MEMORY_SLOTS_USED,$MEMORY_SLOTS_TOTAL,${MEMORY_TYPE:-N/A}"
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
    
    # Vérification de bc pour les calculs
    if ! command -v bc >/dev/null 2>&1; then
        atomic_error "bc requis pour les calculs"
        return 2
    fi
    
    # Parse des arguments
    if ! parse_args "$@"; then
        atomic_error "Erreur dans les arguments"
        show_help >&2
        return 1
    fi
    
    # Mode verbeux
    if $VERBOSE; then
        atomic_info "Démarrage de $SCRIPT_NAME"
        atomic_info "Format: $OUTPUT_FORMAT, Unité: $UNIT"
    fi
    
    # Vérification des dépendances
    if ! check_dependencies; then
        return 2
    fi
    
    # Collecte des informations DMI (optionnel)
    get_dmi_info
    
    # Collecte des informations /proc/meminfo
    if ! get_meminfo; then
        return 3
    fi
    
    # Collecte des informations free (validation)
    get_free_info
    
    # Affichage des résultats
    if ! output_results; then
        return 1
    fi
    
    if $VERBOSE; then
        atomic_success "Collecte des informations mémoire terminée"
    fi
    
    return 0
}

# === EXÉCUTION ===
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi