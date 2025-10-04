#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: schedule-task.at.sh 
# Description: Programmer des tâches avec at/batch
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-04
# ==============================================================================

set -euo pipefail

SCRIPT_NAME="schedule-task.at.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
ACTION=""
WHEN=""
COMMAND=""
TASK_ID=""

show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] <action> [arguments...]

Description:
    Gère les tâches programmées avec at/batch pour exécution différée.

Actions:
    schedule <when> <command>    Programmer une tâche
    list                         Lister les tâches programmées
    remove <job_id>             Supprimer une tâche
    status <job_id>             Statut d'une tâche

Arguments:
    <when>      Moment d'exécution (now +1hour, 14:30, tomorrow, etc.)
    <command>   Commande à exécuter
    <job_id>    ID de la tâche

Options:
    -h, --help       Afficher cette aide
    -v, --verbose    Mode verbeux
    -d, --debug      Mode debug
    -q, --quiet      Mode silencieux
    -j, --json-only  Sortie JSON uniquement
    
Exemples:
    $SCRIPT_NAME schedule "now +1hour" "backup.sh"
    $SCRIPT_NAME schedule "14:30" "/usr/bin/maintenance.sh"
    $SCRIPT_NAME list
    $SCRIPT_NAME remove 1
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
            -*) echo "Option inconnue: $1" >&2; exit 2 ;;
            *) 
                if [[ -z "$ACTION" ]]; then
                    ACTION="$1"
                elif [[ "$ACTION" == "schedule" && -z "$WHEN" ]]; then
                    WHEN="$1"
                elif [[ "$ACTION" == "schedule" && -z "$COMMAND" ]]; then
                    COMMAND="$1"
                elif [[ ("$ACTION" == "remove" || "$ACTION" == "status") && -z "$TASK_ID" ]]; then
                    TASK_ID="$1"
                else
                    echo "Argument inattendu: $1" >&2; exit 2
                fi
                shift ;;
        esac
    done

    [[ -z "$ACTION" ]] && { echo "Action manquante" >&2; exit 2; }
}

check_at_service() {
    command -v at >/dev/null 2>&1 && systemctl is-active atd >/dev/null 2>&1
}

schedule_task() {
    local when="$1" cmd="$2"
    local job_id
    
    if job_id=$(echo "$cmd" | at "$when" 2>&1 | grep -o "job [0-9]\+" | cut -d' ' -f2); then
        cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Task scheduled successfully",
  "data": {
    "action": "schedule",
    "job_id": "$job_id",
    "scheduled_time": "$when",
    "command": "$cmd"
  },
  "errors": [],
  "warnings": []
}
EOF
    else
        cat << EOF
{
  "status": "error",
  "code": 1,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Failed to schedule task",
  "data": {},
  "errors": ["Task scheduling failed"],
  "warnings": []
}
EOF
        exit 1
    fi
}

list_tasks() {
    local tasks_json="[]"
    
    if command -v atq >/dev/null 2>&1; then
        local tasks=()
        while read -r line; do
            if [[ -n "$line" ]]; then
                local job_id date time queue user
                read -r job_id date time queue user <<< "$line"
                tasks+=("{\"job_id\":\"$job_id\",\"date\":\"$date\",\"time\":\"$time\",\"queue\":\"$queue\",\"user\":\"$user\"}")
            fi
        done < <(atq 2>/dev/null)
        
        if [[ ${#tasks[@]} -gt 0 ]]; then
            tasks_json="[$(IFS=','; echo "${tasks[*]}")]"
        fi
    fi
    
    cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Tasks listed successfully",
  "data": {
    "action": "list",
    "tasks": $tasks_json,
    "count": $(echo "$tasks_json" | jq length 2>/dev/null || echo "0")
  },
  "errors": [],
  "warnings": []
}
EOF
}

main() {
    parse_args "$@"
    
    local errors=()
    
    if ! check_at_service; then
        errors+=("at service not available or not running")
    fi
    
    case "$ACTION" in
        schedule)
            [[ -z "$WHEN" ]] && errors+=("Schedule time missing")
            [[ -z "$COMMAND" ]] && errors+=("Command missing")
            [[ ${#errors[@]} -eq 0 ]] && schedule_task "$WHEN" "$COMMAND"
            ;;
        list)
            [[ ${#errors[@]} -eq 0 ]] && list_tasks
            ;;
        remove|status)
            echo '{"status":"success","message":"Action not yet implemented"}'
            ;;
        *)
            errors+=("Unknown action: $ACTION")
            ;;
    esac
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        cat << EOF
{
  "status": "error",
  "code": 1,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Operation failed",
  "data": {},
  "errors": [$(printf '"%s",' "${errors[@]}" | sed 's/,$//')],
  "warnings": []
}
EOF
        exit 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi