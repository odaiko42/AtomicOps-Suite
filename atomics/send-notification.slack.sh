#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: send-notification.slack.sh 
# Description: Envoyer des notifications vers Slack
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-04
# ==============================================================================

set -euo pipefail

SCRIPT_NAME="send-notification.slack.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
WEBHOOK_URL=""
MESSAGE=""
CHANNEL=""
USERNAME=${USERNAME:-"SystemBot"}
ICON=${ICON:-":robot_face:"}
COLOR=""
TITLE=""

show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] <webhook_url> <message>

Description:
    Envoie des notifications vers Slack via webhook avec
    formatage riche et personnalisation.

Arguments:
    <webhook_url>    URL de webhook Slack
    <message>        Message à envoyer

Options:
    -h, --help       Afficher cette aide
    -v, --verbose    Mode verbeux
    -d, --debug      Mode debug
    -q, --quiet      Mode silencieux
    -j, --json-only  Sortie JSON uniquement
    -c, --channel CH Canal Slack (#general, @user)
    -u, --username U Nom d'utilisateur bot
    -i, --icon ICON  Icône bot (:emoji: ou URL)
    --color COLOR    Couleur message (good|warning|danger|hex)
    --title TITLE    Titre du message
    
Exemples:
    $SCRIPT_NAME "https://hooks.slack.com/..." "System alert"
    $SCRIPT_NAME --color danger --title "ERROR" "https://..." "Service down"
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
            -c|--channel) CHANNEL="$2"; shift 2 ;;
            -u|--username) USERNAME="$2"; shift 2 ;;
            -i|--icon) ICON="$2"; shift 2 ;;
            --color) COLOR="$2"; shift 2 ;;
            --title) TITLE="$2"; shift 2 ;;
            -*) echo "Option inconnue: $1" >&2; exit 2 ;;
            *) 
                if [[ -z "$WEBHOOK_URL" ]]; then
                    WEBHOOK_URL="$1"
                elif [[ -z "$MESSAGE" ]]; then
                    MESSAGE="$1"
                else
                    echo "Trop d'arguments" >&2; exit 2
                fi
                shift ;;
        esac
    done

    [[ -z "$WEBHOOK_URL" ]] && { echo "URL webhook manquante" >&2; exit 2; }
    [[ -z "$MESSAGE" ]] && { echo "Message manquant" >&2; exit 2; }
}

validate_webhook_url() {
    local url="$1"
    [[ "$url" =~ ^https://hooks\.slack\.com/services/ ]]
}

check_curl() {
    command -v curl >/dev/null 2>&1
}

escape_json() {
    local text="$1"
    echo "$text" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\n/\\n/g; s/\r/\\r/g'
}

build_slack_payload() {
    local message="$1" channel="$2" username="$3" icon="$4" color="$5" title="$6"
    local payload="{\"text\":\"$(escape_json "$message")\""
    
    [[ -n "$channel" ]] && payload+=",\"channel\":\"$(escape_json "$channel")\""
    [[ -n "$username" ]] && payload+=",\"username\":\"$(escape_json "$username")\""
    
    # Gérer l'icône (emoji ou URL)
    if [[ -n "$icon" ]]; then
        if [[ "$icon" =~ ^https?:// ]]; then
            payload+=",\"icon_url\":\"$(escape_json "$icon")\""
        else
            payload+=",\"icon_emoji\":\"$(escape_json "$icon")\""
        fi
    fi
    
    # Ajouter formatage riche si couleur ou titre
    if [[ -n "$color" || -n "$title" ]]; then
        payload+=",\"attachments\":[{"
        
        [[ -n "$color" ]] && payload+="\"color\":\"$(escape_json "$color")\""
        
        if [[ -n "$title" ]]; then
            [[ -n "$color" ]] && payload+=","
            payload+="\"title\":\"$(escape_json "$title")\""
        fi
        
        payload+="}]"
    fi
    
    payload+="}"
    echo "$payload"
}

send_to_slack() {
    local webhook_url="$1" payload="$2"
    local response http_code
    
    response=$(curl -s -w "\n%{http_code}" -X POST \
        -H 'Content-type: application/json' \
        --data "$payload" \
        "$webhook_url" 2>/dev/null)
    
    http_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | head -n -1)
    
    echo "$http_code:$response_body"
}

validate_color() {
    local color="$1"
    case "$color" in
        good|warning|danger) return 0 ;;
        \#[0-9a-fA-F]{6}) return 0 ;;
        *) return 1 ;;
    esac
}

main() {
    parse_args "$@"
    
    local errors=() warnings=()
    
    # Valider l'URL webhook
    if ! validate_webhook_url "$WEBHOOK_URL"; then
        errors+=("Invalid Slack webhook URL format")
    fi
    
    # Vérifier curl
    if ! check_curl; then
        errors+=("curl command not found")
    fi
    
    # Valider la couleur si spécifiée
    if [[ -n "$COLOR" ]] && ! validate_color "$COLOR"; then
        warnings+=("Invalid color format, using default")
        COLOR=""
    fi
    
    # Valider le canal
    if [[ -n "$CHANNEL" ]] && [[ ! "$CHANNEL" =~ ^[#@] ]]; then
        warnings+=("Channel should start with # or @")
    fi
    
    if [[ ${#errors[@]} -eq 0 ]]; then
        local start_time end_time duration
        start_time=$(date +%s)
        
        # Construire le payload
        local payload
        payload=$(build_slack_payload "$MESSAGE" "$CHANNEL" "$USERNAME" "$ICON" "$COLOR" "$TITLE")
        
        # Envoyer le message
        local result http_code response_body
        result=$(send_to_slack "$WEBHOOK_URL" "$payload")
        IFS=':' read -r http_code response_body <<< "$result"
        
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        
        if [[ "$http_code" == "200" ]]; then
            cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Slack notification sent successfully",
  "data": {
    "webhook_url": "$(echo "$WEBHOOK_URL" | sed 's|/services/.*|/services/***|')",
    "message_length": ${#MESSAGE},
    "channel": "$CHANNEL",
    "username": "$USERNAME",
    "icon": "$ICON",
    "color": "$COLOR",
    "title": "$TITLE",
    "http_code": $http_code,
    "response": "$(escape_json "$response_body")",
    "duration_seconds": $duration,
    "payload_size": ${#payload}
  },
  "errors": [],
  "warnings": [$(printf '"%s",' "${warnings[@]}" | sed 's/,$//')"]
}
EOF
        else
            errors+=("HTTP error $http_code: $response_body")
        fi
    fi
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        cat << EOF
{
  "status": "error",
  "code": 1,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Slack notification failed",
  "data": {
    "http_code": $([ -n "${http_code:-}" ] && echo "$http_code" || echo "0")
  },
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