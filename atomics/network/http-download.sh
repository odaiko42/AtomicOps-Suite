#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: http-download.sh
# Description: Script atomique pour téléchargement de fichiers via HTTP/HTTPS
# Author: Generated with AtomicOps-Suite AI assistance
# Version: 1.0
# Date: 2025-10-04
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# Level: 0 (Atomique)
# Dependencies: curl ou wget, bc
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="http-download.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}

# Configuration HTTP
HTTP_URL=""
LOCAL_FILE=""
REQUEST_TIMEOUT=60
MAX_REDIRECTS=10
USER_AGENT="AtomicOps-Suite/1.0"
VERIFY_SSL=1

# Authentification
AUTH_TYPE=""  # basic, bearer, digest
AUTH_USER=""
AUTH_PASSWORD=""
AUTH_TOKEN=""

# Options de téléchargement
RESUME_DOWNLOAD=0
OVERWRITE_FILE=0
CREATE_DIRS=1
PROGRESS_BAR=0
BANDWIDTH_LIMIT=""  # en KB/s

# Variables de résultat
DOWNLOAD_SUCCESS=0
FILE_SIZE=0
DOWNLOAD_SPEED=0
DOWNLOAD_TIME=0
HTTP_STATUS_CODE=0
CONTENT_TYPE=""
FINAL_URL=""
RESUME_OFFSET=0

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
Usage: http-download.sh --url <url> --output <file> [OPTIONS]

Description:
    Script atomique pour téléchargement de fichiers via HTTP/HTTPS.
    Supporte l'authentification, la reprise de téléchargement et la limitation de bande passante.

Arguments obligatoires:
    --url <url>            URL du fichier à télécharger
    --output <file>        Fichier local de destination

Options:
    -h, --help            Afficher cette aide
    -v, --verbose         Mode verbeux (affichage détaillé)
    -d, --debug           Mode debug (informations de débogage)
    -q, --quiet           Mode silencieux (erreurs seulement)
    -j, --json-only       Sortie JSON uniquement (sans logs)

Options HTTP:
    --timeout <seconds>   Timeout de téléchargement (défaut: 60)
    --max-redirects <n>   Nombre max de redirections (défaut: 10)
    --user-agent <ua>     User-Agent HTTP (défaut: AtomicOps-Suite/1.0)
    --no-verify-ssl      Désactiver vérification certificat SSL
    --header <header>     Header HTTP personnalisé (peut être répété)

Options d'authentification:
    --auth-basic <user:pass>    Authentification HTTP Basic
    --auth-bearer <token>       Authentification Bearer Token
    --auth-digest <user:pass>   Authentification HTTP Digest

Options de téléchargement:
    --resume              Reprendre téléchargement interrompu
    --overwrite           Écraser fichier existant
    --no-create-dirs      Ne pas créer répertoires de destination
    --progress            Afficher barre de progression
    --limit <kbps>        Limiter bande passante (KB/s)

Variables d'environnement:
    HTTP_TIMEOUT          Timeout par défaut (60)
    HTTP_USER_AGENT       User-Agent par défaut
    HTTP_VERIFY_SSL       Vérification SSL par défaut (1)

Sortie JSON:
    {
      "status": "success|error",
      "code": 0|1|2|3,
      "timestamp": "ISO8601",
      "script": "http-download.sh",
      "message": "Description du résultat",
      "data": {
        "request": {
          "url": "https://example.com/file.zip",
          "final_url": "https://cdn.example.com/file.zip",
          "user_agent": "AtomicOps-Suite/1.0",
          "timeout": 60,
          "ssl_verified": true
        },
        "response": {
          "status_code": 200,
          "content_type": "application/zip",
          "content_length": 1048576,
          "redirects": 1
        },
        "download": {
          "local_file": "/path/to/file.zip",
          "successful": true,
          "resumed": false,
          "resume_offset": 0,
          "overwritten": false
        },
        "performance": {
          "size_bytes": 1048576,
          "duration_ms": 2345,
          "speed_kbps": 3456.78,
          "avg_speed_mbps": 3.37
        }
      }
    }

Codes de sortie:
    0 - Téléchargement réussi
    1 - Erreur de paramètres ou configuration
    2 - Erreur de connexion HTTP
    3 - Erreur de téléchargement

Exemples:
    # Téléchargement simple HTTPS
    ./http-download.sh \
        --url https://example.com/archive.zip \
        --output ./downloads/archive.zip

    # Téléchargement avec authentification Bearer
    ./http-download.sh \
        --url https://api.example.com/files/document.pdf \
        --output ./document.pdf \
        --auth-bearer "eyJhbGciOiJIUzI1NiIs..."

    # Téléchargement avec reprise et limitation bande passante
    ./http-download.sh \
        --url https://download.example.com/large-file.iso \
        --output ./large-file.iso \
        --resume --limit 1024 --progress

    # Téléchargement avec authentification Basic
    ./http-download.sh \
        --url https://secure.example.com/private/file.tar.gz \
        --output ./private-file.tar.gz \
        --auth-basic "username:password"
EOF
}

parse_args() {
    local custom_headers=()
    
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
            --output)
                [[ -z "${2:-}" ]] && die "Option --output nécessite une valeur" 1
                LOCAL_FILE="$2"
                shift
                ;;
            --timeout)
                [[ -z "${2:-}" ]] && die "Option --timeout nécessite une valeur" 1
                REQUEST_TIMEOUT="$2"
                shift
                ;;
            --max-redirects)
                [[ -z "${2:-}" ]] && die "Option --max-redirects nécessite une valeur" 1
                MAX_REDIRECTS="$2"
                shift
                ;;
            --user-agent)
                [[ -z "${2:-}" ]] && die "Option --user-agent nécessite une valeur" 1
                USER_AGENT="$2"
                shift
                ;;
            --no-verify-ssl)
                VERIFY_SSL=0
                ;;
            --header)
                [[ -z "${2:-}" ]] && die "Option --header nécessite une valeur" 1
                custom_headers+=("$2")
                shift
                ;;
            --auth-basic)
                [[ -z "${2:-}" ]] && die "Option --auth-basic nécessite une valeur" 1
                AUTH_TYPE="basic"
                if [[ "$2" == *":"* ]]; then
                    AUTH_USER="${2%%:*}"
                    AUTH_PASSWORD="${2#*:}"
                else
                    die "Format --auth-basic invalide (attendu: user:password)" 1
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
                if [[ "$2" == *":"* ]]; then
                    AUTH_USER="${2%%:*}"
                    AUTH_PASSWORD="${2#*:}"
                else
                    die "Format --auth-digest invalide (attendu: user:password)" 1
                fi
                shift
                ;;
            --resume)
                RESUME_DOWNLOAD=1
                ;;
            --overwrite)
                OVERWRITE_FILE=1
                ;;
            --no-create-dirs)
                CREATE_DIRS=0
                ;;
            --progress)
                PROGRESS_BAR=1
                ;;
            --limit)
                [[ -z "${2:-}" ]] && die "Option --limit nécessite une valeur" 1
                BANDWIDTH_LIMIT="$2"
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
    
    # Stockage des headers personnalisés pour usage global
    export CUSTOM_HEADERS="${custom_headers[*]}"
}

# =============================================================================
# Fonctions de Validation
# =============================================================================

validate_prerequisites() {
    log_debug "Validation des prérequis HTTP download..."
    
    # Vérification des outils de téléchargement
    local download_tool=""
    if command -v curl >/dev/null 2>&1; then
        download_tool="curl"
        log_debug "Outil de téléchargement: curl (recommandé)"
    elif command -v wget >/dev/null 2>&1; then
        download_tool="wget"
        log_debug "Outil de téléchargement: wget (alternatif)"
    else
        die "Aucun outil de téléchargement disponible (curl ou wget requis)" 1
    fi
    
    # Validation des paramètres obligatoires
    [[ -z "$HTTP_URL" ]] && die "Paramètre --url obligatoire" 1
    [[ -z "$LOCAL_FILE" ]] && die "Paramètre --output obligatoire" 1
    
    # Validation de l'URL
    if [[ ! "$HTTP_URL" =~ ^https?:// ]]; then
        die "URL invalide: $HTTP_URL (doit commencer par http:// ou https://)" 1
    fi
    
    # Validation des valeurs numériques
    if [[ ! "$REQUEST_TIMEOUT" =~ ^[0-9]+$ ]] || [[ $REQUEST_TIMEOUT -lt 5 ]]; then
        die "Timeout invalide: $REQUEST_TIMEOUT (minimum 5 secondes)" 1
    fi
    
    if [[ ! "$MAX_REDIRECTS" =~ ^[0-9]+$ ]] || [[ $MAX_REDIRECTS -gt 50 ]]; then
        die "Nombre de redirections invalide: $MAX_REDIRECTS (maximum 50)" 1
    fi
    
    if [[ -n "$BANDWIDTH_LIMIT" ]] && ! [[ "$BANDWIDTH_LIMIT" =~ ^[0-9]+$ ]]; then
        die "Limite de bande passante invalide: $BANDWIDTH_LIMIT" 1
    fi
    
    # Vérification du fichier de destination
    local output_dir=$(dirname "$LOCAL_FILE")
    
    if [[ -f "$LOCAL_FILE" ]]; then
        if [[ $OVERWRITE_FILE -eq 0 ]] && [[ $RESUME_DOWNLOAD -eq 0 ]]; then
            die "Fichier de destination existe déjà: $LOCAL_FILE (utilisez --overwrite ou --resume)" 1
        fi
        
        if [[ ! -w "$LOCAL_FILE" ]]; then
            die "Fichier de destination non accessible en écriture: $LOCAL_FILE" 1
        fi
        
        # Calcul de l'offset de reprise si applicable
        if [[ $RESUME_DOWNLOAD -eq 1 ]]; then
            RESUME_OFFSET=$(stat -c%s "$LOCAL_FILE" 2>/dev/null || stat -f%z "$LOCAL_FILE" 2>/dev/null || echo 0)
            log_debug "Reprise de téléchargement à partir de $RESUME_OFFSET octets"
        fi
    else
        if [[ $CREATE_DIRS -eq 1 ]] && [[ ! -d "$output_dir" ]]; then
            if ! mkdir -p "$output_dir" 2>/dev/null; then
                die "Impossible de créer le répertoire de destination: $output_dir" 1
            fi
        fi
        
        if [[ ! -d "$output_dir" ]]; then
            die "Répertoire de destination inexistant: $output_dir" 1
        fi
        
        if [[ ! -w "$output_dir" ]]; then
            die "Répertoire de destination non accessible en écriture: $output_dir" 1
        fi
    fi
    
    # Vérification de bc pour les calculs
    if ! command -v bc >/dev/null 2>&1; then
        log_warn "Commande 'bc' non disponible - Calculs de vitesse approximatifs"
    fi
    
    log_debug "Validation réussie"
    log_info "Téléchargement HTTP de $HTTP_URL vers $LOCAL_FILE"
    
    return 0
}

# =============================================================================
# Fonctions de Téléchargement
# =============================================================================

# Téléchargement avec curl (méthode recommandée)
download_with_curl() {
    log_debug "Téléchargement HTTP avec curl"
    
    local start_time=$(date +%s%3N)
    local curl_args=()
    
    # Configuration de base
    curl_args+=(
        "--location"  # Suivre les redirections
        "--max-redirs" "$MAX_REDIRECTS"
        "--connect-timeout" "$REQUEST_TIMEOUT"
        "--max-time" "$((REQUEST_TIMEOUT * 3))"
        "--user-agent" "$USER_AGENT"
        "--fail"  # Échouer sur les erreurs HTTP
        "--silent"  # Mode silencieux pour JSON
        "--show-error"  # Afficher les erreurs même en mode silencieux
    )
    
    # Configuration SSL
    if [[ $VERIFY_SSL -eq 0 ]]; then
        curl_args+=("--insecure")
    fi
    
    # Configuration de l'authentification
    case "$AUTH_TYPE" in
        "basic")
            curl_args+=("--basic" "--user" "$AUTH_USER:$AUTH_PASSWORD")
            ;;
        "digest")
            curl_args+=("--digest" "--user" "$AUTH_USER:$AUTH_PASSWORD")
            ;;
        "bearer")
            curl_args+=("--header" "Authorization: Bearer $AUTH_TOKEN")
            ;;
    esac
    
    # Headers personnalisés
    if [[ -n "${CUSTOM_HEADERS:-}" ]]; then
        IFS=' ' read -ra headers_array <<< "$CUSTOM_HEADERS"
        for header in "${headers_array[@]}"; do
            curl_args+=("--header" "$header")
        done
    fi
    
    # Configuration de la reprise
    if [[ $RESUME_DOWNLOAD -eq 1 ]] && [[ $RESUME_OFFSET -gt 0 ]]; then
        curl_args+=("--continue-at" "$RESUME_OFFSET")
    fi
    
    # Configuration de la limitation de bande passante
    if [[ -n "$BANDWIDTH_LIMIT" ]]; then
        # curl accepte la limitation en octets/seconde
        local limit_bytes=$((BANDWIDTH_LIMIT * 1024))
        curl_args+=("--limit-rate" "${limit_bytes}")
    fi
    
    # Configuration du fichier de sortie
    curl_args+=("--output" "$LOCAL_FILE")
    
    # Barre de progression si demandée et mode non silencieux
    if [[ $PROGRESS_BAR -eq 1 ]] && [[ $QUIET -eq 0 ]] && [[ $JSON_ONLY -eq 0 ]]; then
        curl_args=(${curl_args[@]/--silent/})  # Retirer --silent
        curl_args+=("--progress-bar")
    fi
    
    # Headers de réponse pour l'analyse
    local temp_headers=$(mktemp)
    curl_args+=("--dump-header" "$temp_headers")
    
    # URL de téléchargement
    curl_args+=("$HTTP_URL")
    
    # Exécution de curl
    log_debug "Commande curl: curl ${curl_args[*]}"
    
    local curl_output=""
    local curl_exit_code=0
    
    if curl_output=$(curl "${curl_args[@]}" 2>&1); then
        curl_exit_code=0
    else
        curl_exit_code=$?
    fi
    
    local end_time=$(date +%s%3N)
    DOWNLOAD_TIME=$((end_time - start_time))
    
    if [[ $curl_exit_code -eq 0 ]]; then
        # Analyse des headers de réponse
        if [[ -f "$temp_headers" ]]; then
            HTTP_STATUS_CODE=$(head -n1 "$temp_headers" | awk '{print $2}')
            CONTENT_TYPE=$(grep -i "^content-type:" "$temp_headers" | cut -d: -f2- | tr -d ' \r')
            FINAL_URL=$(grep -i "^location:" "$temp_headers" | tail -n1 | cut -d: -f2- | tr -d ' \r')
        fi
        
        # Si pas d'URL finale trouvée, utiliser l'URL originale
        [[ -z "$FINAL_URL" ]] && FINAL_URL="$HTTP_URL"
        
        # Calcul de la taille du fichier téléchargé
        FILE_SIZE=$(stat -c%s "$LOCAL_FILE" 2>/dev/null || stat -f%z "$LOCAL_FILE" 2>/dev/null || echo 0)
        
        # Calcul de la vitesse de téléchargement
        if [[ $DOWNLOAD_TIME -gt 0 ]]; then
            DOWNLOAD_SPEED=$(((FILE_SIZE - RESUME_OFFSET) * 1000 / DOWNLOAD_TIME))  # octets/sec
            DOWNLOAD_SPEED=$((DOWNLOAD_SPEED / 1024))  # KB/s
        fi
        
        DOWNLOAD_SUCCESS=1
        log_info "Téléchargement curl réussi (${DOWNLOAD_TIME}ms, ${DOWNLOAD_SPEED} KB/s)"
        
        # Nettoyage du fichier temporaire des headers
        rm -f "$temp_headers"
        
        return 0
    else
        log_error "Échec téléchargement curl (code: $curl_exit_code): $curl_output"
        
        # Nettoyage du fichier temporaire des headers
        rm -f "$temp_headers"
        
        # Analyse du code d'erreur curl
        case $curl_exit_code in
            6|7) return 2 ;;  # Erreur de résolution/connexion
            22|23) return 2 ;;  # Erreur HTTP
            *) return 3 ;;  # Autre erreur de téléchargement
        esac
    fi
}

# Téléchargement avec wget (méthode alternative)
download_with_wget() {
    log_debug "Téléchargement HTTP avec wget"
    
    local start_time=$(date +%s%3N)
    local wget_args=()
    
    # Configuration de base
    wget_args+=(
        "--timeout=$REQUEST_TIMEOUT"
        "--tries=3"
        "--user-agent=$USER_AGENT"
        "--max-redirect=$MAX_REDIRECTS"
        "--quiet"  # Mode silencieux pour JSON
    )
    
    # Configuration SSL
    if [[ $VERIFY_SSL -eq 0 ]]; then
        wget_args+=("--no-check-certificate")
    fi
    
    # Configuration de l'authentification
    case "$AUTH_TYPE" in
        "basic"|"digest")
            wget_args+=("--user=$AUTH_USER" "--password=$AUTH_PASSWORD")
            if [[ "$AUTH_TYPE" == "digest" ]]; then
                wget_args+=("--auth-no-challenge")
            fi
            ;;
        "bearer")
            wget_args+=("--header=Authorization: Bearer $AUTH_TOKEN")
            ;;
    esac
    
    # Headers personnalisés
    if [[ -n "${CUSTOM_HEADERS:-}" ]]; then
        IFS=' ' read -ra headers_array <<< "$CUSTOM_HEADERS"
        for header in "${headers_array[@]}"; do
            wget_args+=("--header=$header")
        done
    fi
    
    # Configuration de la reprise
    if [[ $RESUME_DOWNLOAD -eq 1 ]]; then
        wget_args+=("--continue")
    fi
    
    # Configuration de la limitation de bande passante
    if [[ -n "$BANDWIDTH_LIMIT" ]]; then
        wget_args+=("--limit-rate=${BANDWIDTH_LIMIT}k")
    fi
    
    # Barre de progression si demandée
    if [[ $PROGRESS_BAR -eq 1 ]] && [[ $QUIET -eq 0 ]] && [[ $JSON_ONLY -eq 0 ]]; then
        wget_args=(${wget_args[@]/--quiet/})  # Retirer --quiet
        wget_args+=("--progress=bar")
    fi
    
    # Configuration du fichier de sortie
    wget_args+=("--output-document=$LOCAL_FILE")
    
    # URL de téléchargement
    wget_args+=("$HTTP_URL")
    
    # Exécution de wget
    log_debug "Commande wget: wget ${wget_args[*]}"
    
    local wget_output=""
    local wget_exit_code=0
    
    if wget_output=$(wget "${wget_args[@]}" 2>&1); then
        wget_exit_code=0
    else
        wget_exit_code=$?
    fi
    
    local end_time=$(date +%s%3N)
    DOWNLOAD_TIME=$((end_time - start_time))
    
    if [[ $wget_exit_code -eq 0 ]]; then
        # Calcul de la taille du fichier téléchargé
        FILE_SIZE=$(stat -c%s "$LOCAL_FILE" 2>/dev/null || stat -f%z "$LOCAL_FILE" 2>/dev/null || echo 0)
        
        # Calcul de la vitesse de téléchargement
        if [[ $DOWNLOAD_TIME -gt 0 ]]; then
            DOWNLOAD_SPEED=$(((FILE_SIZE - RESUME_OFFSET) * 1000 / DOWNLOAD_TIME))  # octets/sec
            DOWNLOAD_SPEED=$((DOWNLOAD_SPEED / 1024))  # KB/s
        fi
        
        # Simulation des informations HTTP (wget ne les expose pas facilement)
        HTTP_STATUS_CODE=200
        FINAL_URL="$HTTP_URL"
        
        DOWNLOAD_SUCCESS=1
        log_info "Téléchargement wget réussi (${DOWNLOAD_TIME}ms, ${DOWNLOAD_SPEED} KB/s)"
        return 0
    else
        log_error "Échec téléchargement wget (code: $wget_exit_code): $wget_output"
        
        # Analyse du code d'erreur wget
        case $wget_exit_code in
            4|5|6) return 2 ;;  # Erreur de réseau/DNS/SSL
            8) return 2 ;;  # Erreur HTTP
            *) return 3 ;;  # Autre erreur
        esac
    fi
}

# Fonction principale de téléchargement
perform_download() {
    log_debug "Démarrage du téléchargement HTTP"
    
    # Choix de la méthode de téléchargement selon les outils disponibles
    local download_method=""
    local download_result=0
    
    if command -v curl >/dev/null 2>&1; then
        download_method="curl"
        download_with_curl
        download_result=$?
    elif command -v wget >/dev/null 2>&1; then
        download_method="wget"
        download_with_wget
        download_result=$?
    else
        die "Aucun outil de téléchargement disponible" 1
    fi
    
    if [[ $download_result -eq 0 ]]; then
        log_info "Téléchargement réussi avec $download_method"
        return 0
    else
        log_error "Échec du téléchargement avec $download_method"
        return $download_result
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
    
    # Calcul des métriques de performance
    local avg_speed_mbps=0
    if [[ $DOWNLOAD_SPEED -gt 0 ]]; then
        avg_speed_mbps=$(echo "scale=2; $DOWNLOAD_SPEED / 1024" | bc 2>/dev/null || echo "0")
    fi
    
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
      "final_url": "${FINAL_URL:-$HTTP_URL}",
      "user_agent": "$USER_AGENT",
      "timeout": $REQUEST_TIMEOUT,
      "max_redirects": $MAX_REDIRECTS,
      "ssl_verified": $([ $VERIFY_SSL -eq 1 ] && echo "true" || echo "false"),
      "auth_type": "${AUTH_TYPE:-null}"
    },
    "response": {
      "status_code": ${HTTP_STATUS_CODE:-0},
      "content_type": "${CONTENT_TYPE:-null}",
      "content_length": $FILE_SIZE
    },
    "download": {
      "local_file": "$LOCAL_FILE",
      "successful": $([ $DOWNLOAD_SUCCESS -eq 1 ] && echo "true" || echo "false"),
      "resumed": $([ $RESUME_DOWNLOAD -eq 1 ] && echo "true" || echo "false"),
      "resume_offset": $RESUME_OFFSET,
      "overwrite_allowed": $([ $OVERWRITE_FILE -eq 1 ] && echo "true" || echo "false"),
      "bandwidth_limited": $([ -n "$BANDWIDTH_LIMIT" ] && echo "true" || echo "false"),
      "bandwidth_limit_kbps": ${BANDWIDTH_LIMIT:-0}
    },
    "performance": {
      "size_bytes": $FILE_SIZE,
      "duration_ms": $DOWNLOAD_TIME,
      "speed_kbps": $DOWNLOAD_SPEED,
      "avg_speed_mbps": $avg_speed_mbps
    }
  }
}
EOF
}

# =============================================================================
# Fonction de Nettoyage
# =============================================================================

cleanup() {
    log_debug "Nettoyage des ressources HTTP download"
    
    # Nettoyage des fichiers temporaires si échec et pas de reprise
    if [[ $DOWNLOAD_SUCCESS -eq 0 ]] && [[ $RESUME_DOWNLOAD -eq 0 ]]; then
        if [[ -f "$LOCAL_FILE" ]] && [[ $(stat -c%s "$LOCAL_FILE" 2>/dev/null || echo 0) -eq 0 ]]; then
            rm -f "$LOCAL_FILE"
            log_debug "Fichier vide supprimé: $LOCAL_FILE"
        fi
    fi
}

# =============================================================================
# Point d'Entrée Principal
# =============================================================================

main() {
    # Configuration du trap pour le nettoyage
    trap cleanup EXIT ERR INT TERM
    
    # Récupération des variables d'environnement par défaut
    REQUEST_TIMEOUT="${HTTP_TIMEOUT:-$REQUEST_TIMEOUT}"
    USER_AGENT="${HTTP_USER_AGENT:-$USER_AGENT}"
    VERIFY_SSL="${HTTP_VERIFY_SSL:-$VERIFY_SSL}"
    
    # Parsing des arguments
    parse_args "$@"
    
    # Validation des prérequis
    validate_prerequisites
    
    # Exécution du téléchargement
    local exit_code=0
    local result_message="Téléchargement HTTP réussi"
    
    if perform_download; then
        result_message="Téléchargement HTTP complété avec succès ($FILE_SIZE octets en ${DOWNLOAD_TIME}ms)"
        exit_code=0
    else
        local download_exit_code=$?
        case $download_exit_code in
            2)
                result_message="Erreur de connexion HTTP"
                exit_code=2
                ;;
            3)
                result_message="Erreur de téléchargement"
                exit_code=3
                ;;
            *)
                result_message="Erreur lors du téléchargement HTTP"
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