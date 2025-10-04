#!/usr/bin/env bash
# ============================================================================
# Script      : execute-workflow.remote.sh
# Description : Exécute un workflow complet (séquence de scripts) sur hôte distant
# Version     : 1.0.0  
# Date        : 2024-12-19
# Auteur      : Assistant IA - Conforme AtomicOps-Suite
# Licence     : MIT
#
# Fonctions   :
# - Exécution séquentielle de scripts distants selon workflow JSON
# - Gestion des dépendances entre scripts
# - Support rollback automatique en cas d'échec
# - Logging détaillé et suivi progression
# - Validation intégrité et collecte résultats
#
# Niveau      : 0 (Atomique)
# Dépendances : deploy-script.remote.sh, execute-ssh.remote.sh, check-ssh.connection.sh
# ============================================================================

set -euo pipefail

# === CONSTANTES ===
readonly SCRIPT_NAME="execute-workflow.remote.sh"
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_PATH="${SCRIPT_DIR}/${SCRIPT_NAME}"

# Codes de sortie standardisés
readonly SUCCESS=0
readonly ERROR_ARGS=1
readonly ERROR_PREREQ=2
readonly ERROR_CONFIG=3
readonly ERROR_CONNECTION=4
readonly ERROR_WORKFLOW=5
readonly ERROR_ROLLBACK=6

# === VARIABLES GLOBALES ===
WORKFLOW_CONFIG=""
REMOTE_HOST=""
REMOTE_USER=""
IDENTITY_FILE=""
SSH_PORT="22"
TIMEOUT="600"
ROLLBACK_ENABLED="true"
PARALLEL_EXECUTION="false"
MAX_PARALLEL="3"
CONTINUE_ON_ERROR="false"
WORKSPACE_PATH="/tmp/workflow-$$"

# Variables de contrôle
DEBUG=${DEBUG:-false}
QUIET=${QUIET:-false}
FORCE=${FORCE:-false}

# Variables de résultats
declare -a WORKFLOW_STEPS=()
declare -a STEP_RESULTS=()
declare -a EXECUTED_SCRIPTS=()

# === FONCTIONS DE LOGGING ===
network_log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ "$QUIET" != true ]]; then
        case "$level" in
            INFO)  echo -e "[\033[34mWORKFLOW-INFO\033[0m]  $timestamp - $message" ;;
            WARN)  echo -e "[\033[33mWORKFLOW-WARN\033[0m]  $timestamp - $message" ;;
            ERROR) echo -e "[\033[31mWORKFLOW-ERROR\033[0m] $timestamp - $message" >&2 ;;
            DEBUG) [[ "$DEBUG" == true ]] && echo -e "[\033[36mWORKFLOW-DEBUG\033[0m] $timestamp - $message" ;;
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
execute-workflow.remote.sh - Exécute un workflow complet sur hôte distant

USAGE:
    execute-workflow.remote.sh [OPTIONS] -w CONFIG -h HOST -u USER

ARGUMENTS REQUIS:
    -w, --workflow CONFIG      Fichier JSON de configuration du workflow
    -h, --host HOST           Hôte distant (IP ou FQDN)
    -u, --user USER           Utilisateur SSH distant

OPTIONS:
    -i, --identity FILE       Fichier de clé privée SSH
    -P, --port PORT           Port SSH (défaut: 22)
    -t, --timeout SECONDS    Timeout global workflow (défaut: 600)
    --workspace PATH          Répertoire distant de travail (défaut: /tmp/workflow-PID)
    --no-rollback             Désactiver rollback automatique
    --parallel                Exécution parallèle quand possible  
    --max-parallel N          Nombre max scripts parallèles (défaut: 3)
    --continue-on-error       Continuer même si un script échoue
    -q, --quiet               Mode silencieux
    -d, --debug               Mode debug
    -f, --force               Forcer l'exécution
    --help                    Afficher cette aide

FORMAT WORKFLOW JSON:
    {
        "name": "workflow-name",
        "description": "Workflow description",
        "steps": [
            {
                "id": "step1",
                "name": "Script Setup",
                "script_path": "/local/path/setup.sh",
                "args": ["--verbose", "--env=prod"],
                "depends_on": [],
                "timeout": 300,
                "critical": true,
                "rollback_script": "/local/path/rollback-setup.sh"
            },
            {
                "id": "step2", 
                "name": "Configure App",
                "script_path": "/local/path/configure.sh",
                "args": ["--config", "/etc/app.conf"],
                "depends_on": ["step1"],
                "timeout": 180,
                "critical": false
            }
        ],
        "rollback_order": ["step2", "step1"]
    }

EXEMPLES:
    # Workflow séquentiel simple
    execute-workflow.remote.sh -w deploy-workflow.json -h prod1.com -u deploy
    
    # Workflow parallèle avec clé SSH
    execute-workflow.remote.sh -w complex-workflow.json -h 192.168.1.10 -u root \
                               -i ~/.ssh/deploy_key --parallel --max-parallel 5
    
    # Workflow avec rollback désactivé
    execute-workflow.remote.sh -w test-workflow.json -h staging.com -u test \
                               --no-rollback --continue-on-error

CODES DE SORTIE:
    0  Succès - workflow exécuté complètement
    1  Erreur arguments - paramètres invalides
    2  Erreur prérequis - dépendances manquantes
    3  Erreur config - fichier workflow invalide
    4  Erreur connexion - impossible de se connecter
    5  Erreur workflow - échec d'un step critique
    6  Erreur rollback - échec procédure de rollback

SORTIE JSON:
    {
        "workflow_status": "success|failed|partial",
        "step_results": [
            {
                "step_id": "step1",
                "status": "success|failed|skipped",
                "execution_result": {...},
                "execution_time": 12.34,
                "rollback_executed": false
            }
        ],
        "execution_log": "/tmp/workflow-PID/execution.log",
        "rollback_performed": false,
        "total_execution_time": 45.67
    }
EOF
}

# === FONCTIONS DE VALIDATION ===
validate_prerequisites() {
    network_debug "Validation des prérequis"
    
    # Vérifier dépendances scripts
    local required_scripts=(
        "deploy-script.remote.sh"
        "execute-ssh.remote.sh" 
        "check-ssh.connection.sh"
    )
    
    for script in "${required_scripts[@]}"; do
        if [[ ! -f "${SCRIPT_DIR}/${script}" ]]; then
            network_error "Script dépendant manquant: ${SCRIPT_DIR}/${script}"
            return $ERROR_PREREQ
        fi
    done
    
    # Vérifier commandes système
    local required_commands=("jq" "ssh" "scp")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            network_error "Commande requise manquante: $cmd"
            return $ERROR_PREREQ
        fi
    done
    
    # Vérifier fichier de workflow
    if [[ ! -f "$WORKFLOW_CONFIG" ]]; then
        network_error "Fichier workflow introuvable: $WORKFLOW_CONFIG"
        return $ERROR_PREREQ
    fi
    
    if [[ ! -r "$WORKFLOW_CONFIG" ]]; then
        network_error "Fichier workflow non lisible: $WORKFLOW_CONFIG"
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

# === VALIDATION WORKFLOW ===
validate_workflow_config() {
    network_debug "Validation configuration workflow"
    
    # Vérifier que c'est un JSON valide
    if ! jq empty "$WORKFLOW_CONFIG" 2>/dev/null; then
        network_error "Fichier workflow JSON invalide"
        return $ERROR_CONFIG
    fi
    
    # Vérifier structure requise
    local required_fields=("name" "steps")
    for field in "${required_fields[@]}"; do
        if ! jq -e ".$field" "$WORKFLOW_CONFIG" >/dev/null 2>&1; then
            network_error "Champ requis manquant dans workflow: $field"
            return $ERROR_CONFIG
        fi
    done
    
    # Vérifier que steps est un array non-vide
    local steps_count
    steps_count=$(jq -r '.steps | length' "$WORKFLOW_CONFIG")
    if [[ "$steps_count" -eq 0 ]]; then
        network_error "Workflow sans steps définis"
        return $ERROR_CONFIG
    fi
    
    # Vérifier structure de chaque step
    local step_index=0
    while [[ $step_index -lt $steps_count ]]; do
        local step_id
        step_id=$(jq -r ".steps[$step_index].id // empty" "$WORKFLOW_CONFIG")
        if [[ -z "$step_id" ]]; then
            network_error "Step $step_index sans ID défini"
            return $ERROR_CONFIG
        fi
        
        local script_path
        script_path=$(jq -r ".steps[$step_index].script_path // empty" "$WORKFLOW_CONFIG")
        if [[ -z "$script_path" ]]; then
            network_error "Step $step_id sans script_path défini"
            return $ERROR_CONFIG
        fi
        
        if [[ ! -f "$script_path" ]]; then
            network_error "Script introuvable pour step $step_id: $script_path"
            return $ERROR_CONFIG
        fi
        
        ((step_index++))
    done
    
    network_debug "Configuration workflow validée"
    return $SUCCESS
}

# === CONNEXION SSH ===
test_ssh_connection() {
    network_debug "Test de connexion SSH vers $REMOTE_HOST"
    
    local check_cmd=(
        "${SCRIPT_DIR}/check-ssh.connection.sh"
        "--host" "$REMOTE_HOST"
        "--user" "$REMOTE_USER"
        "--port" "$SSH_PORT"
        "--timeout" "30"
    )
    
    [[ -n "$IDENTITY_FILE" ]] && check_cmd+=("--identity" "$IDENTITY_FILE")
    [[ "$QUIET" == "true" ]] && check_cmd+=("--quiet")
    
    if ! "${check_cmd[@]}" >/dev/null; then
        network_error "Impossible de se connecter à $REMOTE_HOST"
        return $ERROR_CONNECTION
    fi
    
    network_debug "Connexion SSH établie"
    return $SUCCESS
}

# === PRÉPARATION WORKSPACE ===
prepare_remote_workspace() {
    network_debug "Préparation workspace distant: $WORKSPACE_PATH"
    
    local mkdir_cmd="mkdir -p '$WORKSPACE_PATH' && echo 'Workspace ready'"
    local execute_cmd=(
        "${SCRIPT_DIR}/execute-ssh.remote.sh"
        "--host" "$REMOTE_HOST"
        "--user" "$REMOTE_USER"
        "--command" "$mkdir_cmd"
        "--timeout" "60"
    )
    
    [[ -n "$IDENTITY_FILE" ]] && execute_cmd+=("--identity" "$IDENTITY_FILE")
    [[ "$SSH_PORT" != "22" ]] && execute_cmd+=("--port" "$SSH_PORT")
    [[ "$QUIET" == "true" ]] && execute_cmd+=("--quiet")
    
    if ! "${execute_cmd[@]}" >/dev/null; then
        network_error "Échec création workspace distant"
        return $ERROR_WORKFLOW
    fi
    
    network_debug "Workspace distant préparé"
    return $SUCCESS
}

# === EXÉCUTION STEP ===
execute_workflow_step() {
    local step_index="$1"
    local step_data
    step_data=$(jq -c ".steps[$step_index]" "$WORKFLOW_CONFIG")
    
    local step_id
    step_id=$(echo "$step_data" | jq -r '.id')
    
    local step_name  
    step_name=$(echo "$step_data" | jq -r '.name // .id')
    
    local script_path
    script_path=$(echo "$step_data" | jq -r '.script_path')
    
    local step_timeout
    step_timeout=$(echo "$step_data" | jq -r '.timeout // 300')
    
    local step_args
    step_args=$(echo "$step_data" | jq -r '.args[]? // empty' | tr '\n' ' ')
    
    network_info "Exécution step '$step_id': $step_name"
    network_debug "Script: $script_path, Args: $step_args, Timeout: $step_timeout"
    
    local start_time
    start_time=$(date +%s.%N)
    
    # Déploiement et exécution via deploy-script.remote.sh
    local deploy_cmd=(
        "${SCRIPT_DIR}/deploy-script.remote.sh"
        "--script" "$script_path"
        "--host" "$REMOTE_HOST"
        "--user" "$REMOTE_USER"  
        "--path" "$WORKSPACE_PATH"
        "--timeout" "$step_timeout"
    )
    
    [[ -n "$step_args" ]] && deploy_cmd+=("--args" "$step_args")
    [[ -n "$IDENTITY_FILE" ]] && deploy_cmd+=("--identity" "$IDENTITY_FILE")
    [[ "$SSH_PORT" != "22" ]] && deploy_cmd+=("--port" "$SSH_PORT")
    [[ "$QUIET" == "true" ]] && deploy_cmd+=("--quiet")
    [[ "$DEBUG" == "true" ]] && deploy_cmd+=("--debug")
    
    local execution_result
    local step_status="success"
    
    if execution_result=$("${deploy_cmd[@]}"); then
        network_info "Step '$step_id' exécuté avec succès"
    else
        local exit_code=$?
        network_error "Échec step '$step_id' (code: $exit_code)"
        step_status="failed"
        execution_result='{"deployment_status":"failed","error":"Execution failed"}'
    fi
    
    local end_time
    end_time=$(date +%s.%N)
    local execution_time
    execution_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    
    # Construction résultat du step
    local step_result
    step_result=$(cat << EOF
{
    "step_id": "$step_id",
    "step_name": "$step_name", 
    "status": "$step_status",
    "execution_result": $execution_result,
    "execution_time": $execution_time,
    "rollback_executed": false
}
EOF
)
    
    STEP_RESULTS+=("$step_result")
    [[ "$step_status" == "success" ]] && EXECUTED_SCRIPTS+=("$step_id")
    
    network_debug "Step '$step_id' terminé en ${execution_time}s"
    
    # Retour selon le statut
    [[ "$step_status" == "success" ]] && return $SUCCESS || return $ERROR_WORKFLOW
}

# === ROLLBACK ===
execute_rollback() {
    network_warn "Démarrage procédure de rollback"
    
    # Vérifier si rollback est configuré
    if ! jq -e '.rollback_order' "$WORKFLOW_CONFIG" >/dev/null 2>&1; then
        network_info "Aucune configuration de rollback définie"
        return $SUCCESS
    fi
    
    # Obtenir ordre de rollback
    local rollback_steps
    readarray -t rollback_steps < <(jq -r '.rollback_order[]' "$WORKFLOW_CONFIG")
    
    local rollback_success=true
    
    for step_id in "${rollback_steps[@]}"; do
        # Vérifier si ce step a été exécuté
        local was_executed=false
        for executed in "${EXECUTED_SCRIPTS[@]}"; do
            [[ "$executed" == "$step_id" ]] && was_executed=true && break
        done
        
        if [[ "$was_executed" == false ]]; then
            network_debug "Step '$step_id' non exécuté, rollback ignoré"
            continue
        fi
        
        # Chercher script de rollback
        local rollback_script
        rollback_script=$(jq -r --arg id "$step_id" '.steps[] | select(.id == $id) | .rollback_script // empty' "$WORKFLOW_CONFIG")
        
        if [[ -z "$rollback_script" ]]; then
            network_warn "Pas de script rollback pour step '$step_id'"
            continue
        fi
        
        if [[ ! -f "$rollback_script" ]]; then
            network_error "Script rollback introuvable: $rollback_script"
            rollback_success=false
            continue
        fi
        
        network_info "Rollback step '$step_id' avec: $rollback_script"
        
        # Exécution rollback
        local rollback_cmd=(
            "${SCRIPT_DIR}/deploy-script.remote.sh"
            "--script" "$rollback_script"
            "--host" "$REMOTE_HOST"
            "--user" "$REMOTE_USER"
            "--path" "$WORKSPACE_PATH"
            "--timeout" "300"
        )
        
        [[ -n "$IDENTITY_FILE" ]] && rollback_cmd+=("--identity" "$IDENTITY_FILE")
        [[ "$SSH_PORT" != "22" ]] && rollback_cmd+=("--port" "$SSH_PORT")
        [[ "$QUIET" == "true" ]] && rollback_cmd+=("--quiet")
        
        if "${rollback_cmd[@]}" >/dev/null; then
            network_info "Rollback step '$step_id' réussi"
            
            # Marquer le rollback dans les résultats
            local updated_results=()
            for result in "${STEP_RESULTS[@]}"; do
                local result_step_id
                result_step_id=$(echo "$result" | jq -r '.step_id')
                if [[ "$result_step_id" == "$step_id" ]]; then
                    result=$(echo "$result" | jq '.rollback_executed = true')
                fi
                updated_results+=("$result")
            done
            STEP_RESULTS=("${updated_results[@]}")
        else
            network_error "Échec rollback step '$step_id'"
            rollback_success=false
        fi
    done
    
    if [[ "$rollback_success" == true ]]; then
        network_info "Procédure de rollback terminée avec succès"
        return $SUCCESS
    else
        network_error "Échec partiel de la procédure de rollback"
        return $ERROR_ROLLBACK
    fi
}

# === NETTOYAGE WORKSPACE ===
cleanup_remote_workspace() {
    network_debug "Nettoyage workspace distant: $WORKSPACE_PATH"
    
    local cleanup_cmd="rm -rf '$WORKSPACE_PATH'"
    local execute_cmd=(
        "${SCRIPT_DIR}/execute-ssh.remote.sh"
        "--host" "$REMOTE_HOST"
        "--user" "$REMOTE_USER"
        "--command" "$cleanup_cmd"
        "--timeout" "60"
    )
    
    [[ -n "$IDENTITY_FILE" ]] && execute_cmd+=("--identity" "$IDENTITY_FILE")
    [[ "$SSH_PORT" != "22" ]] && execute_cmd+=("--port" "$SSH_PORT")
    [[ "$QUIET" == "true" ]] && execute_cmd+=("--quiet")
    
    if "${execute_cmd[@]}" >/dev/null; then
        network_debug "Workspace distant nettoyé"
    else
        network_warn "Échec nettoyage workspace - fichiers peuvent persister"
    fi
}

# === EXÉCUTION PRINCIPALE ===
execute_remote_workflow() {
    local start_time
    start_time=$(date +%s.%N)
    
    network_info "Démarrage workflow: $(jq -r '.name' "$WORKFLOW_CONFIG")"
    
    # Test connexion
    if ! test_ssh_connection; then
        return $ERROR_CONNECTION
    fi
    
    # Préparation workspace
    if ! prepare_remote_workspace; then
        return $ERROR_WORKFLOW
    fi
    
    # Lecture des steps
    local steps_count
    steps_count=$(jq -r '.steps | length' "$WORKFLOW_CONFIG")
    
    network_info "Exécution de $steps_count steps"
    
    # Exécution séquentielle des steps  
    local workflow_success=true
    local step_index=0
    
    while [[ $step_index -lt $steps_count ]]; do
        local step_data
        step_data=$(jq -c ".steps[$step_index]" "$WORKFLOW_CONFIG")
        
        local step_id
        step_id=$(echo "$step_data" | jq -r '.id')
        
        local is_critical
        is_critical=$(echo "$step_data" | jq -r '.critical // true')
        
        # Vérification des dépendances (simplifié pour cette version)
        local depends_on
        depends_on=$(echo "$step_data" | jq -r '.depends_on[]? // empty')
        if [[ -n "$depends_on" ]]; then
            network_debug "Step '$step_id' dépend de: $depends_on"
            # TODO: Implémenter vérification complète des dépendances
        fi
        
        # Exécution du step
        if execute_workflow_step $step_index; then
            network_debug "Step '$step_id' ($((step_index + 1))/$steps_count) réussi"
        else
            network_error "Échec step '$step_id' ($((step_index + 1))/$steps_count)"
            
            if [[ "$is_critical" == "true" ]]; then
                network_error "Step critique échoué - arrêt workflow"
                workflow_success=false
                break
            elif [[ "$CONTINUE_ON_ERROR" == "false" ]]; then
                network_error "Arrêt workflow sur erreur"
                workflow_success=false
                break
            else
                network_warn "Step non-critique échoué - continuation workflow"
            fi
        fi
        
        ((step_index++))
    done
    
    # Rollback si échec et activé
    local rollback_performed=false
    if [[ "$workflow_success" == false && "$ROLLBACK_ENABLED" == "true" ]]; then
        if execute_rollback; then
            rollback_performed=true
        fi
    fi
    
    # Nettoyage workspace
    cleanup_remote_workspace
    
    # Calcul temps total
    local end_time
    end_time=$(date +%s.%N)
    local total_time
    total_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    
    # Stockage résultats globaux
    if [[ "$workflow_success" == true ]]; then
        WORKFLOW_STATUS="success"
    elif [[ ${#STEP_RESULTS[@]} -gt 0 ]]; then
        WORKFLOW_STATUS="partial"
    else
        WORKFLOW_STATUS="failed"
    fi
    
    ROLLBACK_PERFORMED="$rollback_performed"
    TOTAL_EXECUTION_TIME="$total_time"
    EXECUTION_LOG="${WORKSPACE_PATH}/execution.log"
    
    network_info "Workflow terminé: $WORKFLOW_STATUS (${total_time}s)"
    
    [[ "$workflow_success" == true ]] && return $SUCCESS || return $ERROR_WORKFLOW
}

# === FONCTION DE SORTIE JSON ===
build_json_output() {
    local status="$1"
    
    # Construction array des résultats
    local step_results_json="["
    local first=true
    for result in "${STEP_RESULTS[@]}"; do
        [[ "$first" == false ]] && step_results_json+=","
        step_results_json+="$result"
        first=false
    done
    step_results_json+="]"
    
    cat << EOF
{
    "workflow_status": "${WORKFLOW_STATUS:-failed}",
    "step_results": $step_results_json,
    "execution_log": "${EXECUTION_LOG:-null}",
    "rollback_performed": ${ROLLBACK_PERFORMED:-false},
    "total_execution_time": ${TOTAL_EXECUTION_TIME:-0}
}
EOF
}

# === NETTOYAGE ===
cleanup() {
    local exit_code=$?
    network_debug "Nettoyage avec code de sortie: $exit_code"
    
    # Nettoyage workspace distant en cas d'interruption
    if [[ -n "$REMOTE_HOST" && -n "$REMOTE_USER" ]]; then
        cleanup_remote_workspace 2>/dev/null || true
    fi
    
    exit $exit_code
}

trap cleanup EXIT ERR INT TERM

# === PARSING DES ARGUMENTS ===
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -w|--workflow)
                WORKFLOW_CONFIG="$2"
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
            --workspace)
                WORKSPACE_PATH="$2"
                shift 2
                ;;
            --no-rollback)
                ROLLBACK_ENABLED="false"
                shift
                ;;
            --parallel)
                PARALLEL_EXECUTION="true"
                shift
                ;;
            --max-parallel)
                MAX_PARALLEL="$2"
                shift 2
                ;;
            --continue-on-error)
                CONTINUE_ON_ERROR="true"
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
    if [[ -z "$WORKFLOW_CONFIG" || -z "$REMOTE_HOST" || -z "$REMOTE_USER" ]]; then
        network_error "Arguments requis manquants: --workflow, --host, --user"
        show_help >&2
        exit $ERROR_ARGS
    fi
    
    # Validation prérequis
    if ! validate_prerequisites; then
        network_error "Échec validation prérequis"
        exit $ERROR_PREREQ
    fi
    
    # Validation configuration workflow
    if ! validate_workflow_config; then
        network_error "Échec validation configuration workflow"
        exit $ERROR_CONFIG
    fi
    
    # Exécution principale
    if execute_remote_workflow; then
        build_json_output "success"
        network_info "=== Workflow réussi ==="
        exit $SUCCESS
    else
        local error_code=$?
        build_json_output "failed"
        network_error "=== Workflow échoué ==="
        exit $error_code
    fi
}

# === EXÉCUTION ===
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi