#!/usr/bin/env bash

# ===================================================================
# Script: get-cpu.top.processes.sh
# Description: Liste les processus consommant le plus de CPU
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
TOP_COUNT=10
SORT_BY="cpu"
SHOW_THREADS=false
INTERVAL=1

# === FONCTIONS ===

#################################################################
# Affiche l'aide du script
# Arguments: Aucun
# Retour: 0
#################################################################
show_help() {
    cat << 'EOF'
get-cpu.top.processes.sh - Liste les processus consommant le plus de CPU

SYNOPSIS:
    get-cpu.top.processes.sh [OPTIONS]

DESCRIPTION:
    Ce script identifie les processus avec la plus haute consommation CPU :
    - Top N processus par utilisation CPU
    - Informations détaillées (PID, utilisateur, commande)
    - Support du tri par différents critères
    - Possibilité d'inclure les threads
    
DÉPENDANCES:
    - ps (procps)
    - top [optionnel pour validation]
    
OPTIONS:
    -f, --format FORMAT      Format de sortie (json|text|csv) [défaut: json]
    -n, --count COUNT        Nombre de processus à afficher [défaut: 10]
    -s, --sort-by FIELD      Tri par (cpu|memory|time) [défaut: cpu]
    -t, --threads            Inclure les threads individuels
    -i, --interval SECONDS   Intervalle d'observation [défaut: 1]
    -v, --verbose            Mode verbeux
    -q, --quiet              Mode silencieux
    -h, --help               Affiche cette aide

SORTIE:
    JSON avec les processus triés par consommation CPU

EXEMPLES:
    # Top 10 processus CPU
    ./get-cpu.top.processes.sh
    
    # Top 5 en format texte
    ./get-cpu.top.processes.sh -n 5 --format text
    
    # Inclure les threads, tri par mémoire
    ./get-cpu.top.processes.sh --threads --sort-by memory
    
    # Observation sur 5 secondes
    ./get-cpu.top.processes.sh --interval 5

CODES DE RETOUR:
    0    Succès
    1    Erreur générale
    2    Dépendance manquante
    3    Erreur de collecte des processus
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
            -n|--count)
                if [[ -z "${2:-}" ]] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
                    atomic_error "Nombre valide requis pour l'option --count"
                    return 1
                fi
                TOP_COUNT="$2"
                shift 2
                ;;
            -s|--sort-by)
                if [[ -z "${2:-}" ]]; then
                    atomic_error "Critère de tri requis pour l'option --sort-by"
                    return 1
                fi
                case "$2" in
                    cpu|memory|time)
                        SORT_BY="$2"
                        ;;
                    *)
                        atomic_error "Critère de tri invalide: $2 (cpu|memory|time)"
                        return 1
                        ;;
                esac
                shift 2
                ;;
            -t|--threads)
                SHOW_THREADS=true
                shift
                ;;
            -i|--interval)
                if [[ -z "${2:-}" ]] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
                    atomic_error "Intervalle valide requis pour l'option --interval"
                    return 1
                fi
                INTERVAL="$2"
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
    
    if ! command -v ps >/dev/null 2>&1; then
        missing_deps+=("ps")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        atomic_error "Dépendances manquantes: ${missing_deps[*]}"
        atomic_info "Installation suggérée: apt install procps"
        return 2
    fi
    
    return 0
}

#################################################################
# Collecte les processus avec ps
# Arguments: Aucun
# Retour: 0 si succès, 3 sinon
#################################################################
collect_processes() {
    local ps_options="aux"
    local sort_field
    
    # Options ps selon les paramètres
    if $SHOW_THREADS; then
        ps_options="auxH"  # H pour les threads
    fi
    
    # Détermination du champ de tri pour ps
    case "$SORT_BY" in
        cpu)
            sort_field="pcpu"
            ;;
        memory)
            sort_field="pmem"
            ;;
        time)
            sort_field="time"
            ;;
        *)
            sort_field="pcpu"
            ;;
    esac
    
    if $VERBOSE; then
        atomic_info "Collecte des processus (intervalle: ${INTERVAL}s, tri: $SORT_BY)"
    fi
    
    # Attendre un intervalle pour avoir des statistiques CPU précises
    if [[ $INTERVAL -gt 0 ]]; then
        sleep "$INTERVAL"
    fi
    
    # Collecte avec ps
    if ! PS_OUTPUT=$(ps "$ps_options" --sort="-$sort_field" 2>/dev/null); then
        atomic_error "Erreur lors de l'exécution de ps"
        return 3
    fi
    
    return 0
}

#################################################################
# Parse la sortie ps et extrait les informations
# Arguments: Aucun
# Retour: 0 si succès, 3 sinon
#################################################################
parse_processes() {
    PROCESSES_ARRAY=()
    local line_count=0
    
    # Skip de la première ligne (headers)
    local first_line=true
    
    while IFS= read -r line; do
        if $first_line; then
            first_line=false
            continue
        fi
        
        # Parse de la ligne ps
        # Format: USER PID %CPU %MEM VSZ RSS TTY STAT START TIME COMMAND
        local fields
        read -ra fields <<< "$line"
        
        if [[ ${#fields[@]} -lt 11 ]]; then
            continue
        fi
        
        local user="${fields[0]}"
        local pid="${fields[1]}"
        local cpu_percent="${fields[2]}"
        local mem_percent="${fields[3]}"
        local vsz="${fields[4]}"
        local rss="${fields[5]}"
        local tty="${fields[6]}"
        local stat="${fields[7]}"
        local start="${fields[8]}"
        local time="${fields[9]}"
        
        # Reconstruction de la commande (peut contenir des espaces)
        local command=""
        for ((i=10; i<${#fields[@]}; i++)); do
            if [[ -n "$command" ]]; then
                command="$command ${fields[i]}"
            else
                command="${fields[i]}"
            fi
        done
        
        # Filtrage des processus avec CPU > 0 ou selon le critère de tri
        local include_process=false
        case "$SORT_BY" in
            cpu)
                if (( $(echo "$cpu_percent > 0" | bc -l 2>/dev/null || echo "0") )); then
                    include_process=true
                fi
                ;;
            memory)
                if (( $(echo "$mem_percent > 0" | bc -l 2>/dev/null || echo "0") )); then
                    include_process=true
                fi
                ;;
            time)
                if [[ "$time" != "00:00" && "$time" != "0:00" ]]; then
                    include_process=true
                fi
                ;;
        esac
        
        if $include_process; then
            # Stockage des données du processus
            local process_data="$user|$pid|$cpu_percent|$mem_percent|$vsz|$rss|$tty|$stat|$start|$time|$command"
            PROCESSES_ARRAY+=("$process_data")
            
            ((line_count++))
            
            # Arrêt si on a assez de processus
            if [[ $line_count -ge $TOP_COUNT ]]; then
                break
            fi
        fi
    done <<< "$PS_OUTPUT"
    
    if [[ ${#PROCESSES_ARRAY[@]} -eq 0 ]]; then
        atomic_warn "Aucun processus trouvé avec les critères spécifiés"
        return 3
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
            echo "  \"criteria\": {"
            echo "    \"sort_by\": \"$SORT_BY\","
            echo "    \"count\": $TOP_COUNT,"
            echo "    \"include_threads\": $SHOW_THREADS,"
            echo "    \"interval_seconds\": $INTERVAL"
            echo "  },"
            echo "  \"processes\": ["
            
            local first=true
            for process_data in "${PROCESSES_ARRAY[@]}"; do
                IFS='|' read -r user pid cpu_percent mem_percent vsz rss tty stat start time command <<< "$process_data"
                
                if $first; then
                    first=false
                else
                    echo ","
                fi
                
                echo "    {"
                echo "      \"user\": \"$user\","
                echo "      \"pid\": $pid,"
                echo "      \"cpu_percent\": $cpu_percent,"
                echo "      \"memory_percent\": $mem_percent,"
                echo "      \"vsz_kb\": $vsz,"
                echo "      \"rss_kb\": $rss,"
                echo "      \"tty\": \"$tty\","
                echo "      \"status\": \"$stat\","
                echo "      \"start_time\": \"$start\","
                echo "      \"cpu_time\": \"$time\","
                echo "      \"command\": \"$(echo "$command" | sed 's/"/\\"/g')\""
                echo -n "    }"
            done
            
            echo ""
            echo "  ]"
            echo "}"
            ;;
        text)
            echo "=== Top $TOP_COUNT processus (tri: $SORT_BY) ==="
            printf "%-10s %-8s %-6s %-6s %-10s %-8s %-s\n" "USER" "PID" "%CPU" "%MEM" "RSS(KB)" "TIME" "COMMAND"
            echo "--------------------------------------------------------------------------------------------------------"
            
            for process_data in "${PROCESSES_ARRAY[@]}"; do
                IFS='|' read -r user pid cpu_percent mem_percent vsz rss tty stat start time command <<< "$process_data"
                
                # Troncature de la commande si trop longue
                local cmd_display="$command"
                if [[ ${#cmd_display} -gt 50 ]]; then
                    cmd_display="${cmd_display:0:47}..."
                fi
                
                printf "%-10s %-8s %-6s %-6s %-10s %-8s %-s\n" \
                    "$user" "$pid" "$cpu_percent" "$mem_percent" "$rss" "$time" "$cmd_display"
            done
            ;;
        csv)
            echo "timestamp,user,pid,cpu_percent,memory_percent,vsz_kb,rss_kb,tty,status,start_time,cpu_time,command"
            
            for process_data in "${PROCESSES_ARRAY[@]}"; do
                IFS='|' read -r user pid cpu_percent mem_percent vsz rss tty stat start time command <<< "$process_data"
                
                # Échappement des guillemets dans la commande
                command=$(echo "$command" | sed 's/"/\\"/g')
                
                echo "$(date -Iseconds),$user,$pid,$cpu_percent,$mem_percent,$vsz,$rss,$tty,$stat,$start,$time,\"$command\""
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
    
    # Vérification de bc pour les comparaisons numériques
    if ! command -v bc >/dev/null 2>&1; then
        atomic_warn "bc non trouvé, certaines comparaisons pourraient échouer"
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
        atomic_info "Top $TOP_COUNT processus, tri par $SORT_BY"
        if $SHOW_THREADS; then
            atomic_info "Inclusion des threads individuels"
        fi
    fi
    
    # Vérification des dépendances
    if ! check_dependencies; then
        return 2
    fi
    
    # Collecte des processus
    if ! collect_processes; then
        return 3
    fi
    
    # Parse et traitement
    if ! parse_processes; then
        return 3
    fi
    
    # Affichage des résultats
    if ! output_results; then
        return 1
    fi
    
    if $VERBOSE; then
        atomic_success "Collecte des processus CPU terminée (${#PROCESSES_ARRAY[@]} processus)"
    fi
    
    return 0
}

# === EXÉCUTION ===
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi