#!/usr/bin/env bash

# ===================================================================
# Script: get-cpu.frequency.sh
# Description: Récupère la fréquence CPU actuelle
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
SHOW_ALL_CORES=true

# === FONCTIONS ===

#################################################################
# Affiche l'aide du script
# Arguments: Aucun
# Retour: 0
#################################################################
show_help() {
    cat << 'EOF'
get-cpu.frequency.sh - Récupère la fréquence CPU actuelle

SYNOPSIS:
    get-cpu.frequency.sh [OPTIONS]

DESCRIPTION:
    Ce script collecte les fréquences CPU actuelles :
    - Fréquence par cœur
    - Fréquences min/max configurées
    - Gouverneur de fréquence actuel
    - Détection via cpufreq et /proc/cpuinfo
    
DÉPENDANCES:
    - cpufreq-info [recommandé]
    - /sys/devices/system/cpu/cpu*/cpufreq/
    - /proc/cpuinfo [fallback]
    
OPTIONS:
    -f, --format FORMAT    Format de sortie (json|text|csv) [défaut: json]
    -c, --core-only        Afficher seulement fréquence moyenne
    -a, --all-cores        Afficher toutes les fréquences [défaut]
    -v, --verbose          Mode verbeux
    -q, --quiet            Mode silencieux
    -h, --help             Affiche cette aide

SORTIE:
    JSON avec les fréquences par cœur et informations cpufreq

EXEMPLES:
    # Fréquences CPU en JSON
    ./get-cpu.frequency.sh
    
    # Format texte
    ./get-cpu.frequency.sh --format text
    
    # Seulement fréquence moyenne
    ./get-cpu.frequency.sh --core-only

CODES DE RETOUR:
    0    Succès
    1    Erreur générale
    2    Aucune source de fréquence trouvée
    3    Erreur de lecture des fréquences
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
# Collecte les fréquences via cpufreq-info
# Arguments: Aucun
# Retour: 0 si succès, 1 sinon
#################################################################
get_frequencies_cpufreq() {
    declare -A core_freqs
    declare -A core_min_freqs
    declare -A core_max_freqs
    declare -A core_governors
    local avg_freq=0
    local freq_count=0
    
    if ! command -v cpufreq-info >/dev/null 2>&1; then
        return 1
    fi
    
    # Obtenir la liste des CPUs
    local cpu_list
    if ! cpu_list=$(cpufreq-info -l 2>/dev/null); then
        return 1
    fi
    
    for cpu in $cpu_list; do
        local current_freq min_freq max_freq governor
        
        # Fréquence actuelle
        if current_freq=$(cpufreq-info -c "$cpu" -f 2>/dev/null); then
            # Convertir en MHz si nécessaire
            if [[ "$current_freq" =~ ^[0-9]+$ ]]; then
                # Si c'est en Hz, convertir en MHz
                if [[ ${#current_freq} -gt 6 ]]; then
                    current_freq=$((current_freq / 1000000))
                # Si c'est en kHz, convertir en MHz
                elif [[ ${#current_freq} -gt 3 ]]; then
                    current_freq=$((current_freq / 1000))
                fi
            fi
            core_freqs["cpu$cpu"]="$current_freq"
            avg_freq=$((avg_freq + current_freq))
            ((freq_count++))
        fi
        
        # Limites de fréquence
        if min_freq=$(cpufreq-info -c "$cpu" -l 2>/dev/null | awk '{print $1}'); then
            min_freq=$((min_freq / 1000)) # kHz vers MHz
            core_min_freqs["cpu$cpu"]="$min_freq"
        fi
        
        if max_freq=$(cpufreq-info -c "$cpu" -l 2>/dev/null | awk '{print $2}'); then
            max_freq=$((max_freq / 1000)) # kHz vers MHz
            core_max_freqs["cpu$cpu"]="$max_freq"
        fi
        
        # Gouverneur
        if governor=$(cpufreq-info -c "$cpu" -p 2>/dev/null | awk '{print $3}'); then
            core_governors["cpu$cpu"]="$governor"
        fi
    done
    
    # Calcul de la fréquence moyenne
    if [[ $freq_count -gt 0 ]]; then
        AVERAGE_FREQ=$((avg_freq / freq_count))
    fi
    
    # Stockage des résultats
    CORE_FREQS_ARRAY=()
    for cpu in $(printf '%s\n' "${!core_freqs[@]}" | sort -V); do
        local freq="${core_freqs[$cpu]:-N/A}"
        local min_freq="${core_min_freqs[$cpu]:-N/A}"
        local max_freq="${core_max_freqs[$cpu]:-N/A}"
        local governor="${core_governors[$cpu]:-N/A}"
        CORE_FREQS_ARRAY+=("$cpu:$freq:$min_freq:$max_freq:$governor")
    done
    
    return 0
}

#################################################################
# Collecte les fréquences via sysfs
# Arguments: Aucun
# Retour: 0 si succès, 1 sinon
#################################################################
get_frequencies_sysfs() {
    declare -A core_freqs
    declare -A core_min_freqs
    declare -A core_max_freqs
    declare -A core_governors
    local avg_freq=0
    local freq_count=0
    
    # Parcours des CPUs disponibles
    for cpu_dir in /sys/devices/system/cpu/cpu[0-9]*; do
        if [[ ! -d "$cpu_dir/cpufreq" ]]; then
            continue
        fi
        
        local cpu_num
        cpu_num=$(basename "$cpu_dir" | sed 's/cpu//')
        local cpufreq_dir="$cpu_dir/cpufreq"
        
        # Fréquence actuelle
        if [[ -r "$cpufreq_dir/scaling_cur_freq" ]]; then
            local current_freq
            current_freq=$(cat "$cpufreq_dir/scaling_cur_freq" 2>/dev/null)
            if [[ "$current_freq" =~ ^[0-9]+$ ]]; then
                current_freq=$((current_freq / 1000)) # kHz vers MHz
                core_freqs["cpu$cpu_num"]="$current_freq"
                avg_freq=$((avg_freq + current_freq))
                ((freq_count++))
            fi
        fi
        
        # Fréquence minimale
        if [[ -r "$cpufreq_dir/scaling_min_freq" ]]; then
            local min_freq
            min_freq=$(cat "$cpufreq_dir/scaling_min_freq" 2>/dev/null)
            if [[ "$min_freq" =~ ^[0-9]+$ ]]; then
                min_freq=$((min_freq / 1000)) # kHz vers MHz
                core_min_freqs["cpu$cpu_num"]="$min_freq"
            fi
        fi
        
        # Fréquence maximale
        if [[ -r "$cpufreq_dir/scaling_max_freq" ]]; then
            local max_freq
            max_freq=$(cat "$cpufreq_dir/scaling_max_freq" 2>/dev/null)
            if [[ "$max_freq" =~ ^[0-9]+$ ]]; then
                max_freq=$((max_freq / 1000)) # kHz vers MHz
                core_max_freqs["cpu$cpu_num"]="$max_freq"
            fi
        fi
        
        # Gouverneur
        if [[ -r "$cpufreq_dir/scaling_governor" ]]; then
            local governor
            governor=$(cat "$cpufreq_dir/scaling_governor" 2>/dev/null)
            core_governors["cpu$cpu_num"]="$governor"
        fi
    done
    
    # Calcul de la fréquence moyenne
    if [[ $freq_count -gt 0 ]]; then
        AVERAGE_FREQ=$((avg_freq / freq_count))
    fi
    
    # Stockage des résultats
    CORE_FREQS_ARRAY=()
    for cpu in $(printf '%s\n' "${!core_freqs[@]}" | sort -V); do
        local freq="${core_freqs[$cpu]:-N/A}"
        local min_freq="${core_min_freqs[$cpu]:-N/A}"
        local max_freq="${core_max_freqs[$cpu]:-N/A}"
        local governor="${core_governors[$cpu]:-N/A}"
        CORE_FREQS_ARRAY+=("$cpu:$freq:$min_freq:$max_freq:$governor")
    done
    
    [[ ${#CORE_FREQS_ARRAY[@]} -gt 0 ]]
}

#################################################################
# Collecte les fréquences via /proc/cpuinfo (fallback)
# Arguments: Aucun
# Retour: 0 si succès, 1 sinon
#################################################################
get_frequencies_proc() {
    local cpuinfo_output
    declare -A core_freqs
    local avg_freq=0
    local freq_count=0
    
    if ! cpuinfo_output=$(cat /proc/cpuinfo 2>/dev/null); then
        return 1
    fi
    
    # Parsing des fréquences dans /proc/cpuinfo
    local processor=-1
    while IFS= read -r line; do
        if [[ "$line" =~ ^processor.*:.*([0-9]+) ]]; then
            processor="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^cpu\ MHz.*:.*([0-9.]+) ]]; then
            local freq="${BASH_REMATCH[1]}"
            freq=${freq%.*} # Enlever les décimales
            if [[ $processor -ge 0 ]]; then
                core_freqs["cpu$processor"]="$freq"
                avg_freq=$((avg_freq + freq))
                ((freq_count++))
            fi
        fi
    done <<< "$cpuinfo_output"
    
    # Calcul de la fréquence moyenne
    if [[ $freq_count -gt 0 ]]; then
        AVERAGE_FREQ=$((avg_freq / freq_count))
    fi
    
    # Stockage des résultats (données limitées)
    CORE_FREQS_ARRAY=()
    for cpu in $(printf '%s\n' "${!core_freqs[@]}" | sort -V); do
        local freq="${core_freqs[$cpu]}"
        CORE_FREQS_ARRAY+=("$cpu:$freq:N/A:N/A:N/A")
    done
    
    [[ ${#CORE_FREQS_ARRAY[@]} -gt 0 ]]
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
            echo "  \"cpu_frequency\": {"
            echo "    \"unit\": \"MHz\","
            
            if [[ -n "${AVERAGE_FREQ:-}" ]]; then
                echo "    \"average\": $AVERAGE_FREQ,"
            fi
            
            if $SHOW_ALL_CORES && [[ ${#CORE_FREQS_ARRAY[@]} -gt 0 ]]; then
                echo "    \"cores\": {"
                local first=true
                for core_data in "${CORE_FREQS_ARRAY[@]}"; do
                    IFS=':' read -r cpu freq min_freq max_freq governor <<< "$core_data"
                    
                    if $first; then
                        first=false
                    else
                        echo ","
                    fi
                    
                    echo -n "      \"$cpu\": {"
                    echo -n "\"current\": \"$freq\""
                    if [[ "$min_freq" != "N/A" ]]; then
                        echo -n ", \"min\": \"$min_freq\""
                    fi
                    if [[ "$max_freq" != "N/A" ]]; then
                        echo -n ", \"max\": \"$max_freq\""
                    fi
                    if [[ "$governor" != "N/A" ]]; then
                        echo -n ", \"governor\": \"$governor\""
                    fi
                    echo -n "}"
                done
                echo ""
                echo "    }"
            else
                echo "    \"cores\": {}"
            fi
            
            echo "  }"
            echo "}"
            ;;
        text)
            echo "=== Fréquences CPU ==="
            if [[ -n "${AVERAGE_FREQ:-}" ]]; then
                echo "Fréquence moyenne: ${AVERAGE_FREQ} MHz"
            fi
            
            if $SHOW_ALL_CORES && [[ ${#CORE_FREQS_ARRAY[@]} -gt 0 ]]; then
                echo "Détail par cœur:"
                for core_data in "${CORE_FREQS_ARRAY[@]}"; do
                    IFS=':' read -r cpu freq min_freq max_freq governor <<< "$core_data"
                    echo "  $cpu: ${freq} MHz"
                    if [[ "$min_freq" != "N/A" && "$max_freq" != "N/A" ]]; then
                        echo "    Limites: ${min_freq}-${max_freq} MHz"
                    fi
                    if [[ "$governor" != "N/A" ]]; then
                        echo "    Gouverneur: $governor"
                    fi
                done
            fi
            ;;
        csv)
            echo "timestamp,cpu,current_mhz,min_mhz,max_mhz,governor"
            for core_data in "${CORE_FREQS_ARRAY[@]}"; do
                IFS=':' read -r cpu freq min_freq max_freq governor <<< "$core_data"
                echo "$(date -Iseconds),$cpu,$freq,$min_freq,$max_freq,$governor"
            done
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
        atomic_info "Format: $OUTPUT_FORMAT"
    fi
    
    # Tentative de collecte via cpufreq-info d'abord
    if get_frequencies_cpufreq; then
        if $VERBOSE; then
            atomic_success "Fréquences collectées via cpufreq-info"
        fi
    elif get_frequencies_sysfs; then
        if $VERBOSE; then
            atomic_success "Fréquences collectées via sysfs"
        fi
    elif get_frequencies_proc; then
        if $VERBOSE; then
            atomic_success "Fréquences collectées via /proc/cpuinfo"
        fi
    else
        atomic_error "Aucune source de fréquence disponible"
        atomic_info "Installez cpufrequtils: apt install cpufrequtils"
        return 2
    fi
    
    # Vérification qu'on a au moins une fréquence
    if [[ ${#CORE_FREQS_ARRAY[@]} -eq 0 ]]; then
        atomic_error "Aucune fréquence trouvée"
        return 3
    fi
    
    # Affichage des résultats
    if ! output_results; then
        return 1
    fi
    
    if $VERBOSE; then
        atomic_success "Collecte des fréquences CPU terminée"
    fi
    
    return 0
}

# === EXÉCUTION ===
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi