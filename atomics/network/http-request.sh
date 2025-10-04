#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: http-request.sh
# Description: Exécute des requêtes HTTP/HTTPS avec analyse complète des réponses
# Author: Generated with AtomicOps-Suite AI assistance  
# Version: 1.0
# Date: 2025-10-04
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# Level: 0 (Atomique)
# Dependencies: curl
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="http-request.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}

# Variables HTTP
HTTP_URL=""
HTTP_METHOD=${HTTP_METHOD:-"GET"}
HTTP_TIMEOUT=${HTTP_TIMEOUT:-30}
HTTP_HEADERS=()
HTTP_DATA=""
HTTP_FILE=""
FOLLOW_REDIRECTS=${FOLLOW_REDIRECTS:-1}
VERIFY_SSL=${VERIFY_SSL:-1}
USER_AGENT=${USER_AGENT:-"AtomicOps-Suite/1.0"}
MAX_REDIRECTS=${MAX_REDIRECTS:-10}

# Variables d'authentification
AUTH_TYPE=""  # basic|bearer|digest
AUTH_USER=""
AUTH_PASSWORD=""
AUTH_TOKEN=""

# Variables de résultat
HTTP_STATUS_CODE=0
HTTP_RESPONSE_TIME=0
HTTP_RESPONSE_SIZE=0
HTTP_RESPONSE_HEADERS=""
HTTP_RESPONSE_BODY=""
HTTP_FINAL_URL=""
REDIRECT_COUNT=0
SSL_INFO=""

# =============================================================================
# Fonctions Utilitaires et Logging
# =============================================================================

log_debug() {
    [[ $DEBUG -eq 0 ]] && return 0
    echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_info() {
    [[ $QUIET -eq 1 ]] && return 0
    [[ $JSON_ONLY -eq 1 ]] && return 0
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_warn() {
    [[ $QUIET -eq 1 ]] && return 0
    [[ $JSON_ONLY -eq 1 ]] && return 0
    echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

die() {
    log_error "$1"
    build_json_output "error" "${2:-1}" "$1"
    exit "${2:-1}"
}

# =============================================================================
# Fonctions d'Aide et de Parsing
# =============================================================================

show_help() {
    cat << 'EOF'
Usage: http-request.sh [OPTIONS] --url <url> [--method <method>]

Description:
    Exécute des requêtes HTTP/HTTPS et analyse les réponses. Supporte tous les
    methods HTTP, l'authentification, les headers personnalisés, et l'upload de
    fichiers. Fournit des métriques détaillées sur la performance.

Arguments obligatoires:
    --url <url>            URL complète à requêter (http:// ou https://)

Options principales:
    -h, --help             Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)

Options de requête:
    -m, --method <method>  Méthode HTTP (GET, POST, PUT, DELETE, HEAD, etc.)
    -t, --timeout <sec>    Timeout de requête en secondes (défaut: 30)
    -H, --header <header>  Header HTTP (format: "Name: Value") - répétable
    -d, --data <data>      Données à envoyer (POST/PUT)
    -f, --file <path>      Fichier à uploader
    --user-agent <agent>   User-Agent personnalisé

Options de redirection:
    --no-redirect          Ne pas suivre les redirections
    --max-redirects <n>    Nombre max de redirections (défaut: 10)

Options SSL/TLS:
    --no-verify-ssl        Ignorer les erreurs de certificat SSL
    
Options d'authentification:
    --auth-basic <user:pass>     Authentification Basic
    --auth-bearer <token>        Authentification Bearer Token
    --auth-digest <user:pass>    Authentification Digest

Variables d'environnement:
    HTTP_TIMEOUT           Timeout par défaut (défaut: 30)
    USER_AGENT             User-Agent par défaut
    VERIFY_SSL             Vérification SSL par défaut (défaut: 1)
    FOLLOW_REDIRECTS       Suivi des redirections (défaut: 1)

Sortie JSON:
    {
      "status": "success|error",
      "code": 0|1|2|3|4,
      "timestamp": "ISO8601",
      "script": "http-request.sh",
      "message": "Description du résultat",
      "data": {
        "request": {
          "url": "https://example.com/api",
          "method": "GET",
          "headers": {"User-Agent": "..."},
          "timeout": 30
        },
        "response": {
          "status_code": 200,
          "status_text": "OK",
          "headers": {"content-type": "application/json"},
          "body_size": 1234,
          "body": "response content"
        },
        "timing": {
          "total_time_ms": 1234,
          "connect_time_ms": 100,
          "ssl_time_ms": 200,
          "redirect_time_ms": 50
        },
        "redirects": {
          "count": 2,
          "final_url": "https://final.example.com"
        }
      }
    }

Codes de sortie:
    0 - Requête réussie (status 2xx)
    1 - Erreur de paramètres ou configuration
    2 - Erreur réseau ou timeout
    3 - Erreur HTTP (4xx, 5xx)
    4 - Erreur SSL/TLS

Exemples:
    # GET simple
    ./http-request.sh --url https://api.github.com/users/octocat
    
    # POST avec données JSON
    ./http-request.sh --url https://api.example.com/users \
        --method POST --header "Content-Type: application/json" \
        --data '{"name":"John","email":"john@example.com"}'
    
    # Authentification Bearer
    ./http-request.sh --url https://api.secure.com/data \
        --auth-bearer "eyJhbGciOiJIUzI1NiIs..."
    
    # Upload de fichier
    ./http-request.sh --url https://upload.example.com/files \
        --method POST --file ./document.pdf
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
                ;;
            -d|--debug)
                DEBUG=1
                VERBOSE=1
                ;;
            -q|--quiet)
                QUIET=1
                ;;
            -j|--json-only)
                JSON_ONLY=1
                QUIET=1
                ;;
            --url)
                [[ -z "${2:-}" ]] && die "Option --url nécessite une valeur" 1
                HTTP_URL="$2"
                shift
                ;;
            -m|--method)
                [[ -z "${2:-}" ]] && die "Option --method nécessite une valeur" 1
                HTTP_METHOD="$(echo "$2" | tr '[:lower:]' '[:upper:]')"
                shift
                ;;
            -t|--timeout)
                [[ -z "${2:-}" ]] && die "Option --timeout nécessite une valeur" 1
                HTTP_TIMEOUT="$2"
                shift
                ;;
            -H|--header)
                [[ -z "${2:-}" ]] && die "Option --header nécessite une valeur" 1
                HTTP_HEADERS+=("$2")
                shift
                ;;
            -d|--data)
                [[ -z "${2:-}" ]] && die "Option --data nécessite une valeur" 1
                HTTP_DATA="$2"
                shift
                ;;
            -f|--file)
                [[ -z "${2:-}" ]] && die "Option --file nécessite une valeur" 1
                HTTP_FILE="$2"
                shift
                ;;
            --user-agent)
                [[ -z "${2:-}" ]] && die "Option --user-agent nécessite une valeur" 1
                USER_AGENT="$2"
                shift
                ;;
            --no-redirect)
                FOLLOW_REDIRECTS=0
                ;;
            --max-redirects)
                [[ -z "${2:-}" ]] && die "Option --max-redirects nécessite une valeur" 1
                MAX_REDIRECTS="$2"
                shift
                ;;
            --no-verify-ssl)
                VERIFY_SSL=0
                ;;
            --auth-basic)
                [[ -z "${2:-}" ]] && die "Option --auth-basic nécessite une valeur" 1
                AUTH_TYPE="basic"
                if [[ "$2" =~ ^([^:]+):(.*)$ ]]; then
                    AUTH_USER="${BASH_REMATCH[1]}"
                    AUTH_PASSWORD="${BASH_REMATCH[2]}"
                else
                    die "Format --auth-basic invalide (utilisez user:password)" 1
                fi
                shift
                ;;
            --auth-bearer)
                [[ -z "${2:-}" ]] && die "Option --auth-bearer nécessite une valeur" 1
                AUTH_TYPE="bearer"
                AUTH_TOKEN="$2"
                shift
                ;;
            --auth-digest)
                [[ -z "${2:-}" ]] && die "Option --auth-digest nécessite une valeur" 1
                AUTH_TYPE="digest"
                if [[ "$2" =~ ^([^:]+):(.*)$ ]]; then
                    AUTH_USER="${BASH_REMATCH[1]}"
                    AUTH_PASSWORD="${BASH_REMATCH[2]}"
                else
                    die "Format --auth-digest invalide (utilisez user:password)" 1
                fi
                shift
                ;;
            -*)
                die "Option inconnue: $1" 1
                ;;
            *)
                die "Argument non attendu: $1" 1
                ;;
        esac
        shift
    done
}

# =============================================================================
# Fonctions de Validation
# =============================================================================

validate_prerequisites() {
    log_debug "Validation des prérequis système..."
    
    # Vérification de curl
    if ! command -v curl >/dev/null 2>&1; then
        die "Commande 'curl' non trouvée" 1
    fi
    
    # Validation des paramètres obligatoires
    [[ -z "$HTTP_URL" ]] && die "Paramètre --url obligatoire" 1
    
    # Validation de l'URL
    if [[ ! "$HTTP_URL" =~ ^https?:// ]]; then
        die "URL invalide: $HTTP_URL (doit commencer par http:// ou https://)" 1
    fi
    
    # Validation de la méthode HTTP
    case "$HTTP_METHOD" in
        GET|POST|PUT|DELETE|HEAD|PATCH|OPTIONS|TRACE|CONNECT)
            ;;
        *)
            die "Méthode HTTP non supportée: $HTTP_METHOD" 1
            ;;
    esac
    
    # Validation du timeout
    if [[ ! "$HTTP_TIMEOUT" =~ ^[0-9]+$ ]] || [[ $HTTP_TIMEOUT -lt 1 ]]; then
        die "Timeout invalide: $HTTP_TIMEOUT (doit être >= 1)" 1
    fi
    
    # Validation du fichier si spécifié
    if [[ -n "$HTTP_FILE" ]] && [[ ! -r "$HTTP_FILE" ]]; then
        die "Fichier non accessible: $HTTP_FILE" 1
    fi
    
    # Validation des redirections
    if [[ ! "$MAX_REDIRECTS" =~ ^[0-9]+$ ]] || [[ $MAX_REDIRECTS -lt 0 ]]; then
        die "Nombre max de redirections invalide: $MAX_REDIRECTS" 1
    fi
    
    # Conflits de données
    if [[ -n "$HTTP_DATA" ]] && [[ -n "$HTTP_FILE" ]]; then
        die "Ne peut pas utiliser --data et --file simultanément" 1
    fi
    
    log_debug "Validation réussie"
    log_info "Requête $HTTP_METHOD vers: $HTTP_URL"
    
    return 0
}

# =============================================================================
# Fonctions Principales
# =============================================================================

# Construction des options curl
build_curl_options() {
    local curl_options=()
    
    # Options de base
    curl_options+=(
        --location  # Suivre les redirections si activé
        --max-time "$HTTP_TIMEOUT"
        --user-agent "$USER_AGENT"
        --request "$HTTP_METHOD"
        --write-out '%{json}'  # Statistiques en JSON
        --silent
        --show-error
    )
    
    # Gestion des redirections
    if [[ $FOLLOW_REDIRECTS -eq 1 ]]; then
        curl_options+=(--max-redirs "$MAX_REDIRECTS")
    else
        curl_options+=(--max-redirs 0)
    fi
    
    # SSL/TLS
    if [[ $VERIFY_SSL -eq 0 ]]; then
        curl_options+=(--insecure)
    fi
    
    # Headers personnalisés
    for header in "${HTTP_HEADERS[@]}"; do
        curl_options+=(--header "$header")
    done
    
    # Authentification
    case "$AUTH_TYPE" in
        basic)
            curl_options+=(--user "$AUTH_USER:$AUTH_PASSWORD")
            ;;
        bearer)
            curl_options+=(--header "Authorization: Bearer $AUTH_TOKEN")
            ;;
        digest)
            curl_options+=(--digest --user "$AUTH_USER:$AUTH_PASSWORD")
            ;;
    esac
    
    # Données ou fichier
    if [[ -n "$HTTP_DATA" ]]; then
        curl_options+=(--data "$HTTP_DATA")
    elif [[ -n "$HTTP_FILE" ]]; then
        curl_options+=(--data-binary "@$HTTP_FILE")
    fi
    
    echo "${curl_options[@]}"
}

# Exécution de la requête HTTP
execute_http_request() {
    log_debug "Exécution de la requête HTTP"
    
    # Fichiers temporaires pour les réponses
    local response_headers=$(mktemp)
    local response_body=$(mktemp)
    local curl_stats=$(mktemp)
    
    # Construction des options curl
    local curl_options
    IFS=' ' read -ra curl_options <<< "$(build_curl_options)"
    
    # Ajout des options pour capturer headers et body séparément
    curl_options+=(
        --dump-header "$response_headers"
        --output "$response_body"
    )
    
    log_debug "Exécution: curl ${curl_options[*]} '$HTTP_URL'"
    
    # Exécution de curl avec capture des statistiques
    local curl_exit_code=0
    local curl_stats_json=""
    
    if curl_stats_json=$(curl "${curl_options[@]}" "$HTTP_URL" 2>/dev/null); then
        curl_exit_code=0
    else
        curl_exit_code=$?
    fi
    
    # Analyse des résultats
    if [[ $curl_exit_code -eq 0 ]] && [[ -n "$curl_stats_json" ]]; then
        # Extraction des statistiques depuis le JSON de curl
        HTTP_STATUS_CODE=$(echo "$curl_stats_json" | grep -o '"http_code":[0-9]*' | cut -d: -f2 || echo "0")
        HTTP_RESPONSE_TIME=$(echo "$curl_stats_json" | grep -o '"time_total":[0-9.]*' | cut -d: -f2 || echo "0")
        HTTP_FINAL_URL=$(echo "$curl_stats_json" | grep -o '"url_effective":"[^"]*"' | cut -d'"' -f4 || echo "$HTTP_URL")
        REDIRECT_COUNT=$(echo "$curl_stats_json" | grep -o '"num_redirects":[0-9]*' | cut -d: -f2 || echo "0")
        
        # Conversion du temps en millisecondes
        HTTP_RESPONSE_TIME=$(echo "$HTTP_RESPONSE_TIME * 1000" | bc -l | cut -d. -f1 2>/dev/null || echo "0")
        
        # Lecture des headers et body
        if [[ -f "$response_headers" ]]; then
            HTTP_RESPONSE_HEADERS=$(cat "$response_headers" | grep -v "^$" || echo "")
        fi
        
        if [[ -f "$response_body" ]]; then
            HTTP_RESPONSE_BODY=$(cat "$response_body" || echo "")
            HTTP_RESPONSE_SIZE=$(wc -c < "$response_body" 2>/dev/null || echo "0")
        fi
        
        log_debug "Status: $HTTP_STATUS_CODE, Temps: ${HTTP_RESPONSE_TIME}ms, Taille: ${HTTP_RESPONSE_SIZE} octets"
        
        # Nettoyage des fichiers temporaires
        rm -f "$response_headers" "$response_body" "$curl_stats"
        
        # Détermination du succès basé sur le code de statut
        if [[ $HTTP_STATUS_CODE -ge 200 ]] && [[ $HTTP_STATUS_CODE -lt 300 ]]; then
            return 0  # Succès
        elif [[ $HTTP_STATUS_CODE -ge 400 ]] && [[ $HTTP_STATUS_CODE -lt 600 ]]; then
            return 3  # Erreur HTTP
        else
            return 2  # Erreur réseau
        fi
    else
        # Gestion des erreurs curl
        rm -f "$response_headers" "$response_body" "$curl_stats"
        
        case $curl_exit_code in
            6|7)
                log_error "Impossible de résoudre l'hôte ou de se connecter"
                return 2
                ;;
            28)
                log_error "Timeout de connexion"
                return 2
                ;;
            35|51|52|53|54|58|59|60|64|66|77|80|82|83|90|91)
                log_error "Erreur SSL/TLS"
                return 4
                ;;
            *)
                log_error "Erreur curl (code: $curl_exit_code)"
                return 2
                ;;
        esac
    fi
}

# Action principale du script
do_main_action() {
    log_debug "Démarrage de la requête HTTP"
    
    if execute_http_request; then
        log_info "Requête HTTP réussie (Status: $HTTP_STATUS_CODE)"
        return 0
    else
        local exec_exit_code=$?
        case $exec_exit_code in
            2)
                log_error "Erreur réseau ou timeout"
                return 2
                ;;
            3)
                log_error "Erreur HTTP (Status: $HTTP_STATUS_CODE)"
                return 3
                ;;
            4)
                log_error "Erreur SSL/TLS"
                return 4
                ;;
            *)
                log_error "Erreur lors de la requête HTTP"
                return 1
                ;;
        esac
    fi
}

# =============================================================================
# Fonction de Construction de Sortie JSON
# =============================================================================

build_json_output() {
    local status="$1"
    local exit_code="$2"
    local message="$3"
    local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')
    
    # Construction du JSON des headers de requête
    local request_headers_json="{"
    local first=1
    request_headers_json+="\"User-Agent\": \"$USER_AGENT\""
    
    for header in "${HTTP_HEADERS[@]}"; do
        if [[ "$header" =~ ^([^:]+):[[:space:]]*(.*)$ ]]; then
            local header_name="${BASH_REMATCH[1]}"
            local header_value="${BASH_REMATCH[2]}"
            request_headers_json+=", \"$header_name\": \"$header_value\""
        fi
    done
    request_headers_json+="}"
    
    # Extraction du status text depuis les headers de réponse
    local status_text="Unknown"
    if [[ -n "$HTTP_RESPONSE_HEADERS" ]]; then
        status_text=$(echo "$HTTP_RESPONSE_HEADERS" | head -1 | sed -n 's/^HTTP\/[0-9.]*[[:space:]]*[0-9]*[[:space:]]*\(.*\)$/\1/p' | tr -d '\r\n' || echo "Unknown")
    fi
    
    # Construction du JSON des headers de réponse
    local response_headers_json="{"
    first=1
    while IFS=': ' read -r header_name header_value; do
        [[ -z "$header_name" ]] && continue
        [[ "$header_name" =~ ^HTTP/ ]] && continue
        
        if [[ $first -eq 1 ]]; then
            first=0
        else
            response_headers_json+=", "
        fi
        
        # Nettoyage des valeurs
        header_name=$(echo "$header_name" | tr -d '\r\n')
        header_value=$(echo "$header_value" | tr -d '\r\n')
        
        response_headers_json+="\"$header_name\": \"$header_value\""
    done <<< "$HTTP_RESPONSE_HEADERS"
    response_headers_json+="}"
    
    # Échappement du body pour JSON
    local escaped_body=$(echo -n "$HTTP_RESPONSE_BODY" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' '\\' | sed 's/\\/\\n/g')
    
    cat << EOF
{
  "status": "$status",
  "code": $exit_code,
  "timestamp": "$timestamp",
  "script": "$SCRIPT_NAME",
  "message": "$message",
  "data": {
    "request": {
      "url": "$HTTP_URL",
      "method": "$HTTP_METHOD",
      "headers": $request_headers_json,
      "timeout": $HTTP_TIMEOUT,
      "follow_redirects": $([ $FOLLOW_REDIRECTS -eq 1 ] && echo "true" || echo "false"),
      "verify_ssl": $([ $VERIFY_SSL -eq 1 ] && echo "true" || echo "false")
    },
    "response": {
      "status_code": $HTTP_STATUS_CODE,
      "status_text": "$status_text",
      "headers": $response_headers_json,
      "body_size": $HTTP_RESPONSE_SIZE,
      "body": "$escaped_body"
    },
    "timing": {
      "total_time_ms": $HTTP_RESPONSE_TIME
    },
    "redirects": {
      "count": $REDIRECT_COUNT,
      "final_url": "$HTTP_FINAL_URL"
    },
    "authentication": {
      "type": "${AUTH_TYPE:-none}",
      "used": $([ -n "$AUTH_TYPE" ] && echo "true" || echo "false")
    }
  }
}
EOF
}

# =============================================================================
# Fonction de Nettoyage
# =============================================================================

cleanup() {
    log_debug "Nettoyage des ressources"
    # Supprimer les fichiers temporaires
    rm -f /tmp/curl_* /tmp/http_* 2>/dev/null || true
}

# =============================================================================
# Point d'Entrée Principal
# =============================================================================

main() {
    # Configuration du trap pour le nettoyage
    trap cleanup EXIT ERR INT TERM
    
    # Parsing des arguments
    parse_args "$@"
    
    # Validation des prérequis
    validate_prerequisites
    
    # Exécution de l'action principale
    local exit_code=0
    local result_message="Requête HTTP exécutée avec succès"
    
    if do_main_action; then
        result_message="Requête HTTP réussie (Status: $HTTP_STATUS_CODE)"
        exit_code=0
    else
        local action_exit_code=$?
        case $action_exit_code in
            2)
                result_message="Erreur réseau ou timeout HTTP"
                exit_code=2
                ;;
            3)
                result_message="Erreur HTTP (Status: $HTTP_STATUS_CODE)"
                exit_code=3
                ;;
            4)
                result_message="Erreur SSL/TLS"
                exit_code=4
                ;;
            *)
                result_message="Erreur lors de la requête HTTP"
                exit_code=1
                ;;
        esac
    fi
    
    # Génération de la sortie JSON
    build_json_output \
        "$([ $exit_code -eq 0 ] && echo "success" || echo "error")" \
        "$exit_code" \
        "$result_message"
    
    exit $exit_code
}

# Exécution du script si appelé directement
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi