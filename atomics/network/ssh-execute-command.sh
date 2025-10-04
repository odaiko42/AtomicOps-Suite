#!/usr/bin/env bash

# ==============================================================================
# Script Atomique: ssh-execute-command.sh
# Description: Exécute des commandes à distance via SSH avec gestion des résultats
# Author: Generated with AtomicOps-Suite AI assistance
# Version: 1.0
# Date: 2025-10-04
# Conformité: Méthodologie de Développement Modulaire et Hiérarchique
# Level: 0 (Atomique)
# Dependencies: ssh
# ==============================================================================

set -euo pipefail

# =============================================================================
# Configuration et Variables Globales
# =============================================================================

SCRIPT_NAME="ssh-execute-command.sh"
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
SSH_TIMEOUT=${SSH_TIMEOUT:-30}
SSH_STRICT_HOST_CHECK=${SSH_STRICT_HOST_CHECK:-1}

# Variables de commande
REMOTE_COMMAND=""
COMMAND_TIMEOUT=${COMMAND_TIMEOUT:-60}
CAPTURE_OUTPUT=${CAPTURE_OUTPUT:-1}
WORKING_DIRECTORY=""
ENVIRONMENT_VARS=()

# Variables de résultat
COMMAND_EXIT_CODE=0
COMMAND_STDOUT=""
COMMAND_STDERR=""
EXECUTION_TIME=0
CONNECTION_SUCCESS=0

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
Usage: ssh-execute-command.sh [OPTIONS] --host <hostname> --user <username> --command <command>

Description:
    Exécute une commande à distance via SSH et capture les résultats (stdout, stderr, 
    code de sortie). Supporte l'authentification par clé privée, la définition de 
    variables d'environnement, et le changement de répertoire de travail.

Arguments obligatoires:
    --host <hostname>        Nom d'hôte ou IP du serveur SSH
    --user <username>        Nom d'utilisateur pour la connexion
    --command <command>      Commande à exécuter sur le serveur distant

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)
    -p, --port <port>      Port SSH (défaut: 22)
    -k, --key <path>       Chemin vers la clé privée SSH
    -t, --timeout <sec>    Timeout de connexion SSH en secondes (défaut: 30)
    --cmd-timeout <sec>    Timeout d'exécution de commande (défaut: 60)
    --no-strict-host       Désactiver la vérification strict des clés d'hôte
    --no-capture           Ne pas capturer stdout/stderr (sortie directe)
    -w, --workdir <path>   Répertoire de travail pour l'exécution
    -e, --env <VAR=value>  Variable d'environnement (répétable)

Variables d'environnement:
    SSH_HOST               Nom d'hôte par défaut
    SSH_PORT               Port par défaut (défaut: 22)
    SSH_USER               Utilisateur par défaut
    SSH_PRIVATE_KEY        Clé privée par défaut
    SSH_TIMEOUT            Timeout SSH par défaut (défaut: 30)
    COMMAND_TIMEOUT        Timeout commande par défaut (défaut: 60)
    SSH_STRICT_HOST_CHECK  Vérification des clés d'hôte (défaut: 1)

Sortie JSON:
    {
      "status": "success|error",
      "code": 0|1|2|3|4,
      "timestamp": "ISO8601",
      "script": "ssh-execute-command.sh",
      "message": "Description du résultat",
      "data": {
        "connection": {
          "host": "hostname",
          "port": 22,
          "user": "username",
          "success": true
        },
        "execution": {
          "command": "ls -la",
          "exit_code": 0,
          "execution_time_ms": 1234,
          "timeout_seconds": 60,
          "working_directory": "/home/user",
          "environment": {"VAR1": "value1"}
        },
        "output": {
          "stdout": "output content",
          "stderr": "error content",
          "stdout_lines": 42,
          "stderr_lines": 0
        }
      }
    }

Codes de sortie:
    0 - Commande exécutée avec succès
    1 - Erreur de paramètres ou configuration
    2 - Connexion SSH impossible
    3 - Commande distante a échoué (exit code != 0)
    4 - Timeout d'exécution de la commande

Exemples:
    # Exécuter une commande simple
    ./ssh-execute-command.sh --host 192.168.1.100 --user admin \
        --key ~/.ssh/id_rsa --command "uptime"
    
    # Commande avec variables d'environnement
    ./ssh-execute-command.sh --host server.com --user deploy \
        --env "DEPLOY_ENV=production" --env "DEBUG=false" \
        --command "cd /app && ./deploy.sh"
    
    # Commande avec répertoire de travail et timeout
    ./ssh-execute-command.sh --host build-server --user ci \
        --workdir "/var/lib/jenkins" --cmd-timeout 300 \
        --command "make clean && make all"
    
    # Commande interactive (sans capture)
    ./ssh-execute-command.sh --host remote --user admin \
        --no-capture --command "htop"
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
            --command)
                [[ -z "${2:-}" ]] && die "Option --command nécessite une valeur" 1
                REMOTE_COMMAND="$2"
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
            --cmd-timeout)
                [[ -z "${2:-}" ]] && die "Option --cmd-timeout nécessite une valeur" 1
                COMMAND_TIMEOUT="$2"
                shift
                ;;
            --no-strict-host)
                SSH_STRICT_HOST_CHECK=0
                ;;
            --no-capture)
                CAPTURE_OUTPUT=0
                ;;
            -w|--workdir)
                [[ -z "${2:-}" ]] && die "Option --workdir nécessite une valeur" 1
                WORKING_DIRECTORY="$2"
                shift
                ;;
            -e|--env)
                [[ -z "${2:-}" ]] && die "Option --env nécessite une valeur" 1
                ENVIRONMENT_VARS+=("$2")
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
    
    # Vérification de la commande SSH
    if ! command -v ssh >/dev/null 2>&1; then
        die "Commande 'ssh' non trouvée" 1
    fi
    
    # Validation des paramètres obligatoires
    [[ -z "$SSH_HOST" ]] && die "Paramètre --host obligatoire" 1
    [[ -z "$SSH_USER" ]] && die "Paramètre --user obligatoire" 1
    [[ -z "$REMOTE_COMMAND" ]] && die "Paramètre --command obligatoire" 1
    
    # Validation du port
    if [[ ! "$SSH_PORT" =~ ^[0-9]+$ ]] || [[ $SSH_PORT -lt 1 ]] || [[ $SSH_PORT -gt 65535 ]]; then
        die "Port SSH invalide: $SSH_PORT (doit être entre 1-65535)" 1
    fi
    
    # Validation des timeouts
    if [[ ! "$SSH_TIMEOUT" =~ ^[0-9]+$ ]] || [[ $SSH_TIMEOUT -lt 1 ]]; then
        die "Timeout SSH invalide: $SSH_TIMEOUT (doit être >= 1)" 1
    fi
    
    if [[ ! "$COMMAND_TIMEOUT" =~ ^[0-9]+$ ]] || [[ $COMMAND_TIMEOUT -lt 1 ]]; then
        die "Timeout commande invalide: $COMMAND_TIMEOUT (doit être >= 1)" 1
    fi
    
    # Validation de la clé privée si spécifiée
    if [[ -n "$SSH_PRIVATE_KEY" ]] && [[ ! -r "$SSH_PRIVATE_KEY" ]]; then
        die "Clé privée non accessible: $SSH_PRIVATE_KEY" 1
    fi
    
    log_debug "Validation réussie"
    log_info "Exécution SSH: $REMOTE_COMMAND sur $SSH_USER@$SSH_HOST:$SSH_PORT"
    
    return 0
}

# =============================================================================
# Fonctions Principales
# =============================================================================

# Construction de la commande SSH avec options
build_ssh_command() {
    local ssh_options=(
        -o "BatchMode=yes"
        -o "ConnectTimeout=$SSH_TIMEOUT"
        -p "$SSH_PORT"
    )
    
    if [[ $SSH_STRICT_HOST_CHECK -eq 0 ]]; then
        ssh_options+=(-o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null")
    fi
    
    if [[ -n "$SSH_PRIVATE_KEY" ]]; then
        ssh_options+=(-i "$SSH_PRIVATE_KEY")
    fi
    
    echo "${ssh_options[@]}"
}

# Construction de la commande distante avec environnement et répertoire
build_remote_command() {
    local full_command=""
    
    # Variables d'environnement
    if [[ ${#ENVIRONMENT_VARS[@]} -gt 0 ]]; then
        for env_var in "${ENVIRONMENT_VARS[@]}"; do
            full_command+="export $env_var; "
        done
    fi
    
    # Changement de répertoire si spécifié
    if [[ -n "$WORKING_DIRECTORY" ]]; then
        full_command+="cd '$WORKING_DIRECTORY' && "
    fi
    
    # Commande principale
    full_command+="$REMOTE_COMMAND"
    
    echo "$full_command"
}

# Exécution de la commande SSH avec capture ou sans
execute_ssh_command() {
    log_debug "Exécution de la commande SSH"
    
    local ssh_options
    IFS=' ' read -ra ssh_options <<< "$(build_ssh_command)"
    
    local remote_cmd
    remote_cmd=$(build_remote_command)
    
    local start_time=$(date +%s%3N)
    
    if [[ $CAPTURE_OUTPUT -eq 1 ]]; then
        # Mode capture - récupération stdout/stderr séparément
        local temp_stdout=$(mktemp)
        local temp_stderr=$(mktemp)
        
        log_debug "Exécution avec capture de sortie"
        
        if timeout "$COMMAND_TIMEOUT" ssh "${ssh_options[@]}" "$SSH_USER@$SSH_HOST" "$remote_cmd" \
            >"$temp_stdout" 2>"$temp_stderr"; then
            COMMAND_EXIT_CODE=0
            CONNECTION_SUCCESS=1
        else
            COMMAND_EXIT_CODE=$?
            if [[ $COMMAND_EXIT_CODE -eq 124 ]]; then
                # Code 124 = timeout
                COMMAND_EXIT_CODE=4
                echo "Command timeout after ${COMMAND_TIMEOUT}s" >> "$temp_stderr"
            else
                CONNECTION_SUCCESS=1  # Connexion OK mais commande échouée
            fi
        fi
        
        # Lecture des résultats
        COMMAND_STDOUT=$(cat "$temp_stdout" || echo "")
        COMMAND_STDERR=$(cat "$temp_stderr" || echo "")
        
        # Nettoyage
        rm -f "$temp_stdout" "$temp_stderr"
        
    else
        # Mode sans capture - sortie directe
        log_debug "Exécution sans capture de sortie (mode interactif)"
        
        if timeout "$COMMAND_TIMEOUT" ssh "${ssh_options[@]}" "$SSH_USER@$SSH_HOST" "$remote_cmd"; then
            COMMAND_EXIT_CODE=0
            CONNECTION_SUCCESS=1
        else
            COMMAND_EXIT_CODE=$?
            if [[ $COMMAND_EXIT_CODE -eq 124 ]]; then
                COMMAND_EXIT_CODE=4
            else
                CONNECTION_SUCCESS=1
            fi
        fi
        
        COMMAND_STDOUT="[Output not captured - interactive mode]"
        COMMAND_STDERR="[Output not captured - interactive mode]"
    fi
    
    local end_time=$(date +%s%3N)
    EXECUTION_TIME=$((end_time - start_time))
    
    log_debug "Exécution terminée - Exit code: $COMMAND_EXIT_CODE, Temps: ${EXECUTION_TIME}ms"
    
    return $COMMAND_EXIT_CODE
}

# Action principale du script
do_main_action() {
    log_debug "Démarrage de l'exécution SSH"
    
    # Test de connectivité basique d'abord
    log_debug "Test de connectivité vers $SSH_HOST:$SSH_PORT"
    if ! timeout "$SSH_TIMEOUT" bash -c "exec 3<>/dev/tcp/$SSH_HOST/$SSH_PORT" 2>/dev/null; then
        log_error "Connexion réseau impossible vers $SSH_HOST:$SSH_PORT"
        exec 3>&- 2>/dev/null || true
        return 2
    fi
    exec 3>&- 2>/dev/null || true
    
    # Exécution de la commande SSH
    local exit_code
    if execute_ssh_command; then
        if [[ $COMMAND_EXIT_CODE -eq 0 ]]; then
            log_info "Commande exécutée avec succès"
            return 0
        else
            log_error "Commande distante échouée (exit code: $COMMAND_EXIT_CODE)"
            return 3
        fi
    else
        exit_code=$?
        case $exit_code in
            2)
                log_error "Connexion SSH impossible"
                return 2
                ;;
            4)
                log_error "Timeout d'exécution de la commande"
                return 4
                ;;
            *)
                log_error "Erreur lors de l'exécution SSH"
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
    
    # Comptage des lignes pour stdout/stderr
    local stdout_lines=0
    local stderr_lines=0
    
    if [[ -n "$COMMAND_STDOUT" ]]; then
        stdout_lines=$(echo -n "$COMMAND_STDOUT" | grep -c '^' || echo "0")
    fi
    
    if [[ -n "$COMMAND_STDERR" ]]; then
        stderr_lines=$(echo -n "$COMMAND_STDERR" | grep -c '^' || echo "0")
    fi
    
    # Construction de la chaîne des variables d'environnement
    local env_json="{"
    local first=1
    for env_var in "${ENVIRONMENT_VARS[@]}"; do
        if [[ $first -eq 1 ]]; then
            first=0
        else
            env_json+=", "
        fi
        local var_name="${env_var%%=*}"
        local var_value="${env_var#*=}"
        env_json+="\"$var_name\": \"$var_value\""
    done
    env_json+="}"
    
    # Échappement JSON pour stdout/stderr
    local escaped_stdout=$(echo -n "$COMMAND_STDOUT" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/g' | tr -d '\n' | sed 's/\\n$//')
    local escaped_stderr=$(echo -n "$COMMAND_STDERR" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/g' | tr -d '\n' | sed 's/\\n$//')
    
    cat << EOF
{
  "status": "$status",
  "code": $exit_code,
  "timestamp": "$timestamp",
  "script": "$SCRIPT_NAME",
  "message": "$message",
  "data": {
    "connection": {
      "host": "$SSH_HOST",
      "port": $SSH_PORT,
      "user": "$SSH_USER",
      "success": $([ $CONNECTION_SUCCESS -eq 1 ] && echo "true" || echo "false")
    },
    "execution": {
      "command": "$(echo -n "$REMOTE_COMMAND" | sed 's/\\/\\\\/g; s/"/\\"/g')",
      "exit_code": $COMMAND_EXIT_CODE,
      "execution_time_ms": $EXECUTION_TIME,
      "timeout_seconds": $COMMAND_TIMEOUT,
      "working_directory": "${WORKING_DIRECTORY:-null}",
      "environment": $env_json,
      "captured_output": $([ $CAPTURE_OUTPUT -eq 1 ] && echo "true" || echo "false")
    },
    "output": {
      "stdout": "$escaped_stdout",
      "stderr": "$escaped_stderr",
      "stdout_lines": $stdout_lines,
      "stderr_lines": $stderr_lines
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
    # Fermer les connexions TCP ouvertes si nécessaire
    exec 3>&- 2>/dev/null || true
    # Supprimer les fichiers temporaires s'ils existent
    rm -f /tmp/ssh_stdout_* /tmp/ssh_stderr_* 2>/dev/null || true
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
    local result_message="Commande SSH exécutée avec succès"
    
    if do_main_action; then
        if [[ $COMMAND_EXIT_CODE -eq 0 ]]; then
            result_message="Commande SSH terminée avec succès"
            exit_code=0
        else
            result_message="Commande SSH terminée avec code d'erreur $COMMAND_EXIT_CODE"
            exit_code=3
        fi
    else
        local action_exit_code=$?
        case $action_exit_code in
            2)
                result_message="Connexion SSH impossible"
                exit_code=2
                ;;
            3)
                result_message="Commande distante a échoué"
                exit_code=3
                ;;
            4)
                result_message="Timeout d'exécution de la commande"
                exit_code=4
                ;;
            *)
                result_message="Erreur lors de l'exécution SSH"
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