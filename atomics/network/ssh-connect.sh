#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: ssh-connect.sh
# Description: Test et validation de connexion SSH vers un serveur distant
# Author: Generated with AtomicOps-Suite AI assistance
# Version: 1.0
# Date: 2025-10-04
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# Level: 0 (Atomique)
# Dependencies: ssh, ssh-keyscan
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="ssh-connect.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}

# Variables SSH
SSH_HOST=""
SSH_PORT=${SSH_PORT:-22}
SSH_USER=""
SSH_PRIVATE_KEY=""
SSH_TIMEOUT=${SSH_TIMEOUT:-10}
SSH_STRICT_HOST_CHECK=${SSH_STRICT_HOST_CHECK:-1}
CONNECTION_TEST_ONLY=${CONNECTION_TEST_ONLY:-0}

# Variables de résultat
CONNECTION_STATUS="failed"
CONNECTION_TIME=0
HOST_FINGERPRINT=""
SERVER_VERSION=""
AUTH_METHODS=""
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
Usage: ssh-connect.sh [OPTIONS] --host <hostname> --user <username>

Description:
    Test et valide une connexion SSH vers un serveur distant. Vérifie la
    connectivité, l'authentification, et collecte les informations du serveur.
    Supporte l'authentification par clé privée et par mot de passe.

Arguments obligatoires:
    --host <hostname>        Nom d'hôte ou IP du serveur SSH
    --user <username>        Nom d'utilisateur pour la connexion

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)
    -p, --port <port>      Port SSH (défaut: 22)
    -k, --key <path>       Chemin vers la clé privée SSH
    -t, --timeout <sec>    Timeout de connexion en secondes (défaut: 10)
    --no-strict-host       Désactiver la vérification strict des clés d'hôte
    --test-only            Test de connexion uniquement (pas d'authentification)

Variables d'environnement:
    SSH_HOST               Nom d'hôte par défaut
    SSH_PORT               Port par défaut (défaut: 22)  
    SSH_USER               Utilisateur par défaut
    SSH_PRIVATE_KEY        Clé privée par défaut
    SSH_TIMEOUT            Timeout par défaut (défaut: 10)
    SSH_STRICT_HOST_CHECK  Vérification des clés d'hôte (défaut: 1)
    CONNECTION_TEST_ONLY   Mode test uniquement (défaut: 0)

Sortie JSON:
    {
      "status": "success|error",
      "code": 0|1|2|3,
      "timestamp": "ISO8601",
      "script": "ssh-connect.sh",
      "message": "Description du résultat",
      "data": {
        "connection": {
          "status": "success|failed|timeout|unreachable",
          "host": "hostname",
          "port": 22,
          "user": "username",
          "connection_time_ms": 1234,
          "timeout_seconds": 10
        },
        "server_info": {
          "fingerprint": "SHA256:...",
          "version": "OpenSSH_8.9p1",
          "auth_methods": ["publickey", "password"]
        },
        "authentication": {
          "method": "publickey|password|none",
          "key_file": "/path/to/key",
          "success": true
        }
      }
    }

Codes de sortie:
    0 - Connexion SSH réussie
    1 - Erreur de paramètres ou configuration
    2 - Connexion réseau impossible
    3 - Échec d'authentification SSH
    4 - Timeout de connexion

Exemples:
    # Test de connexion avec clé privée
    ./ssh-connect.sh --host 192.168.1.100 --user admin --key ~/.ssh/id_rsa
    
    # Test rapide de connectivité uniquement
    ./ssh-connect.sh --host server.example.com --user root --test-only
    
    # Connexion avec port personnalisé
    ./ssh-connect.sh --host 10.0.0.50 --port 2222 --user deploy --key ~/.ssh/deploy_key
    
    # Test avec timeout court
    ./ssh-connect.sh --host slow-server.com --user admin --timeout 5
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
                SSH_HOST="$2"
                shift
                ;;
            --user)
                [[ -z "${2:-}" ]] && die "Option --user nécessite une valeur" 1
                SSH_USER="$2"
                shift
                ;;
            -p|--port)
                [[ -z "${2:-}" ]] && die "Option --port nécessite une valeur" 1
                SSH_PORT="$2"
                shift
                ;;
            -k|--key)
                [[ -z "${2:-}" ]] && die "Option --key nécessite une valeur" 1
                SSH_PRIVATE_KEY="$2"
                shift
                ;;
            -t|--timeout)
                [[ -z "${2:-}" ]] && die "Option --timeout nécessite une valeur" 1
                SSH_TIMEOUT="$2"
                shift
                ;;
            --no-strict-host)
                SSH_STRICT_HOST_CHECK=0
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
    
    # Vérification des commandes nécessaires
    local missing_commands=()
    
    if ! command -v ssh >/dev/null 2>&1; then
        missing_commands+=("ssh")
    fi
    
    if ! command -v ssh-keyscan >/dev/null 2>&1; then
        missing_commands+=("ssh-keyscan")
    fi
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        die "Commandes manquantes: ${missing_commands[*]}" 1
    fi
    
    # Validation des paramètres obligatoires
    [[ -z "$SSH_HOST" ]] && die "Paramètre --host obligatoire" 1
    [[ -z "$SSH_USER" ]] && die "Paramètre --user obligatoire" 1
    
    # Validation du port
    if [[ ! "$SSH_PORT" =~ ^[0-9]+$ ]] || [[ $SSH_PORT -lt 1 ]] || [[ $SSH_PORT -gt 65535 ]]; then
        die "Port SSH invalide: $SSH_PORT (doit être entre 1-65535)" 1
    fi
    
    # Validation du timeout
    if [[ ! "$SSH_TIMEOUT" =~ ^[0-9]+$ ]] || [[ $SSH_TIMEOUT -lt 1 ]]; then
        die "Timeout invalide: $SSH_TIMEOUT (doit être >= 1)" 1
    fi
    
    # Validation de la clé privée si spécifiée
    if [[ -n "$SSH_PRIVATE_KEY" ]] && [[ ! -r "$SSH_PRIVATE_KEY" ]]; then
        die "Clé privée non accessible: $SSH_PRIVATE_KEY" 1
    fi
    
    log_debug "Validation réussie"
    log_info "Test SSH vers $SSH_USER@$SSH_HOST:$SSH_PORT"
    
    return 0
}

# =============================================================================
# Fonctions Principales
# =============================================================================

# Test de connectivité réseau basique
test_network_connectivity() {
    log_debug "Test de connectivité réseau vers $SSH_HOST:$SSH_PORT"
    
    local start_time=$(date +%s%3N)
    
    if timeout "$SSH_TIMEOUT" bash -c "exec 3<>/dev/tcp/$SSH_HOST/$SSH_PORT" 2>/dev/null; then
        local end_time=$(date +%s%3N)
        CONNECTION_TIME=$((end_time - start_time))
        log_debug "Connectivité réseau OK (${CONNECTION_TIME}ms)"
        exec 3>&- 2>/dev/null || true
        return 0
    else
        CONNECTION_TIME=0
        ERROR_MESSAGE="Connexion réseau impossible vers $SSH_HOST:$SSH_PORT"
        log_error "$ERROR_MESSAGE"
        return 2
    fi
}

# Récupération des informations du serveur SSH
get_ssh_server_info() {
    log_debug "Récupération des informations du serveur SSH"
    
    # Récupération de l'empreinte et version du serveur
    local ssh_info_output
    if ssh_info_output=$(timeout "$SSH_TIMEOUT" ssh-keyscan -p "$SSH_PORT" -t rsa,ed25519,ecdsa "$SSH_HOST" 2>/dev/null); then
        if [[ -n "$ssh_info_output" ]]; then
            # Extraction de l'empreinte (première clé trouvée)
            HOST_FINGERPRINT=$(echo "$ssh_info_output" | head -1 | ssh-keygen -lf - 2>/dev/null | awk '{print $2}' || echo "unknown")
            log_debug "Empreinte serveur: $HOST_FINGERPRINT"
        fi
    else
        log_warn "Impossible de récupérer l'empreinte du serveur"
    fi
    
    # Test de connexion pour récupérer version et méthodes d'auth
    local ssh_test_output
    local ssh_options=(
        -o "BatchMode=yes"
        -o "ConnectTimeout=$SSH_TIMEOUT"
        -o "PasswordAuthentication=no"
        -o "PubkeyAuthentication=no"
        -o "PreferredAuthentications=none"
        -p "$SSH_PORT"
    )
    
    if [[ $SSH_STRICT_HOST_CHECK -eq 0 ]]; then
        ssh_options+=(-o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null")
    fi
    
    if ssh_test_output=$(ssh "${ssh_options[@]}" "$SSH_USER@$SSH_HOST" 2>&1); then
        log_debug "Test de connexion SSH réussi (inattendu)"
    else
        # Analyser la sortie d'erreur pour extraire les informations utiles
        if echo "$ssh_test_output" | grep -q "Permission denied"; then
            # Extraire les méthodes d'authentification disponibles
            if echo "$ssh_test_output" | grep -q "publickey"; then
                AUTH_METHODS="${AUTH_METHODS:+$AUTH_METHODS,}publickey"
            fi
            if echo "$ssh_test_output" | grep -q "password"; then
                AUTH_METHODS="${AUTH_METHODS:+$AUTH_METHODS,}password"
            fi
            if echo "$ssh_test_output" | grep -q "keyboard-interactive"; then
                AUTH_METHODS="${AUTH_METHODS:+$AUTH_METHODS,}keyboard-interactive"
            fi
        fi
        
        # Extraire la version du serveur si présente
        if echo "$ssh_test_output" | grep -q "OpenSSH"; then
            SERVER_VERSION=$(echo "$ssh_test_output" | grep -o "OpenSSH[_0-9.p]*" | head -1 || echo "unknown")
        fi
    fi
    
    log_debug "Version serveur: ${SERVER_VERSION:-unknown}"
    log_debug "Méthodes d'auth: ${AUTH_METHODS:-unknown}"
}

# Test d'authentification SSH
test_ssh_authentication() {
    log_debug "Test d'authentification SSH"
    
    local ssh_options=(
        -o "BatchMode=yes"
        -o "ConnectTimeout=$SSH_TIMEOUT"
        -p "$SSH_PORT"
    )
    
    if [[ $SSH_STRICT_HOST_CHECK -eq 0 ]]; then
        ssh_options+=(-o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null")
    fi
    
    # Test avec clé privée si spécifiée
    if [[ -n "$SSH_PRIVATE_KEY" ]]; then
        log_debug "Test d'authentification par clé privée: $SSH_PRIVATE_KEY"
        ssh_options+=(-i "$SSH_PRIVATE_KEY")
        
        if ssh "${ssh_options[@]}" "$SSH_USER@$SSH_HOST" "exit 0" 2>/dev/null; then
            CONNECTION_STATUS="success"
            log_info "Authentification SSH réussie (clé privée)"
            return 0
        else
            ERROR_MESSAGE="Échec d'authentification avec la clé privée $SSH_PRIVATE_KEY"
            log_error "$ERROR_MESSAGE"
            return 3
        fi
    else
        # Sans clé privée spécifiée, on teste l'authentification par défaut
        log_debug "Test d'authentification par méthode par défaut"
        
        if ssh "${ssh_options[@]}" "$SSH_USER@$SSH_HOST" "exit 0" 2>/dev/null; then
            CONNECTION_STATUS="success"
            log_info "Authentification SSH réussie (méthode par défaut)"
            return 0
        else
            ERROR_MESSAGE="Échec d'authentification SSH (aucune méthode valide)"
            log_error "$ERROR_MESSAGE"
            return 3
        fi
    fi
}

# Action principale du script
do_main_action() {
    log_debug "Démarrage du test de connexion SSH"
    
    # 1. Test de connectivité réseau basique
    if ! test_network_connectivity; then
        CONNECTION_STATUS="unreachable"
        return 2
    fi
    
    # 2. Récupération des informations du serveur
    get_ssh_server_info
    
    # 3. Si mode test uniquement, on s'arrête ici
    if [[ $CONNECTION_TEST_ONLY -eq 1 ]]; then
        CONNECTION_STATUS="reachable"
        log_info "Test de connectivité uniquement - serveur accessible"
        return 0
    fi
    
    # 4. Test d'authentification complet
    if test_ssh_authentication; then
        log_info "Test de connexion SSH terminé avec succès"
        return 0
    else
        log_error "Test de connexion SSH échoué"
        return 3
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
      "host": "$SSH_HOST",
      "port": $SSH_PORT,
      "user": "$SSH_USER",
      "connection_time_ms": $CONNECTION_TIME,
      "timeout_seconds": $SSH_TIMEOUT
    },
    "server_info": {
      "fingerprint": "${HOST_FINGERPRINT:-unknown}",
      "version": "${SERVER_VERSION:-unknown}",
      "auth_methods": "${AUTH_METHODS:-unknown}"
    },
    "authentication": {
      "method": "${SSH_PRIVATE_KEY:+publickey}${SSH_PRIVATE_KEY:-default}",
      "key_file": "${SSH_PRIVATE_KEY:-null}",
      "success": $([ "$CONNECTION_STATUS" = "success" ] && echo "true" || echo "false"),
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
}

# =============================================================================
# Point d'Entrée Principal
# =============================================================================

main() {
    # Configuration du trap pour le nettoyage
    trap cleanup EXIT ERR INT TERM
    
    # Récupération des variables d'environnement par défaut
    SSH_HOST="${SSH_HOST:-}"
    SSH_USER="${SSH_USER:-}"
    SSH_PRIVATE_KEY="${SSH_PRIVATE_KEY:-}"
    
    # Parsing des arguments
    parse_args "$@"
    
    # Validation des prérequis
    validate_prerequisites
    
    # Exécution de l'action principale
    local exit_code=0
    local result_message="Connexion SSH testée avec succès"
    
    if do_main_action; then
        case "$CONNECTION_STATUS" in
            "success")
                result_message="Connexion SSH authentifiée avec succès"
                exit_code=0
                ;;
            "reachable")
                result_message="Serveur SSH accessible (test de connectivité uniquement)"
                exit_code=0
                ;;
            *)
                result_message="Connexion SSH échouée"
                exit_code=1
                ;;
        esac
    else
        local action_exit_code=$?
        case $action_exit_code in
            2)
                result_message="Serveur SSH inaccessible"
                exit_code=2
                ;;
            3)
                result_message="Échec d'authentification SSH"
                exit_code=3
                ;;
            4)
                result_message="Timeout de connexion SSH"
                exit_code=4
                ;;
            *)
                result_message="Erreur lors du test SSH"
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