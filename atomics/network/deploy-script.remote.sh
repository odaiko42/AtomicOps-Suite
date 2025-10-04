#!/usr/bin/env bash
# ============================================================================
# Script      : deploy-script.remote.sh  
# Description : Déploie et exécute un script sur un hôte distant via SSH
# Version     : 1.0.0
# Date        : 2024-12-19
# Auteur      : Assistant IA - Conforme AtomicOps-Suite
# Licence     : MIT
# 
# Fonctions   :
# - Copie sécurisée de script vers hôte distant 
# - Validation d'intégrité (checksum)
# - Exécution distante avec gestion timeout
# - Collecte logs et codes de sortie
# - Nettoyage automatique des fichiers temporaires
#
# Niveau      : 0 (Atomique)
# Dépendances : copy-file.remote.sh, execute-ssh.remote.sh
# ============================================================================

set -euo pipefail

# === CONSTANTES ===
readonly SCRIPT_NAME="deploy-script.remote.sh"
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_PATH="${SCRIPT_DIR}/${SCRIPT_NAME}"

# Codes de sortie standardisés
readonly SUCCESS=0
readonly ERROR_ARGS=1
readonly ERROR_PREREQ=2
readonly ERROR_COPY=3
readonly ERROR_EXECUTION=4
readonly ERROR_CLEANUP=5

# === VARIABLES GLOBALES ===
SCRIPT_TO_DEPLOY=""
REMOTE_HOST=""
REMOTE_USER=""
REMOTE_PATH="/tmp"
EXECUTION_PARAMS=""
IDENTITY_FILE=""
SSH_PORT="22"
TIMEOUT="300"
CLEANUP_REMOTE="true"
VALIDATE_CHECKSUM="true"
LOG_EXECUTION="true"

# Variables de contrôle
DEBUG=${DEBUG:-false}
QUIET=${QUIET:-false}
FORCE=${FORCE:-false}

# === FONCTIONS DE LOGGING ===
network_log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ "$QUIET" != true ]]; then
        case "$level" in
            INFO)  echo -e "[\033[34mNETWORK-INFO\033[0m]  $timestamp - $message" ;;
            WARN)  echo -e "[\033[33mNETWORK-WARN\033[0m]  $timestamp - $message" ;;
            ERROR) echo -e "[\033[31mNETWORK-ERROR\033[0m] $timestamp - $message" >&2 ;;
            DEBUG) [[ "$DEBUG" == true ]] && echo -e "[\033[36mNETWORK-DEBUG\033[0m] $timestamp - $message" ;;
        esac
    fi
}

network_info() { network_log "INFO" "$@"; }
network_warn() { network_log "WARN" "$@"; }
network_error() { network_log "ERROR" "$@"; }
network_debug() { network_log "DEBUG" "$@"; }

# === FONCTION D'AIDE ===
show_help() {
    cat << 'EOF'
deploy-script.remote.sh - Déploie et exécute un script sur hôte distant

USAGE:
    deploy-script.remote.sh [OPTIONS] -s SCRIPT -h HOST -u USER

ARGUMENTS REQUIS:
    -s, --script SCRIPT         Chemin du script local à déployer
    -h, --host HOST            Hôte distant (IP ou FQDN)  
    -u, --user USER            Utilisateur SSH distant

OPTIONS:
    -p, --path PATH            Répertoire distant (défaut: /tmp)
    -i, --identity FILE        Fichier de clé privée SSH
    -P, --port PORT            Port SSH (défaut: 22)
    -t, --timeout SECONDS     Timeout exécution (défaut: 300)
    -a, --args "ARGS"          Arguments pour le script distant
    --no-cleanup               Ne pas nettoyer les fichiers distants
    --no-checksum              Désactiver validation checksum
    --no-log                   Désactiver logging d'exécution
    -q, --quiet                Mode silencieux
    -d, --debug                Mode debug
    -f, --force                Forcer l'exécution
    --help                     Afficher cette aide

EXEMPLES:
    # Déploiement simple
    deploy-script.remote.sh -s ./setup.sh -h prod1.com -u deploy
    
    # Avec clé SSH et arguments
    deploy-script.remote.sh -s ./install.sh -h 192.168.1.10 -u root \
                           -i ~/.ssh/deploy_key -a "--env prod --verbose"
    
    # Déploiement sécurisé avec validation
    deploy-script.remote.sh -s ./critical.sh -h secure-host \
                           -u admin -P 2222 -t 600

CODES DE SORTIE:
    0  Succès - script déployé et exécuté avec succès
    1  Erreur arguments - paramètres invalides
    2  Erreur prérequis - dépendances manquantes
    3  Erreur copie - échec transfert du script  
    4  Erreur exécution - échec exécution distante
    5  Erreur nettoyage - échec nettoyage distant

SORTIE JSON:
    {
        "deployment_status": "success|failed",
        "execution_result": {
            "exit_code": 0,
            "stdout": "...",
            "stderr": "...",
            "execution_time": 12.34
        },
        "remote_script_path": "/tmp/script_name.sh",
        "checksum_validated": true,
        "cleanup_performed": true
    }
EOF
}

# === FONCTIONS DE VALIDATION ===
validate_prerequisites() {
    network_debug "Validation des prérequis"
    
    # Vérifier dépendances scripts
    local copy_script="${SCRIPT_DIR}/copy-file.remote.sh"
    local execute_script="${SCRIPT_DIR}/execute-ssh.remote.sh"
    
    if [[ ! -f "$copy_script" ]]; then
        network_error "Script dépendant manquant: $copy_script"
        return $ERROR_PREREQ
    fi
    
    if [[ ! -f "$execute_script" ]]; then
        network_error "Script dépendant manquant: $execute_script"
        return $ERROR_PREREQ
    fi
    
    # Vérifier commandes système
    local required_commands=("ssh" "scp" "shasum")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            network_error "Commande requise manquante: $cmd"
            return $ERROR_PREREQ
        fi
    done
    
    # Vérifier script local
    if [[ ! -f "$SCRIPT_TO_DEPLOY" ]]; then
        network_error "Script à déployer introuvable: $SCRIPT_TO_DEPLOY"
        return $ERROR_PREREQ
    fi
    
    if [[ ! -r "$SCRIPT_TO_DEPLOY" ]]; then
        network_error "Script non lisible: $SCRIPT_TO_DEPLOY"
        return $ERROR_PREREQ
    fi
    
    # Vérifier clé SSH si spécifiée
    if [[ -n "$IDENTITY_FILE" && ! -f "$IDENTITY_FILE" ]]; then
        network_error "Fichier clé SSH introuvable: $IDENTITY_FILE"
        return $ERROR_PREREQ
    fi
    
    network_debug "Prérequis validés avec succès"
    return $SUCCESS
}

# === FONCTIONS PRINCIPALES ===
deploy_and_execute_script() {
    network_info "Démarrage déploiement script: $SCRIPT_TO_DEPLOY -> $REMOTE_HOST"
    
    local script_name
    script_name=$(basename "$SCRIPT_TO_DEPLOY")
    local remote_script_path="${REMOTE_PATH}/${script_name}"
    local local_checksum=""
    local remote_checksum=""
    
    # 1. Calcul checksum local si validation activée
    if [[ "$VALIDATE_CHECKSUM" == "true" ]]; then
        network_debug "Calcul checksum local"
        local_checksum=$(shasum -a 256 "$SCRIPT_TO_DEPLOY" | cut -d' ' -f1)
        network_debug "Checksum local: $local_checksum"
    fi
    
    # 2. Copie du script vers l'hôte distant
    network_info "Copie script vers $REMOTE_HOST:$remote_script_path"
    
    local copy_cmd=(
        "${SCRIPT_DIR}/copy-file.remote.sh"
        "--source" "$SCRIPT_TO_DEPLOY"
        "--destination" "$remote_script_path"
        "--host" "$REMOTE_HOST"
        "--user" "$REMOTE_USER"
        "--direction" "upload"
    )
    
    [[ -n "$IDENTITY_FILE" ]] && copy_cmd+=("--identity" "$IDENTITY_FILE")
    [[ "$SSH_PORT" != "22" ]] && copy_cmd+=("--port" "$SSH_PORT")
    [[ "$QUIET" == "true" ]] && copy_cmd+=("--quiet")
    [[ "$DEBUG" == "true" ]] && copy_cmd+=("--debug")
    
    network_debug "Commande copie: ${copy_cmd[*]}"
    
    if ! "${copy_cmd[@]}"; then
        network_error "Échec copie du script"
        return $ERROR_COPY
    fi
    
    network_info "Script copié avec succès"
    
    # 3. Validation checksum distant si activée
    if [[ "$VALIDATE_CHECKSUM" == "true" ]]; then
        network_debug "Validation checksum distant"
        
        local checksum_cmd="shasum -a 256 '$remote_script_path' | cut -d' ' -f1"
        local execute_checksum_cmd=(
            "${SCRIPT_DIR}/execute-ssh.remote.sh"
            "--host" "$REMOTE_HOST"
            "--user" "$REMOTE_USER"
            "--command" "$checksum_cmd"
            "--timeout" "30"
        )
        
        [[ -n "$IDENTITY_FILE" ]] && execute_checksum_cmd+=("--identity" "$IDENTITY_FILE")
        [[ "$SSH_PORT" != "22" ]] && execute_checksum_cmd+=("--port" "$SSH_PORT")
        [[ "$QUIET" == "true" ]] && execute_checksum_cmd+=("--quiet")
        
        if ! remote_checksum_result=$(execute "${execute_checksum_cmd[@]}"); then
            network_error "Échec validation checksum distant"
            return $ERROR_EXECUTION
        fi
        
        # Extraction checksum depuis JSON de sortie
        remote_checksum=$(echo "$remote_checksum_result" | jq -r '.stdout // empty' | tr -d '\n\r ')
        
        if [[ "$local_checksum" != "$remote_checksum" ]]; then
            network_error "Checksums différents - corruption possible"
            network_error "Local: $local_checksum, Distant: $remote_checksum"
            return $ERROR_COPY
        fi
        
        network_debug "Checksum validé: $remote_checksum"
    fi
    
    # 4. Rendre le script exécutable
    network_debug "Application permissions exécution"
    local chmod_cmd="chmod +x '$remote_script_path'"
    local execute_chmod_cmd=(
        "${SCRIPT_DIR}/execute-ssh.remote.sh"
        "--host" "$REMOTE_HOST"
        "--user" "$REMOTE_USER"  
        "--command" "$chmod_cmd"
        "--timeout" "30"
    )
    
    [[ -n "$IDENTITY_FILE" ]] && execute_chmod_cmd+=("--identity" "$IDENTITY_FILE")
    [[ "$SSH_PORT" != "22" ]] && execute_chmod_cmd+=("--port" "$SSH_PORT")
    [[ "$QUIET" == "true" ]] && execute_chmod_cmd+=("--quiet")
    
    if ! "${execute_chmod_cmd[@]}" >/dev/null; then
        network_error "Échec application permissions"
        return $ERROR_EXECUTION
    fi
    
    # 5. Exécution du script distant
    network_info "Exécution script distant: $remote_script_path"
    
    local exec_command="'$remote_script_path'"
    [[ -n "$EXECUTION_PARAMS" ]] && exec_command="$exec_command $EXECUTION_PARAMS"
    
    local execute_cmd=(
        "${SCRIPT_DIR}/execute-ssh.remote.sh"
        "--host" "$REMOTE_HOST"
        "--user" "$REMOTE_USER"
        "--command" "$exec_command"
        "--timeout" "$TIMEOUT"
    )
    
    [[ -n "$IDENTITY_FILE" ]] && execute_cmd+=("--identity" "$IDENTITY_FILE")
    [[ "$SSH_PORT" != "22" ]] && execute_cmd+=("--port" "$SSH_PORT")
    [[ "$QUIET" == "true" ]] && execute_cmd+=("--quiet")
    [[ "$DEBUG" == "true" ]] && execute_cmd+=("--debug")
    
    network_debug "Commande exécution: ${execute_cmd[*]}"
    
    local execution_result
    if ! execution_result=$("${execute_cmd[@]}"); then
        network_error "Échec exécution script distant"
        return $ERROR_EXECUTION
    fi
    
    # 6. Nettoyage si demandé
    local cleanup_status="false"
    if [[ "$CLEANUP_REMOTE" == "true" ]]; then
        network_debug "Nettoyage fichier distant: $remote_script_path"
        
        local rm_cmd="rm -f '$remote_script_path'"
        local execute_rm_cmd=(
            "${SCRIPT_DIR}/execute-ssh.remote.sh"
            "--host" "$REMOTE_HOST"
            "--user" "$REMOTE_USER"
            "--command" "$rm_cmd"
            "--timeout" "30"
        )
        
        [[ -n "$IDENTITY_FILE" ]] && execute_rm_cmd+=("--identity" "$IDENTITY_FILE")
        [[ "$SSH_PORT" != "22" ]] && execute_rm_cmd+=("--port" "$SSH_PORT")
        [[ "$QUIET" == "true" ]] && execute_rm_cmd+=("--quiet")
        
        if "${execute_rm_cmd[@]}" >/dev/null; then
            cleanup_status="true"
            network_debug "Nettoyage effectué"
        else
            network_warn "Échec nettoyage - fichier distant peut persister"
        fi
    fi
    
    # 7. Construction résultat
    network_info "Déploiement et exécution terminés avec succès"
    
    # Stockage des résultats globaux
    DEPLOYMENT_STATUS="success"
    EXECUTION_RESULT="$execution_result"
    REMOTE_SCRIPT_PATH="$remote_script_path"  
    CHECKSUM_VALIDATED="$([[ "$VALIDATE_CHECKSUM" == "true" ]] && echo "true" || echo "false")"
    CLEANUP_PERFORMED="$cleanup_status"
    
    return $SUCCESS
}

# === FONCTION DE SORTIE JSON ===
build_json_output() {
    local status="$1"
    
    if [[ "$status" == "success" ]]; then
        cat << EOF
{
    "deployment_status": "$DEPLOYMENT_STATUS",
    "execution_result": $EXECUTION_RESULT,
    "remote_script_path": "$REMOTE_SCRIPT_PATH",
    "checksum_validated": $CHECKSUM_VALIDATED,
    "cleanup_performed": $CLEANUP_PERFORMED
}
EOF
    else
        cat << EOF
{
    "deployment_status": "failed",
    "execution_result": null,
    "remote_script_path": null,
    "checksum_validated": false,
    "cleanup_performed": false,
    "error": "Deployment failed"
}
EOF
    fi
}

# === NETTOYAGE ===
cleanup() {
    local exit_code=$?
    network_debug "Nettoyage avec code de sortie: $exit_code"
    
    # Nettoyage fichiers temporaires locaux si nécessaire
    # (actuellement aucun fichier temporaire local créé)
    
    exit $exit_code
}

trap cleanup EXIT ERR INT TERM

# === PARSING DES ARGUMENTS ===
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--script)
                SCRIPT_TO_DEPLOY="$2"
                shift 2
                ;;
            -h|--host)
                REMOTE_HOST="$2"
                shift 2
                ;;
            -u|--user)
                REMOTE_USER="$2"
                shift 2
                ;;
            -p|--path)
                REMOTE_PATH="$2"
                shift 2
                ;;
            -i|--identity)
                IDENTITY_FILE="$2"
                shift 2
                ;;
            -P|--port)
                SSH_PORT="$2"
                shift 2
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            -a|--args)
                EXECUTION_PARAMS="$2"
                shift 2
                ;;
            --no-cleanup)
                CLEANUP_REMOTE="false"
                shift
                ;;
            --no-checksum)
                VALIDATE_CHECKSUM="false"
                shift
                ;;
            --no-log)
                LOG_EXECUTION="false"
                shift
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            -d|--debug)
                DEBUG=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            --help)
                show_help
                exit $SUCCESS
                ;;
            *)
                network_error "Argument inconnu: $1"
                show_help >&2
                exit $ERROR_ARGS
                ;;
        esac
    done
}

# === FONCTION PRINCIPALE ===
main() {
    network_info "=== $SCRIPT_NAME v$SCRIPT_VERSION ==="
    
    # Parse des arguments
    if ! parse_args "$@"; then
        network_error "Erreur parsing arguments"
        exit $ERROR_ARGS
    fi
    
    # Validation arguments requis
    if [[ -z "$SCRIPT_TO_DEPLOY" || -z "$REMOTE_HOST" || -z "$REMOTE_USER" ]]; then
        network_error "Arguments requis manquants: --script, --host, --user"
        show_help >&2
        exit $ERROR_ARGS
    fi
    
    # Validation prérequis
    if ! validate_prerequisites; then
        network_error "Échec validation prérequis"
        exit $ERROR_PREREQ
    fi
    
    # Exécution principale
    if deploy_and_execute_script; then
        build_json_output "success"
        network_info "=== Déploiement réussi ==="
        exit $SUCCESS
    else
        local error_code=$?
        build_json_output "failed"
        network_error "=== Déploiement échoué ==="
        exit $error_code
    fi
}

# === EXÉCUTION ===
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi