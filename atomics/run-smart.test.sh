#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: run-smart.test.sh 
# Description: Exécuter des tests SMART sur les disques
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-04
# ==============================================================================

set -euo pipefail

SCRIPT_NAME="run-smart.test.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
DEVICE=""
TEST_TYPE=${TEST_TYPE:-"short"}
WAIT_COMPLETION=${WAIT_COMPLETION:-0}
FORCE=${FORCE:-0}

show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] <device>

Description:
    Lance des tests SMART sur un disque dur pour diagnostiquer
    l'état de santé et détecter les défaillances potentielles.

Arguments:
    <device>         Périphérique à tester (/dev/sda, /dev/nvme0n1, etc.)

Options:
    -h, --help       Afficher cette aide
    -v, --verbose    Mode verbeux
    -d, --debug      Mode debug
    -q, --quiet      Mode silencieux
    -j, --json-only  Sortie JSON uniquement
    -t, --test TYPE  Type de test (short|long|conveyance|selective)
    -w, --wait       Attendre la fin du test
    -f, --force      Forcer même si un test est en cours
    
Exemples:
    $SCRIPT_NAME /dev/sda
    $SCRIPT_NAME -t long -w /dev/nvme0n1
    $SCRIPT_NAME -f -t conveyance /dev/sdb
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
            -t|--test) TEST_TYPE="$2"; shift 2 ;;
            -w|--wait) WAIT_COMPLETION=1; shift ;;
            -f|--force) FORCE=1; shift ;;
            -*) echo "Option inconnue: $1" >&2; exit 2 ;;
            *) 
                [[ -z "$DEVICE" ]] && DEVICE="$1" || { echo "Trop d'arguments" >&2; exit 2; }
                shift ;;
        esac
    done

    [[ -z "$DEVICE" ]] && { echo "Périphérique manquant" >&2; exit 2; }
    [[ ! -b "$DEVICE" ]] && { echo "Périphérique non trouvé: $DEVICE" >&2; exit 3; }
    
    # Valider le type de test
    case "$TEST_TYPE" in
        short|long|conveyance|selective) ;;
        *) echo "Type de test invalide: $TEST_TYPE" >&2; exit 2 ;;
    esac
}

check_smartctl() {
    command -v smartctl >/dev/null 2>&1 || return 1
}

check_smart_support() {
    local device="$1"
    smartctl -i "$device" >/dev/null 2>&1
}

get_smart_info() {
    local device="$1"
    local info_json="{}"
    
    if smartctl -i "$device" >/dev/null 2>&1; then
        local model serial capacity
        model=$(smartctl -i "$device" | grep "Device Model" | cut -d: -f2 | xargs || echo "unknown")
        serial=$(smartctl -i "$device" | grep "Serial Number" | cut -d: -f2 | xargs || echo "unknown")
        capacity=$(smartctl -i "$device" | grep "User Capacity" | cut -d: -f2 | cut -d'[' -f1 | xargs || echo "unknown")
        
        info_json=$(cat << EOF
{
  "model": "$model",
  "serial": "$serial",
  "capacity": "$capacity",
  "smart_available": true
}
EOF
)
    else
        info_json='{"smart_available": false}'
    fi
    
    echo "$info_json"
}

get_current_test_status() {
    local device="$1"
    local status
    
    if status=$(smartctl -c "$device" 2>/dev/null | grep "Self-test execution status"); then
        if echo "$status" | grep -q "in progress"; then
            local percent
            percent=$(echo "$status" | grep -o "[0-9]\+%" | head -1 || echo "0%")
            echo "running:$percent"
        elif echo "$status" | grep -q "completed without error"; then
            echo "completed:success"
        elif echo "$status" | grep -q "was aborted"; then
            echo "aborted"
        elif echo "$status" | grep -q "failed"; then
            echo "failed"
        else
            echo "idle"
        fi
    else
        echo "unknown"
    fi
}

start_smart_test() {
    local device="$1"
    local test_type="$2"
    
    smartctl -t "$test_type" "$device" >/dev/null 2>&1
}

get_test_duration() {
    local device="$1"
    local test_type="$2"
    
    case "$test_type" in
        short) echo "2" ;;  # minutes
        long) 
            # Essayer de récupérer la durée estimée
            local duration
            duration=$(smartctl -c "$device" 2>/dev/null | grep "Extended self-test routine" | grep -o "[0-9]\+" | head -1 || echo "60")
            echo "$duration"
            ;;
        conveyance) echo "5" ;;
        selective) echo "10" ;;
        *) echo "30" ;;
    esac
}

wait_for_test_completion() {
    local device="$1"
    local max_wait_minutes="$2"
    local start_time end_time
    
    start_time=$(date +%s)
    
    while true; do
        local status
        status=$(get_current_test_status "$device")
        
        case "$status" in
            completed:*|aborted|failed)
                return 0
                ;;
            running:*)
                sleep 30
                ;;
            *)
                sleep 10
                ;;
        esac
        
        end_time=$(date +%s)
        local elapsed_minutes=$(( (end_time - start_time) / 60 ))
        
        if [[ $elapsed_minutes -gt $max_wait_minutes ]]; then
            return 1
        fi
    done
}

get_smart_attributes() {
    local device="$1"
    local attributes=()
    
    # Récupérer les attributs critiques
    if smartctl -A "$device" >/dev/null 2>&1; then
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*[0-9]+ ]]; then
                local id name value worst threshold
                read -r id name _ _ _ _ _ _ _ value worst threshold _ <<< "$line"
                
                # Filtrer les attributs importants
                case "$name" in
                    Reallocated_Sector_Ct|Spin_Retry_Count|End-to-End_Error|Reported_Uncorrect|Command_Timeout|Current_Pending_Sector|Offline_Uncorrectable)
                        attributes+=("{\"id\":$id,\"name\":\"$name\",\"value\":$value,\"worst\":$worst,\"threshold\":$threshold}")
                        ;;
                esac
            fi
        done < <(smartctl -A "$device" 2>/dev/null)
    fi
    
    echo "[$(IFS=','; echo "${attributes[*]}")]"
}

main() {
    parse_args "$@"
    
    local errors=() warnings=()
    
    # Vérifier smartctl
    if ! check_smartctl; then
        errors+=("smartctl command not found - install smartmontools package")
    fi
    
    # Vérifier le support SMART
    if [[ ${#errors[@]} -eq 0 ]] && ! check_smart_support "$DEVICE"; then
        errors+=("SMART not supported or enabled on device: $DEVICE")
    fi
    
    # Vérifier si un test est déjà en cours
    local current_status
    if [[ ${#errors[@]} -eq 0 ]]; then
        current_status=$(get_current_test_status "$DEVICE")
        if [[ "$current_status" =~ ^running: ]] && [[ $FORCE -eq 0 ]]; then
            errors+=("Test already in progress, use --force to abort current test")
        fi
    fi
    
    if [[ ${#errors[@]} -eq 0 ]]; then
        # Récupérer les informations du disque
        local device_info
        device_info=$(get_smart_info "$DEVICE")
        
        # Démarrer le test
        local start_time end_time duration test_started=false
        start_time=$(date +%s)
        
        if start_smart_test "$DEVICE" "$TEST_TYPE"; then
            test_started=true
            
            # Attendre la fin si demandé
            local final_status="initiated"
            local test_duration
            test_duration=$(get_test_duration "$DEVICE" "$TEST_TYPE")
            
            if [[ $WAIT_COMPLETION -eq 1 ]]; then
                if wait_for_test_completion "$DEVICE" "$((test_duration + 10))"; then
                    final_status=$(get_current_test_status "$DEVICE")
                else
                    final_status="timeout"
                    warnings+=("Test did not complete within expected time")
                fi
            fi
            
            end_time=$(date +%s)
            duration=$((end_time - start_time))
            
            # Récupérer les attributs SMART après le test
            local smart_attributes
            smart_attributes=$(get_smart_attributes "$DEVICE")
            
            cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "SMART test completed successfully",
  "data": {
    "device": "$DEVICE",
    "test_type": "$TEST_TYPE",
    "test_started": $test_started,
    "estimated_duration_minutes": $test_duration,
    "actual_duration_seconds": $duration,
    "waited_for_completion": $([ $WAIT_COMPLETION -eq 1 ] && echo "true" || echo "false"),
    "final_status": "$final_status",
    "device_info": $device_info,
    "smart_attributes": $smart_attributes,
    "force_mode": $([ $FORCE -eq 1 ] && echo "true" || echo "false")
  },
  "errors": [],
  "warnings": [$(printf '"%s",' "${warnings[@]}" | sed 's/,$//')"]
}
EOF
        else
            errors+=("Failed to start SMART test")
        fi
    fi
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        cat << EOF
{
  "status": "error",
  "code": 1,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "SMART test failed to start",
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