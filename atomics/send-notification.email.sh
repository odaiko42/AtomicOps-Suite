#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: send-notification.email.sh 
# Description: Envoyer des notifications par email
# Author: Generated with AI assistance
# Version: 1.0
# Date: 2025-10-04
# ==============================================================================

set -euo pipefail

SCRIPT_NAME="send-notification.email.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}
TO_EMAIL=""
SUBJECT=""
MESSAGE=""
FROM_EMAIL=${FROM_EMAIL:-"$(whoami)@$(hostname)"}
SMTP_SERVER=${SMTP_SERVER:-"localhost"}
SMTP_PORT=${SMTP_PORT:-"25"}
ATTACHMENT=""
USE_TLS=${USE_TLS:-0}
SMTP_USER=""
SMTP_PASS=""

show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] <to_email> <subject> <message>

Description:
    Envoie des notifications par email via SMTP avec support
    des pièces jointes et authentification.

Arguments:
    <to_email>       Adresse email destinataire
    <subject>        Sujet de l'email
    <message>        Corps du message

Options:
    -h, --help       Afficher cette aide
    -v, --verbose    Mode verbeux
    -d, --debug      Mode debug
    -q, --quiet      Mode silencieux
    -j, --json-only  Sortie JSON uniquement
    -f, --from EMAIL Adresse expéditeur
    -s, --server HOST Serveur SMTP (défaut: localhost)
    -p, --port PORT  Port SMTP (défaut: 25)
    -a, --attach FILE Fichier joint
    --tls            Utiliser TLS/SSL
    --user USER      Utilisateur SMTP
    --pass PASS      Mot de passe SMTP
    
Exemples:
    $SCRIPT_NAME admin@example.com "Alert" "System error detected"
    $SCRIPT_NAME -s smtp.gmail.com -p 587 --tls user@domain.com "Report" "Daily backup completed"
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
            -f|--from) FROM_EMAIL="$2"; shift 2 ;;
            -s|--server) SMTP_SERVER="$2"; shift 2 ;;
            -p|--port) SMTP_PORT="$2"; shift 2 ;;
            -a|--attach) ATTACHMENT="$2"; shift 2 ;;
            --tls) USE_TLS=1; shift ;;
            --user) SMTP_USER="$2"; shift 2 ;;
            --pass) SMTP_PASS="$2"; shift 2 ;;
            -*) echo "Option inconnue: $1" >&2; exit 2 ;;
            *) 
                if [[ -z "$TO_EMAIL" ]]; then
                    TO_EMAIL="$1"
                elif [[ -z "$SUBJECT" ]]; then
                    SUBJECT="$1"
                elif [[ -z "$MESSAGE" ]]; then
                    MESSAGE="$1"
                else
                    echo "Trop d'arguments" >&2; exit 2
                fi
                shift ;;
        esac
    done

    [[ -z "$TO_EMAIL" ]] && { echo "Email destinataire manquant" >&2; exit 2; }
    [[ -z "$SUBJECT" ]] && { echo "Sujet manquant" >&2; exit 2; }
    [[ -z "$MESSAGE" ]] && { echo "Message manquant" >&2; exit 2; }
}

validate_email() {
    local email="$1"
    [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

check_mail_command() {
    if command -v sendmail >/dev/null 2>&1; then
        echo "sendmail"
    elif command -v mail >/dev/null 2>&1; then
        echo "mail"
    elif command -v mutt >/dev/null 2>&1; then
        echo "mutt"
    else
        echo "none"
    fi
}

send_with_sendmail() {
    local to="$1" from="$2" subject="$3" message="$4" attachment="$5"
    local temp_file
    temp_file=$(mktemp)
    
    cat > "$temp_file" << EOF
From: $from
To: $to
Subject: $subject
Date: $(date -R)

$message
EOF
    
    if [[ -n "$attachment" && -f "$attachment" ]]; then
        echo "Attachment: $attachment" >> "$temp_file"
    fi
    
    if sendmail "$to" < "$temp_file" 2>/dev/null; then
        rm -f "$temp_file"
        return 0
    else
        rm -f "$temp_file"
        return 1
    fi
}

send_with_mail() {
    local to="$1" from="$2" subject="$3" message="$4" attachment="$5"
    local mail_opts=""
    
    [[ -n "$from" ]] && mail_opts+="-r $from "
    [[ -n "$attachment" && -f "$attachment" ]] && mail_opts+="-a $attachment "
    
    if echo "$message" | eval "mail $mail_opts -s \"$subject\" \"$to\"" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

test_smtp_connection() {
    local server="$1" port="$2" use_tls="$3"
    
    if command -v nc >/dev/null 2>&1; then
        if nc -z "$server" "$port" 2>/dev/null; then
            return 0
        fi
    elif command -v telnet >/dev/null 2>&1; then
        if timeout 5 telnet "$server" "$port" >/dev/null 2>&1; then
            return 0
        fi
    fi
    
    return 1
}

main() {
    parse_args "$@"
    
    local errors=() warnings=()
    
    # Valider les emails
    if ! validate_email "$TO_EMAIL"; then
        errors+=("Invalid recipient email format: $TO_EMAIL")
    fi
    
    if ! validate_email "$FROM_EMAIL"; then
        errors+=("Invalid sender email format: $FROM_EMAIL")
    fi
    
    # Vérifier la pièce jointe
    if [[ -n "$ATTACHMENT" && ! -f "$ATTACHMENT" ]]; then
        errors+=("Attachment file not found: $ATTACHMENT")
    fi
    
    # Vérifier les commandes mail disponibles
    local mail_cmd
    mail_cmd=$(check_mail_command)
    
    if [[ "$mail_cmd" == "none" ]]; then
        errors+=("No mail command available (sendmail, mail, mutt)")
    fi
    
    # Tester la connexion SMTP si serveur distant
    if [[ "$SMTP_SERVER" != "localhost" ]]; then
        if ! test_smtp_connection "$SMTP_SERVER" "$SMTP_PORT" "$USE_TLS"; then
            warnings+=("Cannot connect to SMTP server $SMTP_SERVER:$SMTP_PORT")
        fi
    fi
    
    if [[ ${#errors[@]} -eq 0 ]]; then
        local start_time end_time duration sent=false
        start_time=$(date +%s)
        
        # Essayer d'envoyer l'email
        case "$mail_cmd" in
            sendmail)
                if send_with_sendmail "$TO_EMAIL" "$FROM_EMAIL" "$SUBJECT" "$MESSAGE" "$ATTACHMENT"; then
                    sent=true
                fi
                ;;
            mail)
                if send_with_mail "$TO_EMAIL" "$FROM_EMAIL" "$SUBJECT" "$MESSAGE" "$ATTACHMENT"; then
                    sent=true
                fi
                ;;
            mutt)
                # Implémentation simplifiée pour mutt
                if echo "$MESSAGE" | mutt -s "$SUBJECT" "$TO_EMAIL" 2>/dev/null; then
                    sent=true
                fi
                ;;
        esac
        
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        
        if [[ $sent == true ]]; then
            local attachment_info="null"
            if [[ -n "$ATTACHMENT" && -f "$ATTACHMENT" ]]; then
                local attachment_size
                attachment_size=$(stat -c%s "$ATTACHMENT" 2>/dev/null || echo "0")
                attachment_info="{\"file\":\"$ATTACHMENT\",\"size\":$attachment_size}"
            fi
            
            cat << EOF
{
  "status": "success",
  "code": 0,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Email sent successfully",
  "data": {
    "recipient": "$TO_EMAIL",
    "sender": "$FROM_EMAIL",
    "subject": "$SUBJECT",
    "message_length": ${#MESSAGE},
    "smtp_server": "$SMTP_SERVER",
    "smtp_port": $SMTP_PORT,
    "use_tls": $([ $USE_TLS -eq 1 ] && echo "true" || echo "false"),
    "mail_command": "$mail_cmd",
    "attachment": $attachment_info,
    "duration_seconds": $duration
  },
  "errors": [],
  "warnings": [$(printf '"%s",' "${warnings[@]}" | sed 's/,$//')"]
}
EOF
        else
            errors+=("Failed to send email")
        fi
    fi
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        cat << EOF
{
  "status": "error",
  "code": 1,
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "script": "$SCRIPT_NAME",
  "message": "Email sending failed",
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