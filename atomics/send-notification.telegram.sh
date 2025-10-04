#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: send-notification.telegram.sh 
# Description: Envoyer des notifications vers Telegram
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-04
# ==============================================================================

set -euo pipefail

SCRIPT_NAME="send-notification.telegram.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
BOT_TOKEN=""
CHAT_ID=""
MESSAGE=""
PARSE_MODE=${PARSE_MODE:-""}
DISABLE_PREVIEW=${DISABLE_PREVIEW:-0}
DISABLE_NOTIFICATION=${DISABLE_NOTIFICATION:-0}

show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] <bot_token> <chat_id> <message>

Description:
    Envoie des notifications vers Telegram via l'API Bot
    avec support du formatage Markdown/HTML.

Arguments:
    <bot_token>      Token du bot Telegram
    <chat_id>        ID du chat/canal/utilisateur
    <message>        Message à envoyer

Options:
    -h, --help       Afficher cette aide
    -v, --verbose    Mode verbeux
    -d, --debug      Mode debug
    -q, --quiet      Mode silencieux
    -j, --json-only  Sortie JSON uniquement
    -p, --parse MODE Format (Markdown|MarkdownV2|HTML)
    --no-preview     Désactiver aperçu des liens
    --silent         Envoyer silencieusement
    
Exemples:
    $SCRIPT_NAME "123456:ABC..." "-123456789" "System alert"
    $SCRIPT_NAME -p Markdown "token" "chat" "*Bold text*"
    $SCRIPT_NAME --silent "token" "@username" "Quiet notification"
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
            -p|--parse) PARSE_MODE="$2"; shift 2 ;;
            --no-preview) DISABLE_PREVIEW=1; shift ;;
            --silent) DISABLE_NOTIFICATION=1; shift ;;
            -*) echo "Option inconnue: $1" >&2; exit 2 ;;
            *) 
                if [[ -z "$BOT_TOKEN" ]]; then
                    BOT_TOKEN="$1"
                elif [[ -z "$CHAT_ID" ]]; then
                    CHAT_ID="$1"
                elif [[ -z "$MESSAGE" ]]; then
                    MESSAGE="$1"
                else
                    echo "Trop d'arguments" >&2; exit 2
                fi
                shift ;;
        esac
    done

    [[ -z "$BOT_TOKEN" ]] && { echo "Token bot manquant" >&2; exit 2; }
    [[ -z "$CHAT_ID" ]] && { echo "Chat ID manquant" >&2; exit 2; }
    [[ -z "$MESSAGE" ]] && { echo "Message manquant" >&2; exit 2; }
}

validate_bot_token() {
    local token="$1"
    [[ "$token" =~ ^[0-9]+:[a-zA-Z0-9_-]{35}$ ]]
}

validate_parse_mode() {
    local mode="$1"
    case "$mode" in
        ""|Markdown|MarkdownV2|HTML) return 0 ;;
        *) return 1 ;;
    esac
}

check_curl() {
    command -v curl >/dev/null 2>&1
}

url_encode() {
    local text="$1"
    echo "$text" | sed 's/ /%20/g; s/!/%21/g; s/"/%22/g; s/#/%23/g; s/\$/%24/g; s/&/%26/g; s/'\''/%27/g; s/(/%28/g; s/)/%29/g; s/\*/%2A/g; s/+/%2B/g; s/,/%2C/g; s/:/%3A/g; s/;/%3B/g; s/=/%3D/g; s/?/%3F/g; s/@/%40/g; s/\[/%5B/g; s/]/%5D/g'
}

send_telegram_message() {
    local token="$1" chat_id="$2" message="$3" parse_mode="$4" disable_preview="$5" disable_notification="$6"
    
    local api_url="https://api.telegram.org/bot${token}/sendMessage"
    local post_data="chat_id=${chat_id}&text=$(url_encode "$message")"
    
    [[ -n "$parse_mode" ]] && post_data+="&parse_mode=${parse_mode}"
    [[ $disable_preview -eq 1 ]] && post_data+="&disable_web_page_preview=true"
    [[ $disable_notification -eq 1 ]] && post_data+="&disable_notification=true"
    
    local response http_code
    response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "$post_data" \
        "$api_url" 2>/dev/null)
    
    http_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | head -n -1)
    
    echo "$http_code:$response_body"
}

parse_telegram_response() {
    local response="$1"
    local success message_id error_code error_description
    
    # Extraction basique sans jq pour compatibilité
    if echo "$response" | grep -q '"ok":true'; then
        success="true"
        message_id=$(echo "$response" | grep -o '"message_id":[0-9]*' | cut -d: -f2 || echo "0")
        error_code=""
        error_description=""
    else
        success="false"
        message_id="0"
        error_code=$(echo "$response" | grep -o '"error_code":[0-9]*' | cut -d: -f2 || echo "0")
        error_description=$(echo "$response" | grep -o '"description":"[^"]*"' | cut -d'"' -f4 || echo "Unknown error")
    fi
    
    echo "$success:$message_id:$error_code:$error_description"
}

test_bot_connection() {
    local token="$1"
    local api_url="https://api.telegram.org/bot${token}/getMe"
    
    if curl -s --connect-timeout 10 "$api_url" | grep -q '"ok":true'; then
        return 0
    else
        return 1
    fi
}

main() {
    parse_args "$@"
    
    local errors=() warnings=()
    
    # Valider le token
    if ! validate_bot_token "$BOT_TOKEN"; then
        errors+=("Invalid bot token format")
    fi
    
    # Valider le mode de parsing
    if ! validate_parse_mode "$PARSE_MODE"; then
        errors+=("Invalid parse mode: $PARSE_MODE")
    fi
    
    # Vérifier curl
    if ! check_curl; then
        errors+=("curl command not found")
    fi
    
    # Valider chat ID (doit être numérique ou commencer par @)
    if [[ ! "$CHAT_ID" =~ ^-?[0-9]+$ ]] && [[ ! "$CHAT_ID" =~ ^@[a-zA-Z0-9_]+ ]]; then
        warnings+=("Chat ID format may be invalid")
    fi
    
    # Vérifier la longueur du message (limite Telegram: 4096 caractères)
    if [[ ${#MESSAGE} -gt 4096 ]]; then
        warnings+=("Message exceeds Telegram limit of 4096 characters")
    fi
    
    if [[ ${#errors[@]} -eq 0 ]]; then
        # Tester la connexion au bot si possible
        if ! test_bot_connection "$BOT_TOKEN"; then
            warnings+=("Cannot verify bot connection")
        fi
        
        local start_time end_time duration
        start_time=$(date +%s)
        
        # Envoyer le message
        local result http_code response_body parsed_result
        result=$(send_telegram_message "$BOT_TOKEN" "$CHAT_ID" "$MESSAGE" "$PARSE_MODE" "$DISABLE_PREVIEW" "$DISABLE_NOTIFICATION")
        IFS=':' read -r http_code response_body <<< "$result"
        
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        
        if [[ "$http_code" == "200" ]]; then
            parsed_result=$(parse_telegram_response "$response_body")
            IFS=':' read -r success message_id error_code error_description <<< "$parsed_result"
            
            if [[ "$success" == "true" ]]; then
                cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Telegram notification sent successfully",
  "data": {
    "bot_token": "$(echo "$BOT_TOKEN" | sed 's/:.*/:***/g')",
    "chat_id": "$CHAT_ID",
    "message_id": $message_id,
    "message_length": ${#MESSAGE},
    "parse_mode": "$PARSE_MODE",
    "disable_preview": $([ $DISABLE_PREVIEW -eq 1 ] && echo "true" || echo "false"),
    "disable_notification": $([ $DISABLE_NOTIFICATION -eq 1 ] && echo "true" || echo "false"),
    "http_code": $http_code,
    "duration_seconds": $duration
  },
  "errors": [],
  "warnings": [$(printf '"%s",' "${warnings[@]}" | sed 's/,$//')"]
}
EOF
            else
                errors+=("Telegram API error $error_code: $error_description")
            fi
        else
            errors+=("HTTP error $http_code")
        fi
    fi
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        cat << EOF
{
  "status": "error",
  "code": 1,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Telegram notification failed",
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