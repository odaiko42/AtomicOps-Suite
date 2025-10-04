#!/usr/bin/env bash

# ==============================================================================
# Script Orchestrateur: network-secure-connection.sh
# Description: Orchestrateur pour établissement de connexions réseau sécurisées
# Author: Generated with AtomicOps-Suite AI assistance
# Version: 1.0
# Date: 2025-10-04
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# Level: 1 (Orchestrateur)
# Dependencies: Scripts atomiques réseau, jq
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="network-secure-connection.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}

# Chemin vers les scripts atomiques
ATOMIC_SCRIPTS_DIR="${ATOMIC_SCRIPTS_DIR:-$(dirname "$0")/../../atomics/network}"

# Configuration de connexion
CONNECTION_TYPE=""  # ssh, ftp, http, scp
TARGET_HOST=""
TARGET_USER=""
TARGET_PORT=""
TARGET_KEY=""
TARGET_PASSWORD=""

# Options spécifiques selon le type de connexion
SSH_COMMAND=""        # Commande à exécuter via SSH
FTP_REMOTE_DIR=""     # Répertoire FTP à explorer
HTTP_ENDPOINT=""      # URL HTTP à tester
SCP_LOCAL_FILE=""     # Fichier local pour SCP
SCP_REMOTE_PATH=""    # Chemin distant pour SCP
SCP_DIRECTION="upload"  # upload ou download

# Configuration de sécurité
VERIFY_HOST_KEY=${VERIFY_HOST_KEY:-1}
USE_ENCRYPTION=${USE_ENCRYPTION:-1}
CONNECTION_TIMEOUT=${CONNECTION_TIMEOUT:-30}
RETRY_ATTEMPTS=${RETRY_ATTEMPTS:-3}

# Variables de résultat
CONNECTION_SUCCESSFUL=0
SECURITY_VALIDATED=0
OPERATION_COMPLETED=0
CONNECTION_INFO=""
SECURITY_STATUS=""

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
Usage: network-secure-connection.sh --type <ssh|ftp|http|scp> --host <host> [OPTIONS]

Description:
    Orchestrateur pour établissement de connexions réseau sécurisées.
    Valide la sécurité, établit la connexion et exécute l'opération demandée.

Arguments obligatoires:
    --type <type>           Type de connexion (ssh|ftp|http|scp)
    --host <hostname>       Serveur cible de la connexion

Options générales:
    -h, --help             Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)

Options de connexion:
    --user <username>      Utilisateur pour la connexion
    --port <port>          Port de connexion (défaut selon protocole)
    --key <path>           Clé privée SSH (pour ssh/scp)
    --password <pass>      Mot de passe (non recommandé)
    --timeout <seconds>    Timeout de connexion (défaut: 30)

Options de sécurité:
    --no-verify-host       Désactiver vérification de clé d'hôte
    --no-encryption        Autoriser connexions non chiffrées
    --retry <count>        Nombre de tentatives (défaut: 3)

Options spécifiques SSH:
    --command <cmd>        Commande à exécuter sur le serveur distant

Options spécifiques FTP:
    --remote-dir <path>    Répertoire distant à explorer

Options spécifiques HTTP:
    --endpoint <url>       URL/endpoint à tester (complet)

Options spécifiques SCP:
    --local-file <path>    Fichier local pour le transfert
    --remote-path <path>   Chemin distant pour le transfert
    --direction <dir>      Direction du transfert (upload|download)

Variables d'environnement:
    TARGET_HOST            Serveur cible par défaut
    TARGET_USER            Utilisateur par défaut
    TARGET_KEY             Clé privée par défaut
    ATOMIC_SCRIPTS_DIR     Répertoire des scripts atomiques
    VERIFY_HOST_KEY        Vérification de clé d'hôte (défaut: 1)
    USE_ENCRYPTION         Utilisation du chiffrement (défaut: 1)

Sortie JSON:
    {
      "status": "success|error",
      "code": 0|1|2|3,
      "timestamp": "ISO8601",
      "script": "network-secure-connection.sh",
      "message": "Description du résultat",
      "data": {
        "connection": {
          "type": "ssh|ftp|http|scp",
          "host": "server.example.com",
          "user": "username",
          "port": 22,
          "successful": true,
          "duration_ms": 1234
        },
        "security": {
          "encryption_used": true,
          "host_key_verified": true,
          "certificate_valid": true,
          "protocol_version": "TLSv1.3",
          "cipher_suite": "ECDHE-RSA-AES256-GCM-SHA384"
        },
        "operation": {
          "type": "command_execution|file_transfer|url_test",
          "successful": true,
          "details": {...}
        }
      }
    }

Codes de sortie:
    0 - Connexion sécurisée établie et opération réussie
    1 - Erreur de paramètres ou configuration
    2 - Échec de sécurité ou validation
    3 - Échec de connexion réseau

Exemples:
    # Connexion SSH sécurisée avec exécution de commande
    ./network-secure-connection.sh \
        --type ssh --host server.example.com \
        --user admin --key ~/.ssh/id_rsa \
        --command "systemctl status nginx"

    # Test de sécurité FTP
    ./network-secure-connection.sh \
        --type ftp --host ftp.example.com \
        --user ftpuser --password secret \
        --remote-dir /uploads

    # Vérification HTTPS avec certificat
    ./network-secure-connection.sh \
        --type http \
        --endpoint https://api.example.com/health

    # Transfert SCP sécurisé
    ./network-secure-connection.sh \
        --type scp --host backup.example.com \
        --user backup --key ~/.ssh/backup_key \
        --local-file ./important.tar.gz \
        --remote-path /backup/daily/ \
        --direction upload
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
            --type)
                [[ -z "${2:-}" ]] && die "Option --type nécessite une valeur" 1
                CONNECTION_TYPE="$2"
                shift
                ;;
            --host)
                [[ -z "${2:-}" ]] && die "Option --host nécessite une valeur" 1
                TARGET_HOST="$2"
                shift
                ;;
            --user)
                [[ -z "${2:-}" ]] && die "Option --user nécessite une valeur" 1
                TARGET_USER="$2"
                shift
                ;;
            --port)
                [[ -z "${2:-}" ]] && die "Option --port nécessite une valeur" 1
                TARGET_PORT="$2"
                shift
                ;;
            --key)
                [[ -z "${2:-}" ]] && die "Option --key nécessite une valeur" 1
                TARGET_KEY="$2"
                shift
                ;;
            --password)
                [[ -z "${2:-}" ]] && die "Option --password nécessite une valeur" 1
                TARGET_PASSWORD="$2"
                shift
                ;;
            --timeout)
                [[ -z "${2:-}" ]] && die "Option --timeout nécessite une valeur" 1
                CONNECTION_TIMEOUT="$2"
                shift
                ;;
            --retry)
                [[ -z "${2:-}" ]] && die "Option --retry nécessite une valeur" 1
                RETRY_ATTEMPTS="$2"
                shift
                ;;
            --no-verify-host)
                VERIFY_HOST_KEY=0
                ;;
            --no-encryption)
                USE_ENCRYPTION=0
                ;;
            --command)
                [[ -z "${2:-}" ]] && die "Option --command nécessite une valeur" 1
                SSH_COMMAND="$2"
                shift
                ;;
            --remote-dir)
                [[ -z "${2:-}" ]] && die "Option --remote-dir nécessite une valeur" 1
                FTP_REMOTE_DIR="$2"
                shift
                ;;
            --endpoint)
                [[ -z "${2:-}" ]] && die "Option --endpoint nécessite une valeur" 1
                HTTP_ENDPOINT="$2"
                shift
                ;;
            --local-file)
                [[ -z "${2:-}" ]] && die "Option --local-file nécessite une valeur" 1
                SCP_LOCAL_FILE="$2"
                shift
                ;;
            --remote-path)
                [[ -z "${2:-}" ]] && die "Option --remote-path nécessite une valeur" 1
                SCP_REMOTE_PATH="$2"
                shift
                ;;
            --direction)
                [[ -z "${2:-}" ]] && die "Option --direction nécessite une valeur" 1
                SCP_DIRECTION="$2"
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
    log_debug "Validation des prérequis de l'orchestrateur..."
    
    # Vérification de jq pour le parsing JSON
    if ! command -v jq >/dev/null 2>&1; then
        die "Commande 'jq' non trouvée (nécessaire pour l'orchestration)" 1
    fi
    
    # Validation des paramètres obligatoires
    [[ -z "$CONNECTION_TYPE" ]] && die "Paramètre --type obligatoire" 1
    [[ -z "$TARGET_HOST" ]] && die "Paramètre --host obligatoire" 1
    
    # Validation du type de connexion
    case "$CONNECTION_TYPE" in
        ssh|ftp|http|scp)
            ;;
        *)
            die "Type de connexion invalide: $CONNECTION_TYPE (attendu: ssh|ftp|http|scp)" 1
            ;;
    esac
    
    # Configuration des ports par défaut
    if [[ -z "$TARGET_PORT" ]]; then
        case "$CONNECTION_TYPE" in
            ssh|scp) TARGET_PORT=22 ;;
            ftp) TARGET_PORT=21 ;;
            http) TARGET_PORT=80 ;;
        esac
    fi
    
    # Validation spécifique par type
    case "$CONNECTION_TYPE" in
        ssh)
            [[ -z "$TARGET_USER" ]] && die "Paramètre --user obligatoire pour SSH" 1
            [[ -z "$SSH_COMMAND" ]] && die "Paramètre --command obligatoire pour SSH" 1
            ;;
        ftp)
            [[ -z "$TARGET_USER" ]] && die "Paramètre --user obligatoire pour FTP" 1
            ;;
        http)
            [[ -z "$HTTP_ENDPOINT" ]] && die "Paramètre --endpoint obligatoire pour HTTP" 1
            ;;
        scp)
            [[ -z "$TARGET_USER" ]] && die "Paramètre --user obligatoire pour SCP" 1
            [[ -z "$SCP_LOCAL_FILE" ]] && die "Paramètre --local-file obligatoire pour SCP" 1
            [[ -z "$SCP_REMOTE_PATH" ]] && die "Paramètre --remote-path obligatoire pour SCP" 1
            ;;
    esac
    
    # Validation de la clé privée si spécifiée
    if [[ -n "$TARGET_KEY" ]] && [[ ! -r "$TARGET_KEY" ]]; then
        die "Clé privée non accessible: $TARGET_KEY" 1
    fi
    
    # Vérification des scripts atomiques requis
    local required_scripts=()
    case "$CONNECTION_TYPE" in
        ssh)
            required_scripts=("ssh-connect.sh" "ssh-execute-command.sh")
            ;;
        ftp)
            required_scripts=("ftp-connect.sh")
            ;;
        http)
            required_scripts=("http-request.sh")
            ;;
        scp)
            required_scripts=("ssh-connect.sh" "scp-transfer.sh")
            ;;
    esac
    
    for script in "${required_scripts[@]}"; do
        if [[ ! -x "$ATOMIC_SCRIPTS_DIR/$script" ]]; then
            die "Script atomique manquant ou non exécutable: $ATOMIC_SCRIPTS_DIR/$script" 1
        fi
    done
    
    log_debug "Validation réussie"
    log_info "Connexion sécurisée $CONNECTION_TYPE vers $TARGET_HOST:$TARGET_PORT"
    
    return 0
}

# =============================================================================
# Fonctions d'Orchestration par Type
# =============================================================================

# Exécution d'un script atomique avec retry
execute_atomic_with_retry() {
    local script_name="$1"
    shift
    local script_args=("$@")
    
    local script_path="$ATOMIC_SCRIPTS_DIR/$script_name"
    log_debug "Exécution avec retry: $script_path ${script_args[*]}"
    
    local attempt=1
    local max_attempts=$RETRY_ATTEMPTS
    local result=""
    local exit_code=0
    
    while [[ $attempt -le $max_attempts ]]; do
        log_debug "Tentative $attempt/$max_attempts"
        
        if result=$("$script_path" --json-only "${script_args[@]}" 2>&1); then
            exit_code=0
            break
        else
            exit_code=$?
            log_debug "Échec tentative $attempt (code: $exit_code)"
            
            if [[ $attempt -lt $max_attempts ]]; then
                local wait_time=$((attempt * 2))
                log_debug "Attente ${wait_time}s avant nouvelle tentative"
                sleep $wait_time
            fi
        fi
        
        attempt=$((attempt + 1))
    done
    
    echo "$result"
    return $exit_code
}

# Orchestration SSH sécurisée
orchestrate_ssh_connection() {
    log_info "=== Connexion SSH Sécurisée ==="
    
    local start_time=$(date +%s%3N)
    
    # Phase 1: Test de connectivité et sécurité
    log_info "Phase 1: Validation de la connectivité SSH"
    
    local ssh_connect_args=(
        --host "$TARGET_HOST"
        --user "$TARGET_USER"
        --port "$TARGET_PORT"
        --timeout "$CONNECTION_TIMEOUT"
    )
    
    if [[ -n "$TARGET_KEY" ]]; then
        ssh_connect_args+=(--key "$TARGET_KEY")
    fi
    
    if [[ $VERIFY_HOST_KEY -eq 0 ]]; then
        ssh_connect_args+=(--no-verify-host)
    fi
    
    local connect_result
    if connect_result=$(execute_atomic_with_retry "ssh-connect.sh" "${ssh_connect_args[@]}"); then
        CONNECTION_SUCCESSFUL=1
        SECURITY_VALIDATED=1
        
        # Extraction des informations de sécurité
        CONNECTION_INFO=$(echo "$connect_result" | jq -r '.data.server_info // {}')
        SECURITY_STATUS=$(echo "$connect_result" | jq -r '.data.security // {}')
        
        log_info "Connectivité SSH validée avec sécurité"
    else
        log_error "Échec de validation SSH sécurisée"
        return 2
    fi
    
    # Phase 2: Exécution de la commande
    log_info "Phase 2: Exécution de commande distante"
    
    local ssh_exec_args=(
        --host "$TARGET_HOST"
        --user "$TARGET_USER"
        --port "$TARGET_PORT"
        --command "$SSH_COMMAND"
        --timeout "$CONNECTION_TIMEOUT"
    )
    
    if [[ -n "$TARGET_KEY" ]]; then
        ssh_exec_args+=(--key "$TARGET_KEY")
    fi
    
    local exec_result
    if exec_result=$(execute_atomic_with_retry "ssh-execute-command.sh" "${ssh_exec_args[@]}"); then
        OPERATION_COMPLETED=1
        
        local end_time=$(date +%s%3N)
        local duration=$((end_time - start_time))
        
        log_info "Commande SSH exécutée avec succès (${duration}ms)"
        return 0
    else
        log_error "Échec de l'exécution de commande SSH"
        return 3
    fi
}

# Orchestration FTP sécurisée
orchestrate_ftp_connection() {
    log_info "=== Connexion FTP Sécurisée ==="
    
    local start_time=$(date +%s%3N)
    
    local ftp_args=(
        --host "$TARGET_HOST"
        --user "$TARGET_USER"
        --port "$TARGET_PORT"
        --timeout "$CONNECTION_TIMEOUT"
    )
    
    if [[ -n "$TARGET_PASSWORD" ]]; then
        ftp_args+=(--password "$TARGET_PASSWORD")
    fi
    
    if [[ $USE_ENCRYPTION -eq 1 ]]; then
        ftp_args+=(--ssl)
    fi
    
    if [[ -n "$FTP_REMOTE_DIR" ]]; then
        ftp_args+=(--remote-dir "$FTP_REMOTE_DIR")
    fi
    
    local ftp_result
    if ftp_result=$(execute_atomic_with_retry "ftp-connect.sh" "${ftp_args[@]}"); then
        CONNECTION_SUCCESSFUL=1
        SECURITY_VALIDATED=1
        OPERATION_COMPLETED=1
        
        local end_time=$(date +%s%3N)
        local duration=$((end_time - start_time))
        
        # Extraction des informations de sécurité
        SECURITY_STATUS=$(echo "$ftp_result" | jq -r '.data.security // {}')
        
        log_info "Connexion FTP sécurisée réussie (${duration}ms)"
        return 0
    else
        log_error "Échec de connexion FTP sécurisée"
        return 3
    fi
}

# Orchestration HTTP sécurisée
orchestrate_http_connection() {
    log_info "=== Connexion HTTP Sécurisée ==="
    
    local start_time=$(date +%s%3N)
    
    local http_args=(
        --url "$HTTP_ENDPOINT"
        --method "GET"
        --timeout "$CONNECTION_TIMEOUT"
    )
    
    if [[ $VERIFY_HOST_KEY -eq 1 ]]; then
        http_args+=(--verify-ssl)
    fi
    
    local http_result
    if http_result=$(execute_atomic_with_retry "http-request.sh" "${http_args[@]}"); then
        CONNECTION_SUCCESSFUL=1
        SECURITY_VALIDATED=1
        OPERATION_COMPLETED=1
        
        local end_time=$(date +%s%3N)
        local duration=$((end_time - start_time))
        
        # Extraction des informations de sécurité
        SECURITY_STATUS=$(echo "$http_result" | jq -r '.data.ssl_info // {}')
        
        local status_code=$(echo "$http_result" | jq -r '.data.response.status_code // 0')
        
        if [[ $status_code -ge 200 ]] && [[ $status_code -lt 400 ]]; then
            log_info "Connexion HTTP sécurisée réussie (${duration}ms, HTTP $status_code)"
            return 0
        else
            log_error "Connexion HTTP établie mais statut inattendu: $status_code"
            return 3
        fi
    else
        log_error "Échec de connexion HTTP sécurisée"
        return 3
    fi
}

# Orchestration SCP sécurisée
orchestrate_scp_connection() {
    log_info "=== Transfert SCP Sécurisé ==="
    
    local start_time=$(date +%s%3N)
    
    # Phase 1: Validation SSH préalable
    log_info "Phase 1: Validation SSH pour SCP"
    
    local ssh_connect_args=(
        --host "$TARGET_HOST"
        --user "$TARGET_USER"
        --port "$TARGET_PORT"
        --timeout "$CONNECTION_TIMEOUT"
    )
    
    if [[ -n "$TARGET_KEY" ]]; then
        ssh_connect_args+=(--key "$TARGET_KEY")
    fi
    
    if [[ $VERIFY_HOST_KEY -eq 0 ]]; then
        ssh_connect_args+=(--no-verify-host)
    fi
    
    local connect_result
    if connect_result=$(execute_atomic_with_retry "ssh-connect.sh" "${ssh_connect_args[@]}"); then
        CONNECTION_SUCCESSFUL=1
        SECURITY_VALIDATED=1
        
        CONNECTION_INFO=$(echo "$connect_result" | jq -r '.data.server_info // {}')
        SECURITY_STATUS=$(echo "$connect_result" | jq -r '.data.security // {}')
        
        log_info "Validation SSH pour SCP réussie"
    else
        log_error "Échec de validation SSH pour SCP"
        return 2
    fi
    
    # Phase 2: Transfert SCP
    log_info "Phase 2: Transfert de fichier SCP"
    
    local scp_args=(
        --host "$TARGET_HOST"
        --user "$TARGET_USER"
        --port "$TARGET_PORT"
        --mode "$SCP_DIRECTION"
        --timeout "$CONNECTION_TIMEOUT"
    )
    
    if [[ "$SCP_DIRECTION" == "upload" ]]; then
        scp_args+=(--local "$SCP_LOCAL_FILE" --remote "$SCP_REMOTE_PATH")
    else
        scp_args+=(--remote "$SCP_REMOTE_PATH" --local "$SCP_LOCAL_FILE")
    fi
    
    if [[ -n "$TARGET_KEY" ]]; then
        scp_args+=(--key "$TARGET_KEY")
    fi
    
    local scp_result
    if scp_result=$(execute_atomic_with_retry "scp-transfer.sh" "${scp_args[@]}"); then
        OPERATION_COMPLETED=1
        
        local end_time=$(date +%s%3N)
        local duration=$((end_time - start_time))
        
        local transfer_size=$(echo "$scp_result" | jq -r '.data.performance.size_bytes // 0')
        local transfer_speed=$(echo "$scp_result" | jq -r '.data.performance.speed_kbps // 0')
        
        log_info "Transfert SCP sécurisé réussi (${duration}ms, $transfer_size octets à ${transfer_speed} KB/s)"
        return 0
    else
        log_error "Échec du transfert SCP sécurisé"
        return 3
    fi
}

# Orchestration principale selon le type
orchestrate() {
    log_debug "Démarrage de l'orchestration de connexion sécurisée"
    
    case "$CONNECTION_TYPE" in
        ssh)
            orchestrate_ssh_connection
            ;;
        ftp)
            orchestrate_ftp_connection
            ;;
        http)
            orchestrate_http_connection
            ;;
        scp)
            orchestrate_scp_connection
            ;;
        *)
            die "Type de connexion non supporté: $CONNECTION_TYPE" 1
            ;;
    esac
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
      "type": "$CONNECTION_TYPE",
      "host": "$TARGET_HOST",
      "user": "${TARGET_USER:-null}",
      "port": $TARGET_PORT,
      "successful": $([ $CONNECTION_SUCCESSFUL -eq 1 ] && echo "true" || echo "false"),
      "timeout": $CONNECTION_TIMEOUT,
      "retry_attempts": $RETRY_ATTEMPTS
    },
    "security": {
      "encryption_required": $([ $USE_ENCRYPTION -eq 1 ] && echo "true" || echo "false"),
      "host_key_verification": $([ $VERIFY_HOST_KEY -eq 1 ] && echo "true" || echo "false"),
      "security_validated": $([ $SECURITY_VALIDATED -eq 1 ] && echo "true" || echo "false"),
      "details": ${SECURITY_STATUS:-"{}"}
    },
    "operation": {
      "type": "$(case "$CONNECTION_TYPE" in
        ssh) echo "command_execution" ;;
        ftp) echo "directory_listing" ;;
        http) echo "url_test" ;;
        scp) echo "file_transfer" ;;
      esac)",
      "successful": $([ $OPERATION_COMPLETED -eq 1 ] && echo "true" || echo "false"),
      "details": {
        "ssh_command": "${SSH_COMMAND:-null}",
        "ftp_remote_dir": "${FTP_REMOTE_DIR:-null}",
        "http_endpoint": "${HTTP_ENDPOINT:-null}",
        "scp_local_file": "${SCP_LOCAL_FILE:-null}",
        "scp_remote_path": "${SCP_REMOTE_PATH:-null}",
        "scp_direction": "${SCP_DIRECTION:-null}"
      }
    },
    "server_info": ${CONNECTION_INFO:-"{}"}
  }
}
EOF
}

# =============================================================================
# Fonction de Nettoyage
# =============================================================================

cleanup() {
    log_debug "Nettoyage des ressources de connexion sécurisée"
    # Pas de ressources spécifiques à nettoyer
}

# =============================================================================
# Point d'Entrée Principal
# =============================================================================

main() {
    # Configuration du trap pour le nettoyage
    trap cleanup EXIT ERR INT TERM
    
    # Récupération des variables d'environnement par défaut
    TARGET_HOST="${TARGET_HOST:-}"
    TARGET_USER="${TARGET_USER:-}"
    TARGET_KEY="${TARGET_KEY:-}"
    
    # Parsing des arguments
    parse_args "$@"
    
    # Validation des prérequis
    validate_prerequisites
    
    # Exécution de l'orchestration
    local exit_code=0
    local result_message="Connexion sécurisée établie avec succès"
    
    if orchestrate; then
        result_message="Connexion $CONNECTION_TYPE sécurisée réussie vers $TARGET_HOST"
        exit_code=0
    else
        local orchestration_exit_code=$?
        case $orchestration_exit_code in
            2)
                result_message="Échec de validation de sécurité"
                exit_code=2
                ;;
            3)
                result_message="Échec de connexion ou d'opération"
                exit_code=3
                ;;
            *)
                result_message="Erreur lors de l'orchestration"
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