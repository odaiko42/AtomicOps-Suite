#!/usr/bin/env bash

# ==============================================================================
# Script Orchestrateur: network-setup-deployment.sh
# Description: Orchestrateur pour déploiement réseau complet (SSH + SCP + HTTP)
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

SCRIPT_NAME="network-setup-deployment.sh"
SCRIPT_VERSION="1.0"
DEBUG=${DEBUG:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
JSON_ONLY=${JSON_ONLY:-0}

# Chemin vers les scripts atomiques
ATOMIC_SCRIPTS_DIR="${ATOMIC_SCRIPTS_DIR:-$(dirname "$0")/../../atomics/network}"

# Variables de configuration serveur cible
TARGET_HOST=""
TARGET_USER=""
TARGET_PORT=${TARGET_PORT:-22}
TARGET_KEY=""
TARGET_PASSWORD=""

# Configuration de déploiement
DEPLOYMENT_PACKAGE=""  # Package/répertoire local à déployer
REMOTE_DEPLOY_PATH=""  # Chemin de déploiement distant
SERVICE_ENDPOINT=""    # URL HTTP à tester après déploiement
ROLLBACK_ON_FAILURE=${ROLLBACK_ON_FAILURE:-1}

# Variables de résultat de l'orchestration
TOTAL_STEPS=5
CURRENT_STEP=0
STEPS_STATUS=()
SSH_CONNECTION_OK=0
DEPLOYMENT_OK=0
SERVICE_HEALTH_OK=0
ERROR_LOGS=""

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
Usage: network-setup-deployment.sh [OPTIONS] --host <host> --user <user> --package <path> --remote <path>

Description:
    Orchestrateur de déploiement réseau complet. Effectue les étapes suivantes :
    1. Test de connectivité SSH
    2. Préparation de l'environnement distant
    3. Transfert du package de déploiement
    4. Exécution des scripts de déploiement
    5. Vérification de santé des services

Arguments obligatoires:
    --host <hostname>        Serveur cible du déploiement
    --user <username>        Utilisateur pour la connexion
    --package <path>         Package/répertoire local à déployer
    --remote <path>          Répertoire de déploiement distant

Options:
    -h, --help              Afficher cette aide
    -v, --verbose          Mode verbeux (affichage détaillé)
    -d, --debug            Mode debug (informations de débogage)
    -q, --quiet            Mode silencieux (erreurs seulement)
    -j, --json-only        Sortie JSON uniquement (sans logs)

Options de connexion:
    -p, --port <port>      Port SSH (défaut: 22)
    -k, --key <path>       Clé privée SSH
    --password <pass>      Mot de passe SSH (non recommandé)

Options de déploiement:
    --endpoint <url>       URL de vérification de santé après déploiement
    --no-rollback          Désactiver le rollback en cas d'échec
    --atomic-dir <path>    Répertoire des scripts atomiques

Variables d'environnement:
    TARGET_HOST            Serveur cible par défaut
    TARGET_USER            Utilisateur par défaut
    TARGET_PORT            Port par défaut (22)
    TARGET_KEY             Clé privée par défaut
    ATOMIC_SCRIPTS_DIR     Répertoire des scripts atomiques
    ROLLBACK_ON_FAILURE    Rollback automatique (défaut: 1)

Sortie JSON:
    {
      "status": "success|error",
      "code": 0|1|2|3|4,
      "timestamp": "ISO8601",
      "script": "network-setup-deployment.sh",
      "message": "Description du résultat",
      "data": {
        "orchestration": {
          "total_steps": 5,
          "completed_steps": 3,
          "current_step": "deployment_transfer",
          "progress_percent": 60
        },
        "steps": [
          {"name": "ssh_connectivity", "status": "success", "duration_ms": 1234},
          {"name": "environment_prep", "status": "success", "duration_ms": 2345},
          {"name": "deployment_transfer", "status": "error", "duration_ms": 5678}
        ],
        "target_server": {
          "host": "server.example.com",
          "user": "deploy",
          "port": 22,
          "connection_successful": true
        },
        "deployment": {
          "package_path": "/local/package",
          "remote_path": "/opt/app",
          "transfer_successful": false,
          "rollback_performed": true
        }
      }
    }

Codes de sortie:
    0 - Déploiement réussi complet
    1 - Erreur de paramètres ou configuration
    2 - Échec de connectivité réseau/SSH
    3 - Échec de transfert/déploiement
    4 - Échec de vérification de santé

Exemples:
    # Déploiement complet avec vérification
    ./network-setup-deployment.sh \
        --host production-server.com \
        --user deploy --key ~/.ssh/deploy_key \
        --package ./dist/myapp \
        --remote /opt/myapp \
        --endpoint https://production-server.com/health

    # Déploiement sans rollback automatique
    ./network-setup-deployment.sh \
        --host staging.example.com \
        --user admin --password secretpass \
        --package ./build --remote /tmp/test-deploy \
        --no-rollback
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
                TARGET_HOST="$2"
                shift
                ;;
            --user)
                [[ -z "${2:-}" ]] && die "Option --user nécessite une valeur" 1
                TARGET_USER="$2"
                shift
                ;;
            --package)
                [[ -z "${2:-}" ]] && die "Option --package nécessite une valeur" 1
                DEPLOYMENT_PACKAGE="$2"
                shift
                ;;
            --remote)
                [[ -z "${2:-}" ]] && die "Option --remote nécessite une valeur" 1
                REMOTE_DEPLOY_PATH="$2"
                shift
                ;;
            -p|--port)
                [[ -z "${2:-}" ]] && die "Option --port nécessite une valeur" 1
                TARGET_PORT="$2"
                shift
                ;;
            -k|--key)
                [[ -z "${2:-}" ]] && die "Option --key nécessite une valeur" 1
                TARGET_KEY="$2"
                shift
                ;;
            --password)
                [[ -z "${2:-}" ]] && die "Option --password nécessite une valeur" 1
                TARGET_PASSWORD="$2"
                shift
                ;;
            --endpoint)
                [[ -z "${2:-}" ]] && die "Option --endpoint nécessite une valeur" 1
                SERVICE_ENDPOINT="$2"
                shift
                ;;
            --no-rollback)
                ROLLBACK_ON_FAILURE=0
                ;;
            --atomic-dir)
                [[ -z "${2:-}" ]] && die "Option --atomic-dir nécessite une valeur" 1
                ATOMIC_SCRIPTS_DIR="$2"
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
    [[ -z "$TARGET_HOST" ]] && die "Paramètre --host obligatoire" 1
    [[ -z "$TARGET_USER" ]] && die "Paramètre --user obligatoire" 1
    [[ -z "$DEPLOYMENT_PACKAGE" ]] && die "Paramètre --package obligatoire" 1
    [[ -z "$REMOTE_DEPLOY_PATH" ]] && die "Paramètre --remote obligatoire" 1
    
    # Validation du package de déploiement
    if [[ ! -e "$DEPLOYMENT_PACKAGE" ]]; then
        die "Package de déploiement non trouvé: $DEPLOYMENT_PACKAGE" 1
    fi
    
    # Validation de la clé privée si spécifiée
    if [[ -n "$TARGET_KEY" ]] && [[ ! -r "$TARGET_KEY" ]]; then
        die "Clé privée non accessible: $TARGET_KEY" 1
    fi
    
    # Vérification de l'existence des scripts atomiques
    local required_scripts=(
        "ssh-connect.sh"
        "ssh-execute-command.sh"
        "scp-transfer.sh"
        "http-request.sh"
    )
    
    for script in "${required_scripts[@]}"; do
        if [[ ! -x "$ATOMIC_SCRIPTS_DIR/$script" ]]; then
            die "Script atomique manquant ou non exécutable: $ATOMIC_SCRIPTS_DIR/$script" 1
        fi
    done
    
    log_debug "Validation réussie"
    log_info "Déploiement orchestré vers $TARGET_USER@$TARGET_HOST:$TARGET_PORT"
    
    return 0
}

# =============================================================================
# Fonctions d'Orchestration
# =============================================================================

# Mise à jour du statut d'une étape
update_step_status() {
    local step_name="$1"
    local status="$2"
    local duration="${3:-0}"
    
    CURRENT_STEP=$((CURRENT_STEP + 1))
    STEPS_STATUS+=("{\"name\":\"$step_name\",\"status\":\"$status\",\"duration_ms\":$duration}")
    
    local progress=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    log_info "Étape $CURRENT_STEP/$TOTAL_STEPS: $step_name [$status] ($progress%)"
}

# Exécution d'un script atomique avec logging
execute_atomic_script() {
    local script_name="$1"
    shift
    local script_args=("$@")
    
    local script_path="$ATOMIC_SCRIPTS_DIR/$script_name"
    log_debug "Exécution: $script_path ${script_args[*]}"
    
    local start_time=$(date +%s%3N)
    local result=""
    local exit_code=0
    
    if result=$("$script_path" --json-only "${script_args[@]}" 2>&1); then
        exit_code=0
    else
        exit_code=$?
    fi
    
    local end_time=$(date +%s%3N)
    local duration=$((end_time - start_time))
    
    log_debug "Script $script_name terminé (code: $exit_code, durée: ${duration}ms)"
    
    # Retourner le résultat JSON et le code de sortie
    echo "$result"
    return $exit_code
}

# Étape 1: Test de connectivité SSH
step_ssh_connectivity() {
    log_info "=== ÉTAPE 1: Test de connectivité SSH ==="
    
    local start_time=$(date +%s%3N)
    local ssh_args=(
        --host "$TARGET_HOST"
        --user "$TARGET_USER"
        --port "$TARGET_PORT"
    )
    
    if [[ -n "$TARGET_KEY" ]]; then
        ssh_args+=(--key "$TARGET_KEY")
    fi
    
    local ssh_result
    if ssh_result=$(execute_atomic_script "ssh-connect.sh" "${ssh_args[@]}"); then
        local end_time=$(date +%s%3N)
        local duration=$((end_time - start_time))
        
        SSH_CONNECTION_OK=1
        update_step_status "ssh_connectivity" "success" "$duration"
        log_info "Connectivité SSH établie avec succès"
        return 0
    else
        local end_time=$(date +%s%3N)
        local duration=$((end_time - start_time))
        
        update_step_status "ssh_connectivity" "error" "$duration"
        ERROR_LOGS+="SSH Connectivity: $(echo "$ssh_result" | jq -r '.message // "Unknown error"')\n"
        log_error "Échec de connectivité SSH"
        return 2
    fi
}

# Étape 2: Préparation de l'environnement distant
step_environment_preparation() {
    log_info "=== ÉTAPE 2: Préparation environnement distant ==="
    
    local start_time=$(date +%s%3N)
    
    # Commandes de préparation
    local prep_commands=(
        "mkdir -p '$REMOTE_DEPLOY_PATH'"
        "mkdir -p '$REMOTE_DEPLOY_PATH/backup'"
        "mkdir -p '$REMOTE_DEPLOY_PATH/logs'"
        "chmod 755 '$REMOTE_DEPLOY_PATH'"
    )
    
    for cmd in "${prep_commands[@]}"; do
        local exec_args=(
            --host "$TARGET_HOST"
            --user "$TARGET_USER"
            --port "$TARGET_PORT"
            --command "$cmd"
        )
        
        if [[ -n "$TARGET_KEY" ]]; then
            exec_args+=(--key "$TARGET_KEY")
        fi
        
        local exec_result
        if ! exec_result=$(execute_atomic_script "ssh-execute-command.sh" "${exec_args[@]}"); then
            local end_time=$(date +%s%3N)
            local duration=$((end_time - start_time))
            
            update_step_status "environment_prep" "error" "$duration"
            ERROR_LOGS+="Environment Prep: $(echo "$exec_result" | jq -r '.message // "Unknown error"')\n"
            log_error "Échec de préparation de l'environnement"
            return 3
        fi
        
        log_debug "Commande réussie: $cmd"
    done
    
    local end_time=$(date +%s%3N)
    local duration=$((end_time - start_time))
    
    update_step_status "environment_prep" "success" "$duration"
    log_info "Environnement distant préparé"
    return 0
}

# Étape 3: Sauvegarde de l'existant (si applicable)
step_backup_existing() {
    log_info "=== ÉTAPE 3: Sauvegarde de l'existant ==="
    
    local start_time=$(date +%s%3N)
    
    # Vérifier si le répertoire de déploiement existe déjà
    local check_args=(
        --host "$TARGET_HOST"
        --user "$TARGET_USER"
        --port "$TARGET_PORT"
        --command "[ -d '$REMOTE_DEPLOY_PATH/current' ] && echo 'exists' || echo 'new'"
    )
    
    if [[ -n "$TARGET_KEY" ]]; then
        check_args+=(--key "$TARGET_KEY")
    fi
    
    local check_result
    if check_result=$(execute_atomic_script "ssh-execute-command.sh" "${check_args[@]}"); then
        local check_output=$(echo "$check_result" | jq -r '.data.output.stdout // ""')
        
        if [[ "$check_output" == "exists" ]]; then
            log_info "Déploiement existant détecté - Création de sauvegarde"
            
            local backup_args=(
                --host "$TARGET_HOST"
                --user "$TARGET_USER"
                --port "$TARGET_PORT"
                --command "cp -r '$REMOTE_DEPLOY_PATH/current' '$REMOTE_DEPLOY_PATH/backup/backup-$(date +%Y%m%d-%H%M%S)'"
            )
            
            if [[ -n "$TARGET_KEY" ]]; then
                backup_args+=(--key "$TARGET_KEY")
            fi
            
            if ! execute_atomic_script "ssh-execute-command.sh" "${backup_args[@]}" >/dev/null; then
                log_warn "Échec de création de sauvegarde (continuation du déploiement)"
            else
                log_info "Sauvegarde créée avec succès"
            fi
        else
            log_info "Nouveau déploiement - Pas de sauvegarde nécessaire"
        fi
    fi
    
    local end_time=$(date +%s%3N)
    local duration=$((end_time - start_time))
    
    update_step_status "backup_existing" "success" "$duration"
    return 0
}

# Étape 4: Transfert du package de déploiement
step_deployment_transfer() {
    log_info "=== ÉTAPE 4: Transfert du package ==="
    
    local start_time=$(date +%s%3N)
    
    local transfer_args=(
        --host "$TARGET_HOST"
        --user "$TARGET_USER"
        --port "$TARGET_PORT"
        --mode "upload"
        --local "$DEPLOYMENT_PACKAGE"
        --remote "$REMOTE_DEPLOY_PATH/current"
    )
    
    if [[ -n "$TARGET_KEY" ]]; then
        transfer_args+=(--key "$TARGET_KEY")
    fi
    
    if [[ -d "$DEPLOYMENT_PACKAGE" ]]; then
        transfer_args+=(--recursive)
    fi
    
    local transfer_result
    if transfer_result=$(execute_atomic_script "scp-transfer.sh" "${transfer_args[@]}"); then
        local end_time=$(date +%s%3N)
        local duration=$((end_time - start_time))
        
        DEPLOYMENT_OK=1
        update_step_status "deployment_transfer" "success" "$duration"
        
        # Extraction des métriques de transfert
        local transfer_size=$(echo "$transfer_result" | jq -r '.data.performance.size_bytes // 0')
        local transfer_speed=$(echo "$transfer_result" | jq -r '.data.performance.speed_kbps // 0')
        
        log_info "Transfert réussi: $transfer_size octets à ${transfer_speed} KB/s"
        return 0
    else
        local end_time=$(date +%s%3N)
        local duration=$((end_time - start_time))
        
        update_step_status "deployment_transfer" "error" "$duration"
        ERROR_LOGS+="Deployment Transfer: $(echo "$transfer_result" | jq -r '.message // "Unknown error"')\n"
        log_error "Échec du transfert de déploiement"
        return 3
    fi
}

# Étape 5: Vérification de santé du service
step_service_health_check() {
    log_info "=== ÉTAPE 5: Vérification de santé ==="
    
    if [[ -z "$SERVICE_ENDPOINT" ]]; then
        log_info "Pas d'endpoint configuré - Vérification passée"
        update_step_status "service_health" "skipped" "0"
        return 0
    fi
    
    local start_time=$(date +%s%3N)
    
    # Attendre quelques secondes pour que le service démarre
    log_info "Attente du démarrage du service (10s)..."
    sleep 10
    
    local health_args=(
        --url "$SERVICE_ENDPOINT"
        --method "GET"
        --timeout 15
    )
    
    local health_result
    if health_result=$(execute_atomic_script "http-request.sh" "${health_args[@]}"); then
        local end_time=$(date +%s%3N)
        local duration=$((end_time - start_time))
        
        local status_code=$(echo "$health_result" | jq -r '.data.response.status_code // 0')
        
        if [[ $status_code -ge 200 ]] && [[ $status_code -lt 400 ]]; then
            SERVICE_HEALTH_OK=1
            update_step_status "service_health" "success" "$duration"
            log_info "Vérification de santé réussie (HTTP $status_code)"
            return 0
        else
            update_step_status "service_health" "error" "$duration"
            ERROR_LOGS+="Service Health: HTTP $status_code\n"
            log_error "Vérification de santé échouée (HTTP $status_code)"
            return 4
        fi
    else
        local end_time=$(date +%s%3N)
        local duration=$((end_time - start_time))
        
        update_step_status "service_health" "error" "$duration"
        ERROR_LOGS+="Service Health: $(echo "$health_result" | jq -r '.message // "Connection failed"')\n"
        log_error "Vérification de santé échouée - Service inaccessible"
        return 4
    fi
}

# Fonction de rollback en cas d'échec
perform_rollback() {
    if [[ $ROLLBACK_ON_FAILURE -eq 0 ]]; then
        log_info "Rollback désactivé - Pas de restauration automatique"
        return 0
    fi
    
    log_warn "=== ROLLBACK: Restauration de la sauvegarde ==="
    
    local rollback_args=(
        --host "$TARGET_HOST"
        --user "$TARGET_USER"
        --port "$TARGET_PORT"
        --command "rm -rf '$REMOTE_DEPLOY_PATH/current' && mv '$REMOTE_DEPLOY_PATH/backup'/* '$REMOTE_DEPLOY_PATH/current' 2>/dev/null || echo 'No backup to restore'"
    )
    
    if [[ -n "$TARGET_KEY" ]]; then
        rollback_args+=(--key "$TARGET_KEY")
    fi
    
    if execute_atomic_script "ssh-execute-command.sh" "${rollback_args[@]}" >/dev/null; then
        log_warn "Rollback effectué avec succès"
    else
        log_error "Échec du rollback"
    fi
}

# Orchestration principale
orchestrate() {
    log_debug "Démarrage de l'orchestration de déploiement"
    
    local overall_success=1
    local failed_step=""
    
    # Étape 1: Connectivité SSH
    if ! step_ssh_connectivity; then
        overall_success=0
        failed_step="ssh_connectivity"
    fi
    
    # Étape 2: Préparation environnement (si SSH OK)
    if [[ $overall_success -eq 1 ]] && ! step_environment_preparation; then
        overall_success=0
        failed_step="environment_prep"
    fi
    
    # Étape 3: Sauvegarde existant
    if [[ $overall_success -eq 1 ]] && ! step_backup_existing; then
        overall_success=0
        failed_step="backup_existing"
    fi
    
    # Étape 4: Transfert déploiement
    if [[ $overall_success -eq 1 ]] && ! step_deployment_transfer; then
        overall_success=0
        failed_step="deployment_transfer"
    fi
    
    # Étape 5: Vérification santé (si transfert OK)
    if [[ $overall_success -eq 1 ]] && ! step_service_health_check; then
        overall_success=0
        failed_step="service_health"
    fi
    
    # Gestion des échecs avec rollback potentiel
    if [[ $overall_success -eq 0 ]]; then
        log_error "Échec à l'étape: $failed_step"
        
        # Rollback si déploiement a commencé
        if [[ "$failed_step" == "deployment_transfer" ]] || [[ "$failed_step" == "service_health" ]]; then
            perform_rollback
        fi
        
        case "$failed_step" in
            "ssh_connectivity"|"environment_prep"|"backup_existing")
                return 2  # Erreur de connectivité/préparation
                ;;
            "deployment_transfer")
                return 3  # Erreur de déploiement
                ;;
            "service_health")
                return 4  # Erreur de santé service
                ;;
        esac
    else
        log_info "=== DÉPLOIEMENT TERMINÉ AVEC SUCCÈS ==="
        return 0
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
    
    # Construction du tableau des étapes
    local steps_json="["
    local first=1
    for step in "${STEPS_STATUS[@]}"; do
        if [[ $first -eq 1 ]]; then
            first=0
        else
            steps_json+=", "
        fi
        steps_json+="$step"
    done
    steps_json+="]"
    
    local progress=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    
    cat << EOF
{
  "status": "$status",
  "code": $exit_code,
  "timestamp": "$timestamp",
  "script": "$SCRIPT_NAME",
  "message": "$message",
  "data": {
    "orchestration": {
      "total_steps": $TOTAL_STEPS,
      "completed_steps": $CURRENT_STEP,
      "progress_percent": $progress,
      "rollback_enabled": $([ $ROLLBACK_ON_FAILURE -eq 1 ] && echo "true" || echo "false")
    },
    "steps": $steps_json,
    "target_server": {
      "host": "$TARGET_HOST",
      "user": "$TARGET_USER",
      "port": $TARGET_PORT,
      "connection_successful": $([ $SSH_CONNECTION_OK -eq 1 ] && echo "true" || echo "false")
    },
    "deployment": {
      "package_path": "$DEPLOYMENT_PACKAGE",
      "remote_path": "$REMOTE_DEPLOY_PATH",
      "transfer_successful": $([ $DEPLOYMENT_OK -eq 1 ] && echo "true" || echo "false"),
      "service_healthy": $([ $SERVICE_HEALTH_OK -eq 1 ] && echo "true" || echo "false"),
      "service_endpoint": "${SERVICE_ENDPOINT:-null}"
    },
    "error_logs": "$(echo -e "$ERROR_LOGS" | sed 's/"/\\"/g' | tr '\n' '\\' | sed 's/\\/\\n/g')"
  }
}
EOF
}

# =============================================================================
# Fonction de Nettoyage
# =============================================================================

cleanup() {
    log_debug "Nettoyage des ressources de l'orchestrateur"
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
    local result_message="Déploiement orchestré avec succès"
    
    if orchestrate; then
        result_message="Déploiement réseau complété avec succès ($CURRENT_STEP/$TOTAL_STEPS étapes)"
        exit_code=0
    else
        local orchestration_exit_code=$?
        case $orchestration_exit_code in
            2)
                result_message="Échec de connectivité ou préparation"
                exit_code=2
                ;;
            3)
                result_message="Échec de déploiement/transfert"
                exit_code=3
                ;;
            4)
                result_message="Échec de vérification de santé du service"
                exit_code=4
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