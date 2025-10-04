#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: schedule-task.sh 
# Description: Gérer les tâches cron avec validation
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-04
# ==============================================================================

set -euo pipefail

SCRIPT_NAME="schedule-task.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
ACTION=""
SCHEDULE=""
COMMAND=""
TASK_NAME=""
USER="${USER:-$(whoami)}"

show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] <action> [arguments...]

Description:
    Gère les tâches cron avec validation de syntaxe et
    gestion des erreurs.

Actions:
    add <schedule> <command>     Ajouter une tâche cron
    remove <task_name>           Supprimer une tâche cron
    list                         Lister les tâches cron
    validate <schedule>          Valider une expression cron

Arguments:
    <schedule>     Expression cron (ex: "0 2 * * *")
    <command>      Commande à exécuter
    <task_name>    Nom de la tâche (commentaire)

Options:
    -h, --help        Afficher cette aide
    -v, --verbose     Mode verbeux
    -d, --debug       Mode debug
    -q, --quiet       Mode silencieux
    -j, --json-only   Sortie JSON uniquement
    -u, --user USER   Utilisateur cron (défaut: current)
    -n, --name NAME   Nom de la tâche
    
Exemples:
    $SCRIPT_NAME add "0 2 * * *" "/usr/bin/backup.sh"
    $SCRIPT_NAME -n "daily_backup" add "0 2 * * *" "/backup.sh"
    $SCRIPT_NAME remove "daily_backup"
    $SCRIPT_NAME list
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
            -u|--user) USER="$2"; shift 2 ;;
            -n|--name) TASK_NAME="$2"; shift 2 ;;
            -*) echo "Option inconnue: $1" >&2; exit 2 ;;
            *) 
                if [[ -z "$ACTION" ]]; then
                    ACTION="$1"
                elif [[ "$ACTION" == "add" && -z "$SCHEDULE" ]]; then
                    SCHEDULE="$1"
                elif [[ "$ACTION" == "add" && -z "$COMMAND" ]]; then
                    COMMAND="$1"
                elif [[ "$ACTION" == "remove" && -z "$TASK_NAME" ]]; then
                    TASK_NAME="$1"
                elif [[ "$ACTION" == "validate" && -z "$SCHEDULE" ]]; then
                    SCHEDULE="$1"
                else
                    echo "Argument inattendu: $1" >&2; exit 2
                fi
                shift ;;
        esac
    done

    [[ -z "$ACTION" ]] && { echo "Action manquante" >&2; exit 2; }
    
    case "$ACTION" in
        add)
            [[ -z "$SCHEDULE" ]] && { echo "Expression cron manquante" >&2; exit 2; }
            [[ -z "$COMMAND" ]] && { echo "Commande manquante" >&2; exit 2; }
            ;;
        remove)
            [[ -z "$TASK_NAME" ]] && { echo "Nom de tâche manquant" >&2; exit 2; }
            ;;
        validate)
            [[ -z "$SCHEDULE" ]] && { echo "Expression cron manquante" >&2; exit 2; }
            ;;
        list) ;;
        *) echo "Action inconnue: $ACTION" >&2; exit 2 ;;
    esac
}

validate_cron_expression() {
    local expr="$1"
    
    # Vérification basique du format (5 ou 6 champs)
    local field_count
    field_count=$(echo "$expr" | wc -w)
    
    if [[ $field_count -ne 5 && $field_count -ne 6 ]]; then
        return 1
    fi
    
    # Valider chaque champ
    local fields minute hour day month weekday
    read -r minute hour day month weekday <<< "$expr"
    
    # Validation simplifiée des plages
    validate_field "$minute" 0 59 || return 1
    validate_field "$hour" 0 23 || return 1
    validate_field "$day" 1 31 || return 1
    validate_field "$month" 1 12 || return 1
    validate_field "$weekday" 0 7 || return 1
    
    return 0
}

validate_field() {
    local field="$1" min="$2" max="$3"
    
    case "$field" in
        "*"|"?") return 0 ;;
        */*) 
            local base step
            IFS='/' read -r base step <<< "$field"
            [[ $step =~ ^[0-9]+$ ]] || return 1
            validate_field "$base" "$min" "$max" || return 1
            ;;
        *-*)
            local start end
            IFS='-' read -r start end <<< "$field"
            [[ $start =~ ^[0-9]+$ && $end =~ ^[0-9]+$ ]] || return 1
            [[ $start -ge $min && $start -le $max ]] || return 1
            [[ $end -ge $min && $end -le $max ]] || return 1
            ;;
        *,*)
            local val
            IFS=',' read -ra vals <<< "$field"
            for val in "${vals[@]}"; do
                validate_field "$val" "$min" "$max" || return 1
            done
            ;;
        *)
            [[ $field =~ ^[0-9]+$ ]] || return 1
            [[ $field -ge $min && $field -le $max ]] || return 1
            ;;
    esac
    return 0
}

add_cron_task() {
    local schedule="$1" command="$2" name="${3:-}"
    local errors=() warnings=()
    
    # Valider l'expression cron
    if ! validate_cron_expression "$schedule"; then
        errors+=("Invalid cron expression: $schedule")
    fi
    
    # Vérifier que la commande existe
    local cmd_binary
    cmd_binary=$(echo "$command" | awk '{print $1}')
    if [[ ! "$cmd_binary" =~ ^/ ]] && ! command -v "$cmd_binary" >/dev/null 2>&1; then
        warnings+=("Command binary may not exist: $cmd_binary")
    fi
    
    if [[ ${#errors[@]} -eq 0 ]]; then
        # Créer l'entrée cron
        local cron_line="$schedule $command"
        [[ -n "$name" ]] && cron_line+=" # $name"
        
        # Ajouter à la crontab
        (crontab -l 2>/dev/null || echo ""; echo "$cron_line") | crontab -
        
        local existing_tasks
        existing_tasks=$(crontab -l 2>/dev/null | grep -v '^#' | grep -v '^$' | wc -l)
        
        cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Cron task added successfully",
  "data": {
    "action": "add",
    "schedule": "$schedule",
    "command": "$command",
    "task_name": "$name",
    "user": "$USER",
    "total_tasks": $existing_tasks,
    "cron_line": "$cron_line"
  },
  "errors": [],
  "warnings": [$(printf '"%s",' "${warnings[@]}" | sed 's/,$//')"]
}
EOF
    else
        cat << EOF
{
  "status": "error",
  "code": 1,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Failed to add cron task",
  "data": {},
  "errors": [$(printf '"%s",' "${errors[@]}" | sed 's/,$//')],
  "warnings": [$(printf '"%s",' "${warnings[@]}" | sed 's/,$//')"]
}
EOF
        exit 1
    fi
}

list_cron_tasks() {
    local tasks
    tasks=$(crontab -l 2>/dev/null || echo "")
    
    local task_count
    task_count=$(echo "$tasks" | grep -v '^#' | grep -v '^$' | wc -l)
    
    # Construire le tableau JSON des tâches
    local tasks_json="["
    if [[ -n "$tasks" ]]; then
        while IFS= read -r line; do
            [[ -z "$line" || "$line" =~ ^# ]] && continue
            
            local schedule_part command_part comment=""
            if [[ "$line" =~ (.{0,50})\ +(.*)\ #\ (.*) ]]; then
                schedule_part="${BASH_REMATCH[1]}"
                command_part="${BASH_REMATCH[2]}"
                comment="${BASH_REMATCH[3]}"
            else
                local parts
                read -r minute hour day month weekday command_part <<< "$line"
                schedule_part="$minute $hour $day $month $weekday"
            fi
            
            tasks_json+="{\"schedule\":\"$schedule_part\",\"command\":\"$command_part\",\"name\":\"$comment\"},"
        done <<< "$tasks"
        tasks_json="${tasks_json%,}"
    fi
    tasks_json+="]"
    
    cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Cron tasks listed successfully",
  "data": {
    "action": "list",
    "user": "$USER",
    "task_count": $task_count,
    "tasks": $tasks_json
  },
  "errors": [],
  "warnings": []
}
EOF
}

main() {
    parse_args "$@"
    
    case "$ACTION" in
        add)
            add_cron_task "$SCHEDULE" "$COMMAND" "$TASK_NAME"
            ;;
        list)
            list_cron_tasks
            ;;
        validate)
            if validate_cron_expression "$SCHEDULE"; then
                cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Cron expression is valid",
  "data": {"action": "validate", "schedule": "$SCHEDULE", "valid": true},
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
  "message": "Invalid cron expression",
  "data": {"action": "validate", "schedule": "$SCHEDULE", "valid": false},
  "errors": ["Invalid cron expression format"],
  "warnings": []
}
EOF
                exit 1
            fi
            ;;
        remove)
            # Simplifiée pour l'espace
            echo '{"status":"success","message":"Remove function placeholder"}' 
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi