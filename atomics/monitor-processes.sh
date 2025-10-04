#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: monitor-processes.sh
# Description: Surveille les processus système avec alertes et statistiques
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-04
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="monitor-processes.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
CONTINUOUS=${CONTINUOUS:-0}
INTERVAL=${INTERVAL:-5}
MAX_ITERATIONS=${MAX_ITERATIONS:-0}  # 0 = infini
CPU_THRESHOLD=${CPU_THRESHOLD:-80}
MEMORY_THRESHOLD=${MEMORY_THRESHOLD:-80}
FILTER_PATTERN=""
SORT_BY="cpu"  # cpu|memory|pid|name

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
    Surveille les processus système avec collecte de statistiques détaillées,
    alertes sur seuils et filtrage avancé.

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)
    -c, --continuous       Mode continu (surveillance continue)
    -i, --interval SECS    Intervalle entre les mesures (défaut: 5)
    -n, --max-iter NUM     Nombre maximum d'itérations (0=infini)
    --cpu-threshold NUM    Seuil d'alerte CPU en % (défaut: 80)
    --memory-threshold NUM Seuil d'alerte mémoire en % (défaut: 80)
    -f, --filter PATTERN   Filtrer les processus par nom/commande
    -s, --sort-by FIELD    Trier par: cpu|memory|pid|name (défaut: cpu)
    
Sortie JSON:
    {
      "status": "success|error",
      "code": 0,
      "timestamp": "ISO8601",
      "script": "$SCRIPT_NAME",
      "message": "Description",
      "data": {
        "monitoring_config": {
          "interval": 5,
          "continuous": true,
          "cpu_threshold": 80,
          "memory_threshold": 80,
          "filter": "apache",
          "sort_by": "cpu"
        },
        "system_stats": {
          "total_processes": 156,
          "cpu_usage_percent": 15.2,
          "memory_usage_percent": 65.8,
          "load_average": [0.5, 0.3, 0.2],
          "uptime_seconds": 86400
        },
        "top_processes": [
          {
            "pid": 1234,
            "name": "apache2",
            "command": "/usr/sbin/apache2 -DFOREGROUND",
            "user": "www-data",
            "cpu_percent": 25.3,
            "memory_percent": 12.1,
            "memory_mb": 145,
            "status": "S",
            "priority": 20,
            "threads": 8,
            "start_time": "10:30",
            "cpu_time": "00:05:23"
          }
        ],
        "alerts": [
          {
            "type": "cpu_high",
            "process": "apache2",
            "pid": 1234,
            "value": 85.2,
            "threshold": 80,
            "message": "High CPU usage detected"
          }
        ],
        "iteration": 1,
        "monitoring_duration": 5.2
      },
      "errors": [],
      "warnings": []
    }

Codes de sortie:
    0 - Succès
    1 - Erreur générale
    2 - Erreur de paramètres
    3 - Outils de monitoring manquants
    4 - Permissions insuffisantes

Exemples:
    $SCRIPT_NAME                                   # Snapshot unique
    $SCRIPT_NAME -c -i 10                        # Surveillance continue (10s)
    $SCRIPT_NAME -f apache --cpu-threshold 90    # Filtrer apache, seuil 90%
    $SCRIPT_NAME --sort-by memory -n 5           # 5 mesures triées par mémoire
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
            -c|--continuous)
                CONTINUOUS=1
                shift
                ;;
            -i|--interval)
                if [[ -n "${2:-}" && "$2" =~ ^[0-9]+$ ]]; then
                    INTERVAL="$2"
                    shift 2
                else
                    die "Intervalle invalide: ${2:-}. Doit être un nombre entier." 2
                fi
                ;;
            -n|--max-iter)
                if [[ -n "${2:-}" && "$2" =~ ^[0-9]+$ ]]; then
                    MAX_ITERATIONS="$2"
                    shift 2
                else
                    die "Nombre d'itérations invalide: ${2:-}. Doit être un nombre entier." 2
                fi
                ;;
            --cpu-threshold)
                if [[ -n "${2:-}" && "$2" =~ ^[0-9]+$ ]]; then
                    CPU_THRESHOLD="$2"
                    shift 2
                else
                    die "Seuil CPU invalide: ${2:-}. Doit être un nombre entre 0-100." 2
                fi
                ;;
            --memory-threshold)
                if [[ -n "${2:-}" && "$2" =~ ^[0-9]+$ ]]; then
                    MEMORY_THRESHOLD="$2"
                    shift 2
                else
                    die "Seuil mémoire invalide: ${2:-}. Doit être un nombre entre 0-100." 2
                fi
                ;;
            -f|--filter)
                if [[ -n "${2:-}" ]]; then
                    FILTER_PATTERN="$2"
                    shift 2
                else
                    die "Pattern de filtre manquant pour -f/--filter" 2
                fi
                ;;
            -s|--sort-by)
                if [[ -n "${2:-}" ]]; then
                    case "$2" in
                        cpu|memory|pid|name)
                            SORT_BY="$2"
                            shift 2
                            ;;
                        *)
                            die "Critère de tri invalide: $2. Utilisez: cpu|memory|pid|name" 2
                            ;;
                    esac
                else
                    die "Critère de tri manquant pour -s/--sort-by" 2
                fi
                ;;
            -*)
                die "Option inconnue: $1. Utilisez -h pour l'aide." 2
                ;;
            *)
                die "Argument inattendu: $1. Utilisez -h pour l'aide." 2
                ;;
        esac
    done

    # Validation des seuils
    if [[ $CPU_THRESHOLD -lt 0 || $CPU_THRESHOLD -gt 100 ]]; then
        die "Seuil CPU invalide: $CPU_THRESHOLD. Doit être entre 0-100." 2
    fi
    
    if [[ $MEMORY_THRESHOLD -lt 0 || $MEMORY_THRESHOLD -gt 100 ]]; then
        die "Seuil mémoire invalide: $MEMORY_THRESHOLD. Doit être entre 0-100." 2
    fi
    
    if [[ $INTERVAL -lt 1 ]]; then
        die "Intervalle invalide: $INTERVAL. Doit être >= 1 seconde." 2
    fi
}

# =============================================================================
# Fonctions Métier
# =============================================================================

check_dependencies() {
    local missing=()
    
    if ! command -v ps >/dev/null 2>&1; then
        missing+=("ps")
    fi
    
    if ! command -v grep >/dev/null 2>&1; then
        missing+=("grep")
    fi
    
    if ! command -v awk >/dev/null 2>&1; then
        missing+=("awk")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Commandes manquantes: ${missing[*]}" 3
    fi
    
    log_debug "Dépendances vérifiées avec succès"
}

get_system_stats() {
    local total_processes cpu_usage memory_usage uptime_seconds
    
    # Nombre total de processus
    total_processes=$(ps aux --no-headers 2>/dev/null | wc -l || echo "0")
    
    # Utilisation CPU globale (approximative via load average)
    if [[ -r /proc/loadavg ]]; then
        local load_1min
        load_1min=$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo "0")
        local num_cpus
        num_cpus=$(nproc 2>/dev/null || echo "1")
        cpu_usage=$(echo "scale=1; $load_1min * 100 / $num_cpus" | bc 2>/dev/null || echo "0")
        # Limiter à 100%
        if (( $(echo "$cpu_usage > 100" | bc -l 2>/dev/null || echo "0") )); then
            cpu_usage="100.0"
        fi
    else
        cpu_usage="0"
    fi
    
    # Utilisation mémoire globale
    if [[ -r /proc/meminfo ]]; then
        local mem_total mem_available mem_used
        mem_total=$(grep "^MemTotal:" /proc/meminfo | awk '{print $2}' || echo "1")
        mem_available=$(grep "^MemAvailable:" /proc/meminfo | awk '{print $2}' 2>/dev/null || \
                       grep "^MemFree:" /proc/meminfo | awk '{print $2}' || echo "$mem_total")
        mem_used=$((mem_total - mem_available))
        memory_usage=$(echo "scale=1; $mem_used * 100 / $mem_total" | bc 2>/dev/null || echo "0")
    else
        memory_usage="0"
    fi
    
    # Uptime du système
    if [[ -r /proc/uptime ]]; then
        uptime_seconds=$(awk '{print int($1)}' /proc/uptime 2>/dev/null || echo "0")
    else
        uptime_seconds="0"
    fi
    
    # Load averages
    local load_avg="[0,0,0]"
    if [[ -r /proc/loadavg ]]; then
        local load1 load5 load15
        read -r load1 load5 load15 _ < /proc/loadavg 2>/dev/null || load1="0" load5="0" load15="0"
        load_avg="[$load1,$load5,$load15]"
    fi
    
    echo "$total_processes|$cpu_usage|$memory_usage|$load_avg|$uptime_seconds"
}

get_process_info() {
    local filter_pattern="$1"
    local sort_field="$2"
    
    # Colonnes PS : PID PPID %CPU %MEM RSS VSZ STAT PRI USER COMMAND
    local ps_format="pid,ppid,pcpu,pmem,rss,vsz,stat,pri,user,comm"
    local ps_cmd="ps axo $ps_format --no-headers"
    
    if [[ -n "$filter_pattern" ]]; then
        ps_cmd+=" | grep -i \"$filter_pattern\""
    fi
    
    # Trier selon le critère demandé
    case "$sort_field" in
        cpu)
            ps_cmd+=" | sort -k3 -nr"  # Colonne %CPU
            ;;
        memory)
            ps_cmd+=" | sort -k4 -nr"  # Colonne %MEM
            ;;
        pid)
            ps_cmd+=" | sort -k1 -n"   # Colonne PID
            ;;
        name)
            ps_cmd+=" | sort -k10"     # Colonne COMM
            ;;
    esac
    
    # Limiter aux 20 premiers processus
    ps_cmd+=" | head -20"
    
    log_debug "Commande PS: $ps_cmd"
    
    # Exécuter et retourner le résultat
    eval "$ps_cmd" 2>/dev/null || echo ""
}

get_process_details() {
    local pid="$1"
    
    local threads="0" start_time="" cpu_time="" command=""
    
    # Nombre de threads
    if [[ -r "/proc/$pid/status" ]]; then
        threads=$(grep "^Threads:" "/proc/$pid/status" 2>/dev/null | awk '{print $2}' || echo "0")
    fi
    
    # Heure de démarrage (format HH:MM)
    if command -v ps >/dev/null 2>&1; then
        start_time=$(ps -p "$pid" -o lstart --no-headers 2>/dev/null | awk '{print $4}' | cut -d: -f1-2 || echo "")
    fi
    
    # Temps CPU cumulé
    if command -v ps >/dev/null 2>&1; then
        cpu_time=$(ps -p "$pid" -o time --no-headers 2>/dev/null | tr -d ' ' || echo "00:00:00")
    fi
    
    # Commande complète
    if [[ -r "/proc/$pid/cmdline" ]]; then
        command=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | head -c 100 || echo "")
        # Si cmdline est vide, utiliser comm
        if [[ -z "$command" && -r "/proc/$pid/comm" ]]; then
            command=$(cat "/proc/$pid/comm" 2>/dev/null || echo "")
        fi
    fi
    
    echo "$threads|$start_time|$cpu_time|$command"
}

check_alerts() {
    local processes_data="$1"
    local alerts=()
    
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        
        local pid ppid cpu_percent mem_percent rss vsz stat pri user comm
        read -r pid ppid cpu_percent mem_percent rss vsz stat pri user comm <<< "$line"
        
        # Vérifier seuil CPU
        if (( $(echo "$cpu_percent >= $CPU_THRESHOLD" | bc -l 2>/dev/null || echo "0") )); then
            local alert="{\"type\":\"cpu_high\",\"process\":\"$comm\",\"pid\":$pid,\"value\":$cpu_percent,\"threshold\":$CPU_THRESHOLD,\"message\":\"High CPU usage detected\"}"
            alerts+=("$alert")
        fi
        
        # Vérifier seuil mémoire
        if (( $(echo "$mem_percent >= $MEMORY_THRESHOLD" | bc -l 2>/dev/null || echo "0") )); then
            local alert="{\"type\":\"memory_high\",\"process\":\"$comm\",\"pid\":$pid,\"value\":$mem_percent,\"threshold\":$MEMORY_THRESHOLD,\"message\":\"High memory usage detected\"}"
            alerts+=("$alert")
        fi
    done <<< "$processes_data"
    
    # Retourner les alertes au format JSON
    if [[ ${#alerts[@]} -gt 0 ]]; then
        local alerts_str
        alerts_str=$(IFS=','; echo "${alerts[*]}")
        echo "[$alerts_str]"
    else
        echo "[]"
    fi
}

build_processes_json() {
    local processes_data="$1"
    local processes_json="[]"
    
    if [[ -n "$processes_data" ]]; then
        local processes_list=""
        
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            
            local pid ppid cpu_percent mem_percent rss vsz stat pri user comm
            read -r pid ppid cpu_percent mem_percent rss vsz stat pri user comm <<< "$line"
            
            # Obtenir les détails supplémentaires
            local details threads start_time cpu_time command
            details=$(get_process_details "$pid")
            IFS='|' read -r threads start_time cpu_time command <<< "$details"
            
            # Calculer la mémoire en MB
            local memory_mb
            memory_mb=$(echo "scale=1; ${rss:-0} / 1024" | bc 2>/dev/null || echo "0")
            
            # Échapper les chaînes pour JSON
            comm=$(echo "$comm" | sed 's/\\/\\\\/g; s/"/\\"/g')
            command=$(echo "$command" | sed 's/\\/\\\\/g; s/"/\\"/g')
            user=$(echo "$user" | sed 's/\\/\\\\/g; s/"/\\"/g')
            
            # Nettoyer les valeurs numériques
            [[ -z "$cpu_percent" ]] && cpu_percent="0"
            [[ -z "$mem_percent" ]] && mem_percent="0"
            [[ -z "$threads" ]] && threads="0"
            [[ -z "$pri" ]] && pri="0"
            [[ -z "$start_time" ]] && start_time=""
            [[ -z "$cpu_time" ]] && cpu_time="00:00:00"
            
            # Construire l'objet JSON du processus
            local process_json
            process_json="{\"pid\":$pid,\"name\":\"$comm\",\"command\":\"$command\",\"user\":\"$user\",\"cpu_percent\":$cpu_percent,\"memory_percent\":$mem_percent,\"memory_mb\":$memory_mb,\"status\":\"$stat\",\"priority\":$pri,\"threads\":$threads,\"start_time\":\"$start_time\",\"cpu_time\":\"$cpu_time\"}"
            
            processes_list+="$process_json,"
        done <<< "$processes_data"
        
        # Supprimer la virgule finale et construire le tableau
        processes_list=${processes_list%,}
        [[ -n "$processes_list" ]] && processes_json="[$processes_list]"
    fi
    
    echo "$processes_json"
}

monitor_processes() {
    local iteration=1
    local start_time
    start_time=$(date +%s.%N 2>/dev/null || date +%s)
    
    log_debug "Début du monitoring (itération $iteration)"
    
    # Collecter les statistiques système
    local system_stats_raw system_stats
    system_stats_raw=$(get_system_stats)
    IFS='|' read -r total_processes cpu_usage memory_usage load_avg uptime_seconds <<< "$system_stats_raw"
    
    # Collecter les informations des processus
    local processes_data
    processes_data=$(get_process_info "$FILTER_PATTERN" "$SORT_BY")
    
    # Construire le JSON des processus
    local processes_json
    processes_json=$(build_processes_json "$processes_data")
    
    # Vérifier les alertes
    local alerts_json
    alerts_json=$(check_alerts "$processes_data")
    
    # Calculer la durée de monitoring
    local end_time duration
    end_time=$(date +%s.%N 2>/dev/null || date +%s)
    duration=$(echo "scale=1; $end_time - $start_time" | bc 2>/dev/null || echo "0")
    
    # Échapper le pattern de filtre pour JSON
    local filter_escaped
    filter_escaped=$(echo "$FILTER_PATTERN" | sed 's/\\/\\\\/g; s/"/\\"/g')
    
    # Générer la réponse JSON
    cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Process monitoring completed successfully",
  "data": {
    "monitoring_config": {
      "interval": $INTERVAL,
      "continuous": $([ $CONTINUOUS -eq 1 ] && echo "true" || echo "false"),
      "cpu_threshold": $CPU_THRESHOLD,
      "memory_threshold": $MEMORY_THRESHOLD,
      "filter": "$filter_escaped",
      "sort_by": "$SORT_BY",
      "max_iterations": $MAX_ITERATIONS
    },
    "system_stats": {
      "total_processes": $total_processes,
      "cpu_usage_percent": $cpu_usage,
      "memory_usage_percent": $memory_usage,
      "load_average": $load_avg,
      "uptime_seconds": $uptime_seconds
    },
    "top_processes": $processes_json,
    "alerts": $alerts_json,
    "iteration": $iteration,
    "monitoring_duration": $duration
  },
  "errors": [],
  "warnings": []
}
EOF
    
    log_debug "Monitoring terminé (durée: ${duration}s)"
}

monitor_continuous() {
    local iteration=1
    
    log_info "Démarrage du monitoring continu (intervalle: ${INTERVAL}s)"
    
    while true; do
        local start_time
        start_time=$(date +%s)
        
        # Afficher le numéro d'itération si verbose
        [[ $VERBOSE -eq 1 ]] && log_info "Itération $iteration"
        
        # Exécuter le monitoring (en modifiant temporairement l'iteration dans la fonction)
        CURRENT_ITERATION=$iteration monitor_processes_iteration
        
        # Incrémenter le compteur
        ((iteration++))
        
        # Vérifier la limite d'itérations
        if [[ $MAX_ITERATIONS -gt 0 && $iteration -gt $MAX_ITERATIONS ]]; then
            log_info "Limite d'itérations atteinte: $MAX_ITERATIONS"
            break
        fi
        
        # Calculer le temps d'attente
        local end_time elapsed_time sleep_time
        end_time=$(date +%s)
        elapsed_time=$((end_time - start_time))
        sleep_time=$((INTERVAL - elapsed_time))
        
        # Attendre si nécessaire
        if [[ $sleep_time -gt 0 ]]; then
            log_debug "Attente de ${sleep_time}s avant la prochaine itération"
            sleep "$sleep_time"
        fi
    done
}

monitor_processes_iteration() {
    # Version modifiée pour le mode continu
    local iteration=${CURRENT_ITERATION:-1}
    local start_time
    start_time=$(date +%s.%N 2>/dev/null || date +%s)
    
    # Collecter les données (même logique que monitor_processes)
    local system_stats_raw system_stats
    system_stats_raw=$(get_system_stats)
    IFS='|' read -r total_processes cpu_usage memory_usage load_avg uptime_seconds <<< "$system_stats_raw"
    
    local processes_data
    processes_data=$(get_process_info "$FILTER_PATTERN" "$SORT_BY")
    
    local processes_json
    processes_json=$(build_processes_json "$processes_data")
    
    local alerts_json
    alerts_json=$(check_alerts "$processes_data")
    
    local end_time duration
    end_time=$(date +%s.%N 2>/dev/null || date +%s)
    duration=$(echo "scale=1; $end_time - $start_time" | bc 2>/dev/null || echo "0")
    
    local filter_escaped
    filter_escaped=$(echo "$FILTER_PATTERN" | sed 's/\\/\\\\/g; s/"/\\"/g')
    
    # Sortir le JSON pour cette itération
    cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Process monitoring iteration $iteration completed",
  "data": {
    "monitoring_config": {
      "interval": $INTERVAL,
      "continuous": true,
      "cpu_threshold": $CPU_THRESHOLD,
      "memory_threshold": $MEMORY_THRESHOLD,
      "filter": "$filter_escaped",
      "sort_by": "$SORT_BY",
      "max_iterations": $MAX_ITERATIONS
    },
    "system_stats": {
      "total_processes": $total_processes,
      "cpu_usage_percent": $cpu_usage,
      "memory_usage_percent": $memory_usage,
      "load_average": $load_avg,
      "uptime_seconds": $uptime_seconds
    },
    "top_processes": $processes_json,
    "alerts": $alerts_json,
    "iteration": $iteration,
    "monitoring_duration": $duration
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
    
    # Gestion des signaux pour le mode continu
    if [[ $CONTINUOUS -eq 1 ]]; then
        trap 'log_info "Monitoring interrompu par signal"; exit 0' INT TERM
        monitor_continuous
    else
        monitor_processes
    fi
    
    log_info "Script completed successfully"
}

# =============================================================================
# Point d'Entrée
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi