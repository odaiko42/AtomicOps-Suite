#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: set-cpu.governor.sh 
# Description: Configurer le gouverneur de fréquence CPU
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-04
# ==============================================================================

set -euo pipefail

SCRIPT_NAME="set-cpu.governor.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
GOVERNOR=""
CPU_ID=${CPU_ID:-"all"}
PERSISTENT=${PERSISTENT:-0}

show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] <governor>

Description:
    Configure le gouverneur de fréquence CPU pour optimiser
    les performances ou la consommation énergétique.

Arguments:
    <governor>       Gouverneur CPU (performance|powersave|ondemand|conservative|userspace|schedutil)

Options:
    -h, --help       Afficher cette aide
    -v, --verbose    Mode verbeux
    -d, --debug      Mode debug
    -q, --quiet      Mode silencieux
    -j, --json-only  Sortie JSON uniquement
    -c, --cpu ID     CPU spécifique (défaut: all)
    -p, --persistent Rendre persistant au redémarrage
    
Exemples:
    $SCRIPT_NAME performance
    $SCRIPT_NAME -c 0 powersave
    $SCRIPT_NAME -p ondemand
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help) show_help; exit 0 ;;
            -v|--verbose) VERBOSE=1; shift ;;
            -d|--debug) DEBUG=1; VERBOSE=1; shift ;;
            -q|--quiet) QUIET=1; shift ;;
            -j|--json-only) JSON_ONLY=1; QUIET=1; shift ;;
            -c|--cpu) CPU_ID="$2"; shift 2 ;;
            -p|--persistent) PERSISTENT=1; shift ;;
            -*) echo "Option inconnue: $1" >&2; exit 2 ;;
            *) 
                [[ -z "$GOVERNOR" ]] && GOVERNOR="$1" || { echo "Trop d'arguments" >&2; exit 2; }
                shift ;;
        esac
    done

    [[ -z "$GOVERNOR" ]] && { echo "Gouverneur manquant" >&2; exit 2; }
}

get_cpu_count() {
    nproc 2>/dev/null || echo "1"
}

get_available_governors() {
    local cpu="${1:-0}"
    local gov_file="/sys/devices/system/cpu/cpu${cpu}/cpufreq/scaling_available_governors"
    
    if [[ -f "$gov_file" ]]; then
        cat "$gov_file" 2>/dev/null | tr ' ' '\n' | grep -v '^$'
    else
        echo ""
    fi
}

get_current_governor() {
    local cpu="${1:-0}"
    local gov_file="/sys/devices/system/cpu/cpu${cpu}/cpufreq/scaling_governor"
    
    if [[ -f "$gov_file" ]]; then
        cat "$gov_file" 2>/dev/null || echo "unknown"
    else
        echo "unavailable"
    fi
}

validate_governor() {
    local governor="$1" cpu="${2:-0}"
    local available_governors
    
    readarray -t available_governors < <(get_available_governors "$cpu")
    
    for available in "${available_governors[@]}"; do
        [[ "$available" == "$governor" ]] && return 0
    done
    return 1
}

set_cpu_governor() {
    local governor="$1" cpu="$2"
    local gov_file="/sys/devices/system/cpu/cpu${cpu}/cpufreq/scaling_governor"
    
    if [[ -w "$gov_file" ]]; then
        echo "$governor" > "$gov_file" 2>/dev/null
    else
        return 1
    fi
}

get_cpu_frequencies() {
    local cpu="${1:-0}"
    local min_freq max_freq cur_freq
    
    min_freq=$(cat "/sys/devices/system/cpu/cpu${cpu}/cpufreq/cpuinfo_min_freq" 2>/dev/null || echo "0")
    max_freq=$(cat "/sys/devices/system/cpu/cpu${cpu}/cpufreq/cpuinfo_max_freq" 2>/dev/null || echo "0")
    cur_freq=$(cat "/sys/devices/system/cpu/cpu${cpu}/cpufreq/scaling_cur_freq" 2>/dev/null || echo "0")
    
    echo "$min_freq:$max_freq:$cur_freq"
}

make_governor_persistent() {
    local governor="$1"
    local service_file="/etc/systemd/system/cpu-governor.service"
    
    cat > "$service_file" << EOF
[Unit]
Description=Set CPU Governor
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo $governor > /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload 2>/dev/null
    systemctl enable cpu-governor.service 2>/dev/null
}

check_cpufreq_support() {
    [[ -d /sys/devices/system/cpu/cpu0/cpufreq ]]
}

main() {
    parse_args "$@"
    
    local errors=() warnings=()
    local cpu_count results=()
    
    # Vérifier le support cpufreq
    if ! check_cpufreq_support; then
        errors+=("CPU frequency scaling not supported or not enabled")
    fi
    
    # Vérifier les permissions
    if [[ $EUID -ne 0 ]]; then
        errors+=("Root privileges required to change CPU governor")
    fi
    
    if [[ ${#errors[@]} -eq 0 ]]; then
        cpu_count=$(get_cpu_count)
        
        # Déterminer les CPUs à modifier
        local cpu_list=()
        if [[ "$CPU_ID" == "all" ]]; then
            for ((i=0; i<cpu_count; i++)); do
                cpu_list+=("$i")
            done
        else
            if [[ "$CPU_ID" =~ ^[0-9]+$ ]] && [[ $CPU_ID -lt $cpu_count ]]; then
                cpu_list=("$CPU_ID")
            else
                errors+=("Invalid CPU ID: $CPU_ID (available: 0-$((cpu_count-1)))")
            fi
        fi
        
        # Valider le gouverneur pour le premier CPU
        if [[ ${#errors[@]} -eq 0 ]] && [[ ${#cpu_list[@]} -gt 0 ]]; then
            if ! validate_governor "$GOVERNOR" "${cpu_list[0]}"; then
                local available
                available=$(get_available_governors "${cpu_list[0]}" | tr '\n' ',' | sed 's/,$//')
                errors+=("Governor '$GOVERNOR' not available. Available: $available")
            fi
        fi
        
        if [[ ${#errors[@]} -eq 0 ]]; then
            local start_time end_time duration
            start_time=$(date +%s)
            
            # Appliquer le gouverneur à chaque CPU
            for cpu in "${cpu_list[@]}"; do
                local previous_governor current_governor freq_info
                previous_governor=$(get_current_governor "$cpu")
                
                if set_cpu_governor "$GOVERNOR" "$cpu"; then
                    current_governor=$(get_current_governor "$cpu")
                    freq_info=$(get_cpu_frequencies "$cpu")
                    IFS=':' read -r min_freq max_freq cur_freq <<< "$freq_info"
                    
                    results+=("{\"cpu\":$cpu,\"previous_governor\":\"$previous_governor\",\"current_governor\":\"$current_governor\",\"min_freq_khz\":$min_freq,\"max_freq_khz\":$max_freq,\"current_freq_khz\":$cur_freq,\"success\":true}")
                else
                    results+=("{\"cpu\":$cpu,\"previous_governor\":\"$previous_governor\",\"current_governor\":\"$previous_governor\",\"success\":false}")
                    warnings+=("Failed to set governor for CPU $cpu")
                fi
            done
            
            # Rendre persistant si demandé
            local persistence_configured=false
            if [[ $PERSISTENT -eq 1 ]]; then
                if make_governor_persistent "$GOVERNOR" 2>/dev/null; then
                    persistence_configured=true
                else
                    warnings+=("Failed to configure persistence")
                fi
            fi
            
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            
            # Compter les succès
            local successful_cpus=0
            for result in "${results[@]}"; do
                if echo "$result" | grep -q '"success":true'; then
                    successful_cpus=$((successful_cpus + 1))
                fi
            done
            
            cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "CPU governor configuration completed",
  "data": {
    "governor": "$GOVERNOR",
    "target_cpus": "$CPU_ID",
    "total_cpus": $cpu_count,
    "cpus_modified": ${#cpu_list[@]},
    "successful_changes": $successful_cpus,
    "made_persistent": $persistence_configured,
    "duration_seconds": $duration,
    "cpu_results": [$(IFS=','; echo "${results[*]}")]
  },
  "errors": [],
  "warnings": [$(printf '"%s",' "${warnings[@]}" | sed 's/,$//')"]
}
EOF
        fi
    fi
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        cat << EOF
{
  "status": "error",
  "code": 1,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "CPU governor configuration failed",
  "data": {},
  "errors": [$(printf '"%s",' "${errors[@]}" | sed 's/,$//')],
  "warnings": [$(printf '"%s",' "${warnings[@]}" | sed 's/,$//')"]
}
EOF
        exit 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi