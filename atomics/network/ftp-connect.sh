#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: ftp-connect.sh
# Description: Test et validation de connexion FTP/FTPS vers un serveur
# Author: Generated with AtomicOps-Suite AI assistance
# Version: 1.0
# Date: 2025-10-04
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# Level: 0 (Atomique)
# Dependencies: ftp, lftp, openssl
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="ftp-connect.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}

# Variables FTP
FTP_HOST=""
FTP_PORT=${FTP_PORT:-21}
FTP_USER=""
FTP_PASSWORD=""
FTP_TIMEOUT=${FTP_TIMEOUT:-30}
FTP_PASSIVE=${FTP_PASSIVE:-1}
FTP_SSL=${FTP_SSL:-0}  # 0=FTP, 1=FTPS Explicit, 2=FTPS Implicit
CONNECTION_TEST_ONLY=${CONNECTION_TEST_ONLY:-0}

# Variables de résultat
CONNECTION_STATUS="failed"
CONNECTION_TIME=0
SERVER_FEATURES=""
SERVER_WELCOME=""
AUTH_SUCCESS=0
PASSIVE_MODE_OK=0
SSL_SUPPORT=0
ERROR_MESSAGE=""

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
Usage: ftp-connect.sh [OPTIONS] --host <hostname> --user <username>

Description:
    Test et valide une connexion FTP/FTPS vers un serveur. Supporte FTP standard,
    FTPS Explicit (STARTTLS) et FTPS Implicit. Teste la connectivité, 
    l'authentification et les fonctionnalités du serveur.

Arguments obligatoires:
    --host <hostname>        Nom d'hôte ou IP du serveur FTP
    --user <username>        Nom d'utilisateur FTP

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)
    -p, --port <port>      Port FTP (défaut: 21, FTPS Implicit: 990)
    --password <pass>      Mot de passe FTP
    -t, --timeout <sec>    Timeout de connexion en secondes (défaut: 30)
    --ssl <mode>           Mode SSL: 0=FTP, 1=FTPS Explicit, 2=FTPS Implicit (défaut: 0)
    --no-passive           Désactiver le mode passif
    --test-only            Test de connexion uniquement (pas d'authentification)

Variables d'environnement:
    FTP_HOST               Nom d'hôte par défaut
    FTP_PORT               Port par défaut (défaut: 21)
    FTP_USER               Utilisateur par défaut  
    FTP_PASSWORD           Mot de passe par défaut
    FTP_TIMEOUT            Timeout par défaut (défaut: 30)
    FTP_PASSIVE            Mode passif par défaut (défaut: 1)
    FTP_SSL                Mode SSL par défaut (défaut: 0)
    CONNECTION_TEST_ONLY   Mode test uniquement (défaut: 0)

Sortie JSON:
    {
      "status": "success|error",
      "code": 0|1|2|3|4,
      "timestamp": "ISO8601",
      "script": "ftp-connect.sh",
      "message": "Description du résultat",
      "data": {
        "connection": {
          "status": "success|failed|timeout|unreachable",
          "host": "hostname",
          "port": 21,
          "user": "username", 
          "connection_time_ms": 1234,
          "timeout_seconds": 30,
          "ssl_mode": 0
        },
        "server_info": {
          "welcome_message": "220 FTP Server ready",
          "features": ["PASV", "SIZE", "MDTM", "UTF8"],
          "ssl_support": false,
          "passive_mode_ok": true
        },
        "authentication": {
          "success": true,
          "method": "password",
          "anonymous": false
        }
      }
    }

Codes de sortie:
    0 - Connexion FTP réussie
    1 - Erreur de paramètres ou configuration
    2 - Connexion réseau impossible
    3 - Échec d'authentification FTP
    4 - Timeout de connexion

Exemples:
    # Test de connexion FTP basique
    ./ftp-connect.sh --host ftp.example.com --user testuser --password secret123
    
    # Test FTPS Explicit (STARTTLS)
    ./ftp-connect.sh --host secure-ftp.com --user admin --ssl 1 --password mypass
    
    # Test FTPS Implicit
    ./ftp-connect.sh --host ftps.secure.com --port 990 --user client --ssl 2
    
    # Test de connectivité uniquement
    ./ftp-connect.sh --host ftp.server.org --user anonymous --test-only
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
            --host)
                [[ -z "${2:-}" ]] && die "Option --host nécessite une valeur" 1
                FTP_HOST="$2"
                shift
                ;;
            --user)
                [[ -z "${2:-}" ]] && die "Option --user nécessite une valeur" 1
                FTP_USER="$2"
                shift
                ;;
            --password)
                [[ -z "${2:-}" ]] && die "Option --password nécessite une valeur" 1
                FTP_PASSWORD="$2"
                shift
                ;;
            -p|--port)
                [[ -z "${2:-}" ]] && die "Option --port nécessite une valeur" 1
                FTP_PORT="$2"
                shift
                ;;
            -t|--timeout)
                [[ -z "${2:-}" ]] && die "Option --timeout nécessite une valeur" 1
                FTP_TIMEOUT="$2"
                shift
                ;;
            --ssl)
                [[ -z "${2:-}" ]] && die "Option --ssl nécessite une valeur" 1
                FTP_SSL="$2"
                shift
                ;;
            --no-passive)
                FTP_PASSIVE=0
                ;;
            --test-only)
                CONNECTION_TEST_ONLY=1
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
    
    # Vérification des commandes nécessaires selon le mode
    local missing_commands=()
    
    # lftp est préféré pour FTPS et fonctionnalités avancées
    if ! command -v lftp >/dev/null 2>&1; then
        # Fallback sur ftp standard si pas de SSL requis
        if [[ $FTP_SSL -eq 0 ]] && command -v ftp >/dev/null 2>&1; then
            log_debug "Utilisation de 'ftp' standard (pas de FTPS)"
        else
            missing_commands+=("lftp")
        fi
    fi
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        die "Commandes manquantes: ${missing_commands[*]}" 1
    fi
    
    # Validation des paramètres obligatoires
    [[ -z "$FTP_HOST" ]] && die "Paramètre --host obligatoire" 1
    [[ -z "$FTP_USER" ]] && die "Paramètre --user obligatoire" 1
    
    # Validation du port
    if [[ ! "$FTP_PORT" =~ ^[0-9]+$ ]] || [[ $FTP_PORT -lt 1 ]] || [[ $FTP_PORT -gt 65535 ]]; then
        die "Port FTP invalide: $FTP_PORT (doit être entre 1-65535)" 1
    fi
    
    # Validation du timeout
    if [[ ! "$FTP_TIMEOUT" =~ ^[0-9]+$ ]] || [[ $FTP_TIMEOUT -lt 1 ]]; then
        die "Timeout invalide: $FTP_TIMEOUT (doit être >= 1)" 1
    fi
    
    # Validation du mode SSL
    if [[ ! "$FTP_SSL" =~ ^[0-2]$ ]]; then
        die "Mode SSL invalide: $FTP_SSL (doit être 0, 1 ou 2)" 1
    fi
    
    # Ajustement automatique du port pour FTPS Implicit
    if [[ $FTP_SSL -eq 2 ]] && [[ $FTP_PORT -eq 21 ]]; then
        FTP_PORT=990
        log_debug "Port ajusté à 990 pour FTPS Implicit"
    fi
    
    # Mot de passe obligatoire sauf pour test uniquement
    if [[ $CONNECTION_TEST_ONLY -eq 0 ]] && [[ -z "$FTP_PASSWORD" ]] && [[ "$FTP_USER" != "anonymous" ]]; then
        die "Mot de passe obligatoire pour l'authentification (ou --test-only)" 1
    fi
    
    log_debug "Validation réussie"
    log_info "Test FTP$([ $FTP_SSL -gt 0 ] && echo "S" || echo "") vers $FTP_USER@$FTP_HOST:$FTP_PORT"
    
    return 0
}

# =============================================================================
# Fonctions Principales
# =============================================================================

# Test de connectivité réseau basique
test_network_connectivity() {
    log_debug "Test de connectivité réseau vers $FTP_HOST:$FTP_PORT"
    
    local start_time=$(date +%s%3N)
    
    if timeout "$FTP_TIMEOUT" bash -c "exec 3<>/dev/tcp/$FTP_HOST/$FTP_PORT" 2>/dev/null; then
        local end_time=$(date +%s%3N)
        CONNECTION_TIME=$((end_time - start_time))
        log_debug "Connectivité réseau OK (${CONNECTION_TIME}ms)"
        exec 3>&- 2>/dev/null || true
        return 0
    else
        CONNECTION_TIME=0
        ERROR_MESSAGE="Connexion réseau impossible vers $FTP_HOST:$FTP_PORT"
        log_error "$ERROR_MESSAGE"
        return 2
    fi
}

# Test FTP avec lftp (recommandé)
test_ftp_with_lftp() {
    log_debug "Test FTP avec lftp"
    
    # Configuration lftp
    local lftp_commands="set net:timeout $FTP_TIMEOUT; "
    
    # Configuration SSL
    case $FTP_SSL in
        0)
            lftp_commands+="set ftp:ssl-allow no; "
            ;;
        1)
            lftp_commands+="set ftp:ssl-allow yes; set ftp:ssl-force yes; set ftp:ssl-protect-data yes; "
            ;;
        2)
            lftp_commands+="set ftp:ssl-allow yes; set ftp:ssl-force yes; set ftp:ssl-protect-data yes; set ssl:verify-certificate no; "
            ;;
    esac
    
    # Configuration mode passif
    if [[ $FTP_PASSIVE -eq 1 ]]; then
        lftp_commands+="set ftp:passive-mode true; "
    else
        lftp_commands+="set ftp:passive-mode false; "
    fi
    
    # Commandes de test
    lftp_commands+="open -u '$FTP_USER,${FTP_PASSWORD:-}' "
    
    if [[ $FTP_SSL -eq 2 ]]; then
        lftp_commands+="ftps://$FTP_HOST:$FTP_PORT; "
    else
        lftp_commands+="ftp://$FTP_HOST:$FTP_PORT; "
    fi
    
    if [[ $CONNECTION_TEST_ONLY -eq 0 ]]; then
        lftp_commands+="pwd; ls -la; feat; quit"
    else
        lftp_commands+="quit"
    fi
    
    # Exécution avec lftp
    local lftp_output
    local start_time=$(date +%s%3N)
    
    if lftp_output=$(echo "$lftp_commands" | lftp 2>&1); then
        local end_time=$(date +%s%3N)
        CONNECTION_TIME=$((end_time - start_time))
        
        # Analyser la sortie pour extraire les informations
        if echo "$lftp_output" | grep -q "Login successful" || echo "$lftp_output" | grep -q "^/"; then
            CONNECTION_STATUS="success"
            AUTH_SUCCESS=1
            log_debug "Connexion FTP réussie via lftp"
        elif echo "$lftp_output" | grep -q "Connected to" || echo "$lftp_output" | grep -q "220 "; then
            CONNECTION_STATUS="connected"
            log_debug "Connexion établie mais authentification non testée"
        fi
        
        # Extraction du message de bienvenue
        if SERVER_WELCOME=$(echo "$lftp_output" | grep "^220 " | head -1); then
            log_debug "Message serveur: $SERVER_WELCOME"
        fi
        
        # Extraction des fonctionnalités
        if echo "$lftp_output" | grep -q "FEAT"; then
            SERVER_FEATURES=$(echo "$lftp_output" | sed -n '/211-Features:/,/211 End/p' | grep -v "^211" || echo "")
        fi
        
        return 0
    else
        CONNECTION_TIME=0
        ERROR_MESSAGE="Échec de connexion FTP: $(echo "$lftp_output" | tail -1)"
        log_error "$ERROR_MESSAGE"
        return 3
    fi
}

# Test FTP avec client ftp standard (fallback)
test_ftp_with_standard_client() {
    log_debug "Test FTP avec client standard"
    
    # Préparation du script FTP
    local ftp_script=$(mktemp)
    cat > "$ftp_script" << EOF
user $FTP_USER ${FTP_PASSWORD:-}
$([ $FTP_PASSIVE -eq 1 ] && echo "passive" || echo "")
pwd
ls
quit
EOF

    local ftp_output
    local start_time=$(date +%s%3N)
    
    if ftp_output=$(timeout "$FTP_TIMEOUT" ftp -n "$FTP_HOST" "$FTP_PORT" < "$ftp_script" 2>&1); then
        local end_time=$(date +%s%3N)
        CONNECTION_TIME=$((end_time - start_time))
        
        if echo "$ftp_output" | grep -q "230 " || echo "$ftp_output" | grep -q "Login successful"; then
            CONNECTION_STATUS="success"
            AUTH_SUCCESS=1
            log_debug "Connexion FTP réussie via client standard"
        elif echo "$ftp_output" | grep -q "220 "; then
            CONNECTION_STATUS="connected"
            log_debug "Connexion établie"
        fi
        
        # Extraction du message de bienvenue
        if SERVER_WELCOME=$(echo "$ftp_output" | grep "^220 " | head -1); then
            log_debug "Message serveur: $SERVER_WELCOME"
        fi
        
        rm -f "$ftp_script"
        return 0
    else
        CONNECTION_TIME=0
        ERROR_MESSAGE="Échec de connexion FTP standard"
        log_error "$ERROR_MESSAGE"
        rm -f "$ftp_script"
        return 3
    fi
}

# Action principale du script
do_main_action() {
    log_debug "Démarrage du test de connexion FTP"
    
    # 1. Test de connectivité réseau basique
    if ! test_network_connectivity; then
        CONNECTION_STATUS="unreachable"
        return 2
    fi
    
    # 2. Test FTP selon les outils disponibles
    if command -v lftp >/dev/null 2>&1; then
        if test_ftp_with_lftp; then
            log_info "Test FTP terminé avec succès (lftp)"
            return 0
        else
            log_error "Test FTP échoué (lftp)"
            return 3
        fi
    elif [[ $FTP_SSL -eq 0 ]] && command -v ftp >/dev/null 2>&1; then
        if test_ftp_with_standard_client; then
            log_info "Test FTP terminé avec succès (client standard)"
            return 0
        else
            log_error "Test FTP échoué (client standard)"
            return 3
        fi
    else
        die "Aucun client FTP compatible disponible" 1
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
    
    # Extraction des fonctionnalités serveur en tableau JSON
    local features_json="[]"
    if [[ -n "$SERVER_FEATURES" ]]; then
        features_json="["
        local first=1
        while IFS= read -r feature; do
            [[ -z "$feature" ]] && continue
            if [[ $first -eq 1 ]]; then
                first=0
            else
                features_json+=", "
            fi
            features_json+="\"$(echo "$feature" | sed 's/^ *//; s/ *$//')\""
        done <<< "$SERVER_FEATURES"
        features_json+="]"
    fi
    
    cat << EOF
{
  "status": "$status",
  "code": $exit_code,
  "timestamp": "$timestamp",
  "script": "$SCRIPT_NAME",
  "message": "$message",
  "data": {
    "connection": {
      "status": "$CONNECTION_STATUS",
      "host": "$FTP_HOST",
      "port": $FTP_PORT,
      "user": "$FTP_USER",
      "connection_time_ms": $CONNECTION_TIME,
      "timeout_seconds": $FTP_TIMEOUT,
      "ssl_mode": $FTP_SSL,
      "passive_mode": $([ $FTP_PASSIVE -eq 1 ] && echo "true" || echo "false")
    },
    "server_info": {
      "welcome_message": "${SERVER_WELCOME:-null}",
      "features": $features_json,
      "ssl_support": $([ $FTP_SSL -gt 0 ] && echo "true" || echo "false"),
      "passive_mode_ok": $([ $PASSIVE_MODE_OK -eq 1 ] && echo "true" || echo "false")
    },
    "authentication": {
      "success": $([ $AUTH_SUCCESS -eq 1 ] && echo "true" || echo "false"),
      "method": "password",
      "anonymous": $([ "$FTP_USER" = "anonymous" ] && echo "true" || echo "false"),
      "test_only": $([ $CONNECTION_TEST_ONLY -eq 1 ] && echo "true" || echo "false")
    },
    "error": "${ERROR_MESSAGE:-null}"
  }
}
EOF
}

# =============================================================================
# Fonction de Nettoyage
# =============================================================================

cleanup() {
    log_debug "Nettoyage des ressources"
    # Fermer les connexions TCP ouvertes si nécessaire
    exec 3>&- 2>/dev/null || true
    # Supprimer les fichiers temporaires
    rm -f /tmp/ftp_script_* 2>/dev/null || true
}

# =============================================================================
# Point d'Entrée Principal
# =============================================================================

main() {
    # Configuration du trap pour le nettoyage
    trap cleanup EXIT ERR INT TERM
    
    # Récupération des variables d'environnement par défaut
    FTP_HOST="${FTP_HOST:-}"
    FTP_USER="${FTP_USER:-}"
    FTP_PASSWORD="${FTP_PASSWORD:-}"
    
    # Parsing des arguments
    parse_args "$@"
    
    # Validation des prérequis
    validate_prerequisites
    
    # Exécution de l'action principale
    local exit_code=0
    local result_message="Connexion FTP testée avec succès"
    
    if do_main_action; then
        case "$CONNECTION_STATUS" in
            "success")
                result_message="Connexion FTP authentifiée avec succès"
                exit_code=0
                ;;
            "connected")
                result_message="Serveur FTP accessible (test de connectivité uniquement)"
                exit_code=0
                ;;
            *)
                result_message="Connexion FTP échouée"
                exit_code=1
                ;;
        esac
    else
        local action_exit_code=$?
        case $action_exit_code in
            2)
                result_message="Serveur FTP inaccessible"
                exit_code=2
                ;;
            3)
                result_message="Échec d'authentification FTP"
                exit_code=3
                ;;
            4)
                result_message="Timeout de connexion FTP"
                exit_code=4
                ;;
            *)
                result_message="Erreur lors du test FTP"
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