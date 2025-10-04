#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: set-config.kernel.parameter.sh 
# Description: Configurer des paramètres kernel via sysctl
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-04
# ==============================================================================

set -euo pipefail

SCRIPT_NAME="set-config.kernel.parameter.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
PARAMETER=""
VALUE=""
PERSISTENT=${PERSISTENT:-1}
BACKUP=${BACKUP:-1}
FORCE=${FORCE:-0}

show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] <parameter> <value>

Description:
    Configure les paramètres kernel via sysctl avec sauvegarde
    persistante et validation de sécurité.

Arguments:
    <parameter>      Paramètre kernel (ex: net.ipv4.ip_forward)
    <value>          Nouvelle valeur du paramètre

Options:
    -h, --help       Afficher cette aide
    -v, --verbose    Mode verbeux
    -d, --debug      Mode debug
    -q, --quiet      Mode silencieux
    -j, --json-only  Sortie JSON uniquement
    -f, --force      Forcer même si dangereux
    --no-persist     Ne pas sauvegarder dans /etc/sysctl.conf
    --no-backup      Ne pas créer de sauvegarde
    
Exemples:
    $SCRIPT_NAME net.ipv4.ip_forward 1
    $SCRIPT_NAME vm.swappiness 10
    $SCRIPT_NAME -f kernel.panic 0
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
            -f|--force) FORCE=1; shift ;;
            --no-persist) PERSISTENT=0; shift ;;
            --no-backup) BACKUP=0; shift ;;
            -*) echo "Option inconnue: $1" >&2; exit 2 ;;
            *) 
                if [[ -z "$PARAMETER" ]]; then
                    PARAMETER="$1"
                elif [[ -z "$VALUE" ]]; then
                    VALUE="$1"
                else
                    echo "Trop d'arguments" >&2; exit 2
                fi
                shift ;;
        esac
    done

    [[ -z "$PARAMETER" ]] && { echo "Paramètre manquant" >&2; exit 2; }
    [[ -z "$VALUE" ]] && { echo "Valeur manquante" >&2; exit 2; }
}

validate_parameter() {
    local param="$1"
    # Vérifier que le paramètre existe dans /proc/sys
    local proc_path="/proc/sys/$(echo "$param" | tr '.' '/')"
    [[ -f "$proc_path" ]]
}

get_current_value() {
    local param="$1"
    sysctl -n "$param" 2>/dev/null || echo ""
}

check_dangerous_parameters() {
    local param="$1"
    local dangerous_params=(
        "kernel.panic"
        "kernel.sysrq"
        "vm.drop_caches"
        "vm.panic_on_oom"
        "kernel.core_pattern"
    )
    
    for dangerous in "${dangerous_params[@]}"; do
        [[ "$param" == "$dangerous" ]] && return 0
    done
    return 1
}

validate_value() {
    local param="$1" value="$2"
    
    # Validations spécifiques par paramètre
    case "$param" in
        net.ipv4.ip_forward|net.ipv6.conf.all.forwarding)
            [[ "$value" =~ ^[01]$ ]] || return 1
            ;;
        vm.swappiness)
            [[ "$value" =~ ^[0-9]+$ ]] && [[ $value -ge 0 ]] && [[ $value -le 100 ]] || return 1
            ;;
        net.core.somaxconn|net.core.netdev_max_backlog)
            [[ "$value" =~ ^[0-9]+$ ]] && [[ $value -gt 0 ]] || return 1
            ;;
        vm.max_map_count)
            [[ "$value" =~ ^[0-9]+$ ]] && [[ $value -gt 0 ]] || return 1
            ;;
        *)
            # Validation générique : numérique ou chaîne
            [[ -n "$value" ]] || return 1
            ;;
    esac
    return 0
}

backup_sysctl_conf() {
    local backup_file="/etc/sysctl.conf.backup.$(date +%Y%m%d_%H%M%S)"
    if [[ -f /etc/sysctl.conf ]]; then
        cp /etc/sysctl.conf "$backup_file" && echo "$backup_file"
    fi
}

set_kernel_parameter() {
    local param="$1" value="$2"
    sysctl -w "${param}=${value}" >/dev/null 2>&1
}

make_persistent() {
    local param="$1" value="$2"
    local sysctl_conf="/etc/sysctl.conf"
    
    # Créer le fichier s'il n'existe pas
    [[ ! -f "$sysctl_conf" ]] && touch "$sysctl_conf"
    
    # Supprimer l'ancienne entrée si elle existe
    sed -i "/^${param}[[:space:]]*=/d" "$sysctl_conf"
    
    # Ajouter la nouvelle entrée
    echo "${param} = ${value}" >> "$sysctl_conf"
}

get_parameter_info() {
    local param="$1"
    local proc_path="/proc/sys/$(echo "$param" | tr '.' '/')"
    local info="{}"
    
    if [[ -f "$proc_path" ]]; then
        local current_value writable description=""
        current_value=$(cat "$proc_path" 2>/dev/null || echo "unknown")
        writable=$([ -w "$proc_path" ] && echo "true" || echo "false")
        
        # Essayer de récupérer la description depuis la documentation
        case "$param" in
            net.ipv4.ip_forward)
                description="Enable IP forwarding"
                ;;
            vm.swappiness)
                description="Swap usage aggressiveness (0-100)"
                ;;
            vm.max_map_count)
                description="Maximum number of memory map areas"
                ;;
            *)
                description="Kernel parameter"
                ;;
        esac
        
        info=$(cat << EOF
{
  "exists": true,
  "current_value": "$current_value",
  "writable": $writable,
  "description": "$description",
  "proc_path": "$proc_path"
}
EOF
)
    else
        info='{"exists": false}'
    fi
    
    echo "$info"
}

main() {
    parse_args "$@"
    
    local errors=() warnings=()
    
    # Vérifier les permissions root
    if [[ $EUID -ne 0 ]]; then
        errors+=("Root privileges required to modify kernel parameters")
    fi
    
    # Vérifier que le paramètre existe
    if ! validate_parameter "$PARAMETER"; then
        errors+=("Kernel parameter does not exist: $PARAMETER")
    fi
    
    # Valider la valeur
    if [[ ${#errors[@]} -eq 0 ]] && ! validate_value "$PARAMETER" "$VALUE"; then
        errors+=("Invalid value for parameter $PARAMETER: $VALUE")
    fi
    
    # Vérifier les paramètres dangereux
    if [[ ${#errors[@]} -eq 0 ]] && check_dangerous_parameters "$PARAMETER" && [[ $FORCE -eq 0 ]]; then
        warnings+=("Potentially dangerous parameter, use --force to proceed")
        errors+=("Dangerous parameter modification requires --force flag")
    fi
    
    if [[ ${#errors[@]} -eq 0 ]]; then
        local start_time end_time duration backup_file=""
        local current_value new_value param_info
        
        start_time=$(date +%s)
        current_value=$(get_current_value "$PARAMETER")
        param_info=$(get_parameter_info "$PARAMETER")
        
        # Créer une sauvegarde si demandé
        if [[ $BACKUP -eq 1 ]] && [[ $PERSISTENT -eq 1 ]]; then
            backup_file=$(backup_sysctl_conf)
            if [[ -z "$backup_file" ]]; then
                warnings+=("Failed to create backup of sysctl.conf")
            fi
        fi
        
        # Définir le paramètre
        if set_kernel_parameter "$PARAMETER" "$VALUE"; then
            new_value=$(get_current_value "$PARAMETER")
            
            # Rendre persistant si demandé
            if [[ $PERSISTENT -eq 1 ]]; then
                make_persistent "$PARAMETER" "$VALUE"
            fi
            
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            
            # Vérifier que la valeur a bien été appliquée
            local applied_successfully="true"
            if [[ "$new_value" != "$VALUE" ]]; then
                applied_successfully="false"
                warnings+=("Applied value differs from requested value")
            fi
            
            cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Kernel parameter set successfully",
  "data": {
    "parameter": "$PARAMETER",
    "requested_value": "$VALUE",
    "previous_value": "$current_value",
    "current_value": "$new_value",
    "applied_successfully": $applied_successfully,
    "made_persistent": $([ $PERSISTENT -eq 1 ] && echo "true" || echo "false"),
    "backup_created": $([ -n "$backup_file" ] && echo "true" || echo "false"),
    "backup_file": "$backup_file",
    "parameter_info": $param_info,
    "duration_seconds": $duration,
    "dangerous_parameter": $(check_dangerous_parameters "$PARAMETER" && echo "true" || echo "false")
  },
  "errors": [],
  "warnings": [$(printf '"%s",' "${warnings[@]}" | sed 's/,$//')"]
}
EOF
        else
            errors+=("Failed to set kernel parameter")
        fi
    fi
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        cat << EOF
{
  "status": "error",
  "code": 1,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Kernel parameter configuration failed",
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