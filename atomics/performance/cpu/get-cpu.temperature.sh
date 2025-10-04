#!/usr/bin/env bash

# ===================================================================
# Script: get-cpu.temperature.sh
# Description: Récupère la température du CPU
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
UNIT="celsius"
SHOW_ALL_CORES=true

# === FONCTIONS ===

#################################################################
# Affiche l'aide du script
# Arguments: Aucun
# Retour: 0
#################################################################
show_help() {
    cat << 'EOF'
get-cpu.temperature.sh - Récupère la température du CPU

SYNOPSIS:
    get-cpu.temperature.sh [OPTIONS]

DESCRIPTION:
    Ce script collecte les températures CPU :
    - Température par cœur
    - Température globale du package
    - Détection via sensors et /sys/class/thermal
    - Support des seuils d'alerte
    
DÉPENDANCES:
    - sensors (lm-sensors) [recommandé]
    - /sys/class/thermal [fallback]
    
OPTIONS:
    -f, --format FORMAT    Format de sortie (json|text|csv) [défaut: json]
    -u, --unit UNIT        Unité (celsius|fahrenheit|kelvin) [défaut: celsius]
    -c, --core-only        Afficher seulement température moyenne
    -a, --all-cores        Afficher toutes les températures [défaut]
    -v, --verbose          Mode verbeux
    -q, --quiet            Mode silencieux
    -h, --help             Affiche cette aide

SORTIE:
    JSON avec les températures par cœur et globale

EXEMPLES:
    # Température CPU en JSON
    ./get-cpu.temperature.sh
    
    # Format texte, Fahrenheit
    ./get-cpu.temperature.sh --format text --unit fahrenheit
    
    # Seulement température moyenne
    ./get-cpu.temperature.sh --core-only

CODES DE RETOUR:
    0    Succès
    1    Erreur générale
    2    Aucune source de température trouvée
    3    Erreur de lecture des températures
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
                UNIT="$2"
                shift 2
                ;;
            -c|--core-only)
                SHOW_ALL_CORES=false
                shift
                ;;
            -a|--all-cores)
                SHOW_ALL_CORES=true
                shift
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
# Convertit la température selon l'unité demandée
# Arguments: $1 (température en celsius)
# Retour: température convertie
#################################################################
convert_temperature() {
    local temp_c="$1"
    
    case "$UNIT" in
        celsius|c)
            echo "$temp_c"
            ;;
        fahrenheit|f)
            echo "scale=1; ($temp_c * 9/5) + 32" | bc -l
            ;;
        kelvin|k)
            echo "scale=1; $temp_c + 273.15" | bc -l
            ;;
        *)
            echo "$temp_c"
            ;;
    esac
}

#################################################################
# Obtient le symbole d'unité
# Arguments: Aucun
# Retour: symbole d'unité
#################################################################
get_unit_symbol() {
    case "$UNIT" in
        celsius|c) echo "°C" ;;
        fahrenheit|f) echo "°F" ;;
        kelvin|k) echo "K" ;;
        *) echo "°C" ;;
    esac
}

#################################################################
# Collecte les températures via sensors
# Arguments: Aucun
# Retour: 0 si succès, 1 sinon
#################################################################
get_temperatures_sensors() {
    local sensors_output
    declare -A core_temps
    local package_temp=""
    
    if ! command -v sensors >/dev/null 2>&1; then
        return 1
    fi
    
    if ! sensors_output=$(sensors 2>/dev/null); then
        return 1
    fi
    
    # Parsing de la sortie sensors
    while IFS= read -r line; do
        # Température du package
        if [[ "$line" =~ Package.*:.*\+([0-9.]+)°C ]]; then
            package_temp="${BASH_REMATCH[1]}"
        # Températures des cœurs
        elif [[ "$line" =~ Core\ ([0-9]+):.*\+([0-9.]+)°C ]]; then
            local core_num="${BASH_REMATCH[1]}"
            local temp="${BASH_REMATCH[2]}"
            core_temps["core_$core_num"]="$temp"
        fi
    done <<< "$sensors_output"
    
    # Stockage des résultats
    PACKAGE_TEMP="$package_temp"
    CORE_TEMPS_ARRAY=()
    
    for core in $(printf '%s\n' "${!core_temps[@]}" | sort -V); do
        CORE_TEMPS_ARRAY+=("$core:${core_temps[$core]}")
    done
    
    # Si pas de température package, calculer la moyenne
    if [[ -z "$package_temp" && ${#CORE_TEMPS_ARRAY[@]} -gt 0 ]]; then
        local temp_sum=0
        local temp_count=0
        for core_temp in "${CORE_TEMPS_ARRAY[@]}"; do
            temp_sum=$(echo "$temp_sum + ${core_temp##*:}" | bc -l)
            ((temp_count++))
        done
        if [[ $temp_count -gt 0 ]]; then
            PACKAGE_TEMP=$(echo "scale=1; $temp_sum / $temp_count" | bc -l)
        fi
    fi
    
    return 0
}

#################################################################
# Collecte les températures via /sys/class/thermal
# Arguments: Aucun
# Retour: 0 si succès, 1 sinon
#################################################################
get_temperatures_thermal() {
    declare -A core_temps
    local package_temp=""
    
    # Parcours des zones thermales
    for thermal_zone in /sys/class/thermal/thermal_zone*; do
        if [[ ! -d "$thermal_zone" ]]; then
            continue
        fi
        
        local type_file="$thermal_zone/type"
        local temp_file="$thermal_zone/temp"
        
        if [[ ! -r "$type_file" || ! -r "$temp_file" ]]; then
            continue
        fi
        
        local zone_type=$(cat "$type_file" 2>/dev/null)
        local raw_temp=$(cat "$temp_file" 2>/dev/null)
        
        # Conversion de millidegrés en degrés
        if [[ "$raw_temp" =~ ^[0-9]+$ ]]; then
            local temp_c=$(echo "scale=1; $raw_temp / 1000" | bc -l)
            
            # Classification des zones thermales
            case "$zone_type" in
                *package*|*cpu*|*x86_pkg_temp*)
                    package_temp="$temp_c"
                    ;;
                *core*)
                    if [[ "$zone_type" =~ core([0-9]+) ]]; then
                        local core_num="${BASH_REMATCH[1]}"
                        core_temps["core_$core_num"]="$temp_c"
                    else
                        core_temps["core_${zone_type##*_}"]="$temp_c"
                    fi
                    ;;
            esac
        fi
    done
    
    # Stockage des résultats
    PACKAGE_TEMP="$package_temp"
    CORE_TEMPS_ARRAY=()
    
    for core in $(printf '%s\n' "${!core_temps[@]}" | sort -V); do
        CORE_TEMPS_ARRAY+=("$core:${core_temps[$core]}")
    done
    
    # Si pas de température package, calculer la moyenne
    if [[ -z "$package_temp" && ${#CORE_TEMPS_ARRAY[@]} -gt 0 ]]; then
        local temp_sum=0
        local temp_count=0
        for core_temp in "${CORE_TEMPS_ARRAY[@]}"; do
            temp_sum=$(echo "$temp_sum + ${core_temp##*:}" | bc -l)
            ((temp_count++))
        done
        if [[ $temp_count -gt 0 ]]; then
            PACKAGE_TEMP=$(echo "scale=1; $temp_sum / $temp_count" | bc -l)
        fi
    fi
    
    [[ ${#CORE_TEMPS_ARRAY[@]} -gt 0 || -n "$package_temp" ]]
}

#################################################################
# Formate et affiche les résultats
# Arguments: Aucun
# Retour: 0
#################################################################
output_results() {
    local unit_symbol
    unit_symbol=$(get_unit_symbol)
    
    # Conversion des températures
    local converted_package_temp=""
    if [[ -n "$PACKAGE_TEMP" ]]; then
        converted_package_temp=$(convert_temperature "$PACKAGE_TEMP")
    fi
    
    case "$OUTPUT_FORMAT" in
        json)
            echo "{"
            echo "  \"timestamp\": \"$(date -Iseconds)\","
            echo "  \"unit\": \"$unit_symbol\","
            echo "  \"cpu_temperature\": {"
            
            if [[ -n "$converted_package_temp" ]]; then
                echo "    \"package\": $converted_package_temp,"
            fi
            
            if $SHOW_ALL_CORES && [[ ${#CORE_TEMPS_ARRAY[@]} -gt 0 ]]; then
                echo "    \"cores\": {"
                local first=true
                for core_temp in "${CORE_TEMPS_ARRAY[@]}"; do
                    local core_name="${core_temp%%:*}"
                    local core_val="${core_temp##*:}"
                    local converted_core_temp
                    converted_core_temp=$(convert_temperature "$core_val")
                    
                    if $first; then
                        first=false
                    else
                        echo ","
                    fi
                    echo -n "      \"$core_name\": $converted_core_temp"
                done
                echo ""
                echo "    },"
            fi
            
            echo "    \"status\": \"$(get_temperature_status "$PACKAGE_TEMP")\""
            echo "  }"
            echo "}"
            ;;
        text)
            echo "=== Températures CPU ==="
            if [[ -n "$converted_package_temp" ]]; then
                echo "Package: $converted_package_temp$unit_symbol"
            fi
            
            if $SHOW_ALL_CORES && [[ ${#CORE_TEMPS_ARRAY[@]} -gt 0 ]]; then
                echo "Cœurs:"
                for core_temp in "${CORE_TEMPS_ARRAY[@]}"; do
                    local core_name="${core_temp%%:*}"
                    local core_val="${core_temp##*:}"
                    local converted_core_temp
                    converted_core_temp=$(convert_temperature "$core_val")
                    echo "  $core_name: $converted_core_temp$unit_symbol"
                done
            fi
            
            echo "Statut: $(get_temperature_status "$PACKAGE_TEMP")"
            ;;
        csv)
            echo "timestamp,unit,package_temp,core_temps,status"
            local core_temps_csv=""
            for core_temp in "${CORE_TEMPS_ARRAY[@]}"; do
                if [[ -n "$core_temps_csv" ]]; then
                    core_temps_csv="$core_temps_csv;"
                fi
                local core_name="${core_temp%%:*}"
                local core_val="${core_temp##*:}"
                local converted_core_temp
                converted_core_temp=$(convert_temperature "$core_val")
                core_temps_csv="$core_temps_csv$core_name=$converted_core_temp"
            done
            echo "$(date -Iseconds),$unit_symbol,$converted_package_temp,\"$core_temps_csv\",$(get_temperature_status "$PACKAGE_TEMP")"
            ;;
        *)
            atomic_error "Format non supporté: $OUTPUT_FORMAT"
            return 1
            ;;
    esac
    return 0
}

#################################################################
# Détermine le statut de température
# Arguments: $1 (température en celsius)
# Retour: statut (normal|warning|critical)
#################################################################
get_temperature_status() {
    local temp_c="$1"
    
    if [[ -z "$temp_c" ]]; then
        echo "unknown"
        return
    fi
    
    # Seuils en Celsius
    if (( $(echo "$temp_c >= 85" | bc -l) )); then
        echo "critical"
    elif (( $(echo "$temp_c >= 70" | bc -l) )); then
        echo "warning"
    else
        echo "normal"
    fi
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
        atomic_error "bc requis pour les conversions de température"
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
    
    # Tentative de collecte via sensors d'abord
    if get_temperatures_sensors; then
        if $VERBOSE; then
            atomic_success "Températures collectées via sensors"
        fi
    elif get_temperatures_thermal; then
        if $VERBOSE; then
            atomic_success "Températures collectées via /sys/class/thermal"
        fi
    else
        atomic_error "Aucune source de température disponible"
        atomic_info "Installez lm-sensors: apt install lm-sensors && sensors-detect"
        return 2
    fi
    
    # Vérification qu'on a au moins une température
    if [[ -z "$PACKAGE_TEMP" && ${#CORE_TEMPS_ARRAY[@]} -eq 0 ]]; then
        atomic_error "Aucune température trouvée"
        return 3
    fi
    
    # Affichage des résultats
    if ! output_results; then
        return 1
    fi
    
    if $VERBOSE; then
        atomic_success "Collecte des températures CPU terminée"
    fi
    
    return 0
}

# === EXÉCUTION ===
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi