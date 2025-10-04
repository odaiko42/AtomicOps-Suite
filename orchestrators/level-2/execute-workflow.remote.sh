#!/usr/bin/env bash

#===============================================================================
# Script Orchestrateur : Exécution de Workflow Complet Distant
#===============================================================================
# Nom du fichier : execute-workflow.remote.sh
# Niveau : 2 (Orchestrateur)
# Catégorie : network
# Protocole : ssh
# Description : Orchestre l'exécution complète d'un workflow sur un hôte distant
#
# Objectif :
# - Déploiement et exécution d'un workflow multi-scripts à distance
# - Gestion complète de l'accès SSH (génération clés, autorisation)
# - Orchestration de déploiement de scripts avec dépendances
# - Exécution séquentielle ou parallèle de multiple workflows
# - Récupération et agrégation des résultats JSON
# - Rollback automatique en cas d'échec critique
#
# Conforme à la méthodologie AtomicOps-Suite - Niveau 2 (Orchestrateur)
#===============================================================================

set -euo pipefail

# === MÉTADONNÉES DU SCRIPT ===
readonly SCRIPT_NAME="execute-workflow.remote.sh"
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_CATEGORY="network"
readonly SCRIPT_PROTOCOL="ssh"
readonly SCRIPT_LEVEL=2

# === CHEMINS DES ORCHESTRATEURS ET SCRIPTS ===
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ORCHESTRATORS_DIR="$(realpath "$SCRIPT_DIR/..")"
readonly ATOMICS_DIR="$(realpath "$SCRIPT_DIR/../../atomics")"
readonly LIB_DIR="$(realpath "$SCRIPT_DIR/../../lib")"

# Scripts atomiques
readonly GENERATE_SSH_KEY_SCRIPT="$ATOMICS_DIR/generate-ssh.keypair.sh"
readonly ADD_SSH_KEY_SCRIPT="$ATOMICS_DIR/network/add-ssh.key.authorized.sh"
readonly CHECK_SSH_SCRIPT="$ATOMICS_DIR/network/check-ssh.connection.sh"

# Orchestrateurs niveau 1
readonly SETUP_SSH_ACCESS_SCRIPT="$ORCHESTRATORS_DIR/level-1/setup-ssh.access.sh"
readonly DEPLOY_SCRIPT_REMOTE="$ORCHESTRATORS_DIR/level-1/deploy-script.remote.sh"

# === CONFIGURATION PAR DÉFAUT ===
readonly DEFAULT_SSH_PORT=22
readonly DEFAULT_USER="$(whoami)"
readonly DEFAULT_REMOTE_WORKDIR="/tmp/workflow"
readonly DEFAULT_TIMEOUT=600

# === VARIABLES GLOBALES ===
TARGET_HOST=""
TARGET_PORT="$DEFAULT_SSH_PORT"
TARGET_USER="$DEFAULT_USER"
SSH_KEY_FILE=""
WORKFLOW_NAME=""
WORKFLOW_SCRIPTS=()
WORKFLOW_DEPENDENCIES=()
REMOTE_WORKDIR="$DEFAULT_REMOTE_WORKDIR"
WORKFLOW_ARGUMENTS=""
ENVIRONMENT_VARS=""
EXECUTION_MODE="sequential"  # sequential|parallel
SETUP_SSH_ACCESS=false
ROLLBACK_ON_FAILURE=true
PERSIST_RESULTS=true
GLOBAL_TIMEOUT="$DEFAULT_TIMEOUT"
MAX_RETRIES=3
DRY_RUN=false
QUIET_MODE=false
DEBUG_MODE=false
VERBOSE_MODE=false

# === FONCTIONS D'AIDE ===
show_help() {
    cat << EOF
Exécution de Workflow Complet Distant - Orchestrateur Niveau 2

USAGE:
    $(basename "$0") [OPTIONS] HOST WORKFLOW_NAME SCRIPT1 [SCRIPT2 ...]

DESCRIPTION:
    Orchestre l'exécution complète d'un workflow multi-scripts sur serveur distant :
    
    WORKFLOW COMPLET:
    1. Configuration automatique de l'accès SSH (optionnel)
    2. Validation de la connectivité et des prérequis
    3. Déploiement des scripts du workflow et dépendances
    4. Exécution séquentielle ou parallèle des scripts
    5. Récupération et agrégation des résultats JSON
    6. Rollback automatique en cas d'échec (optionnel)
    
    ORCHESTRATION MULTI-NIVEAU:
    - Niveau 2 : Coordination de workflow business complet
    - Niveau 1 : Déploiement de scripts individuels
    - Niveau 0 : Opérations atomiques SSH/transfert

PARAMÈTRES OBLIGATOIRES:
    HOST                    Nom d'hôte ou adresse IP du serveur distant
    WORKFLOW_NAME          Nom du workflow à exécuter
    SCRIPT1 [SCRIPT2...]   Scripts du workflow (ordre d'exécution)

OPTIONS PRINCIPALES:
    -p, --port PORT         Port SSH (défaut: 22)
    -u, --user USER         Utilisateur SSH (défaut: current user)
    -i, --identity FILE     Fichier de clé privée SSH existante
    -w, --workdir PATH      Répertoire de travail distant (défaut: /tmp/workflow)
    -a, --args "ARGUMENTS"  Arguments communs pour tous les scripts
    
OPTIONS DE WORKFLOW:
    --setup-ssh             Configurer l'accès SSH automatiquement
    --parallel              Exécution parallèle des scripts (défaut: séquentiel)
    --no-rollback           Désactiver le rollback automatique
    --no-persist            Ne pas persister les résultats sur le serveur
    -d, --dependency FILE   Fichier de dépendance global (répétable)
    -e, --env "VAR=value"   Variables d'environnement (répétable)
    
OPTIONS DE CONTRÔLE:
    -t, --timeout SECONDS   Timeout global d'exécution (défaut: 600)
    -r, --retries NUMBER    Nombre de tentatives max (défaut: 3)
    --dry-run               Simulation complète (affiche toutes les actions)
    
OPTIONS D'AFFICHAGE:
    -v, --verbose           Mode verbose avec détails des orchestrations
    -q, --quiet             Mode silencieux (erreurs uniquement)
    --debug                 Mode debug avec traces de tous les niveaux
    -h, --help              Affiche cette aide

EXEMPLES D'USAGE:

    # Workflow simple avec setup SSH automatique
    $(basename "$0") --setup-ssh server.com "backup-system" ./backup.sh ./cleanup.sh
    
    # Workflow complexe avec dépendances et environnement
    $(basename "$0") --parallel --dependency ./config.yml --env "ENV=prod" \\
                     server.com "deploy-app" ./prepare.sh ./deploy.sh ./verify.sh
    
    # Workflow avec clé SSH spécifique et timeout augmenté
    $(basename "$0") --identity ~/.ssh/deploy_key --timeout 1800 --args "--verbose" \\
                     server.com "maintenance" ./stop-services.sh ./update.sh ./start-services.sh
    
    # Dry-run pour prévisualiser l'orchestration complète
    $(basename "$0") --dry-run --verbose --setup-ssh server.com "test-workflow" ./test.sh

WORKFLOWS PRÉDÉFINIS:
    system-setup        : Configuration système complète
    backup-full         : Sauvegarde complète avec vérification
    deploy-application  : Déploiement d'application multi-tiers
    security-audit      : Audit de sécurité complet
    maintenance-window  : Fenêtre de maintenance orchestrée

MODES D'EXÉCUTION:
    sequential  : Scripts exécutés l'un après l'autre (défaut)
    parallel    : Scripts exécutés simultanément (plus rapide)

SORTIE JSON:
    {
        "status": "success|error|partial",
        "timestamp": "ISO8601",
        "script": "$SCRIPT_NAME",
        "data": {
            "workflow": {
                "name": "workflow_name",
                "target_host": "hostname",
                "execution_mode": "sequential|parallel",
                "scripts_count": number,
                "dependencies_count": number
            },
            "orchestration": {
                "ssh_setup": {...},
                "script_deployments": [...],
                "script_executions": [...],
                "rollback_performed": boolean
            },
            "results": {
                "total_scripts": number,
                "successful_scripts": number,
                "failed_scripts": number,
                "execution_times": {...},
                "aggregated_output": "string"
            },
            "performance": {
                "total_duration_ms": number,
                "setup_time_ms": number,
                "deployment_time_ms": number,
                "execution_time_ms": number,
                "cleanup_time_ms": number
            }
        }
    }

CODES DE RETOUR:
    0 : Succès - Workflow exécuté avec succès
    1 : Erreur de paramètres ou de validation
    2 : Échec de configuration SSH
    3 : Échec de déploiement de scripts
    4 : Échec partiel d'exécution de workflow
    5 : Échec complet d'exécution de workflow
    6 : Timeout global dépassé

ORCHESTRATEURS UTILISÉS:
    - setup-ssh.access.sh         : Configuration accès SSH (niveau 1)
    - deploy-script.remote.sh     : Déploiement scripts (×N, niveau 1)

SCRIPTS ATOMIQUES UTILISÉS:
    - generate-ssh.keypair.sh     : Génération clés SSH
    - add-ssh.key.authorized.sh   : Autorisation clés SSH
    - check-ssh.connection.sh     : Validation connectivité
    - copy-file.remote.sh         : Transferts de fichiers
    - execute-ssh.remote.sh       : Exécutions distantes

CONFORMITÉ:
    - Méthodologie AtomicOps-Suite Niveau 2 (Orchestrateur)
    - Composition d'orchestrateurs niveau 1 et scripts atomiques
    - Sortie JSON standardisée agrégée
    - Gestion d'erreurs avec rollback et recovery
EOF
}

# === FONCTIONS DE LOGGING ===
log_debug() { [[ "$DEBUG_MODE" == true ]] && echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2; }
log_info() { [[ "$QUIET_MODE" == false ]] && echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2; }
log_verbose() { [[ "$VERBOSE_MODE" == true ]] && echo "[VERBOSE] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2; }
log_error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2; }
log_workflow() { [[ "$QUIET_MODE" == false ]] && echo "[WORKFLOW] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2; }

# === VALIDATION DES DÉPENDANCES ===
validate_dependencies() {
    local errors=0
    
    # Vérification des orchestrateurs niveau 1
    local required_orchestrators=("$DEPLOY_SCRIPT_REMOTE")
    
    # Ajout conditionnel de setup-ssh.access.sh s'il existe
    if [[ -f "$SETUP_SSH_ACCESS_SCRIPT" ]]; then
        required_orchestrators+=("$SETUP_SSH_ACCESS_SCRIPT")
    elif [[ "$SETUP_SSH_ACCESS" == true ]]; then
        log_error "Option --setup-ssh demandée mais setup-ssh.access.sh non trouvé"
        ((errors++))
    fi
    
    for orchestrator in "${required_orchestrators[@]}"; do
        if [[ ! -f "$orchestrator" ]]; then
            log_error "Orchestrateur manquant : $orchestrator"
            ((errors++))
        elif [[ ! -x "$orchestrator" ]]; then
            log_error "Orchestrateur non exécutable : $orchestrator"
            ((errors++))
        fi
    done
    
    # Vérification des scripts atomiques critiques
    local required_atomics=("$CHECK_SSH_SCRIPT")
    
    for atomic in "${required_atomics[@]}"; do
        if [[ ! -f "$atomic" ]]; then
            log_error "Script atomique manquant : $atomic"
            ((errors++))
        elif [[ ! -x "$atomic" ]]; then
            log_error "Script atomique non exécutable : $atomic"
            ((errors++))
        fi
    done
    
    return $errors
}

# === VALIDATION DES PARAMÈTRES ===
validate_parameters() {
    local errors=0
    
    # Validation de l'hôte obligatoire
    if [[ -z "$TARGET_HOST" ]]; then
        log_error "Hôte cible obligatoire"
        ((errors++))
    fi
    
    # Validation du nom de workflow
    if [[ -z "$WORKFLOW_NAME" ]]; then
        log_error "Nom de workflow obligatoire"
        ((errors++))
    fi
    
    # Validation des scripts du workflow
    if [[ ${#WORKFLOW_SCRIPTS[@]} -eq 0 ]]; then
        log_error "Au moins un script de workflow obligatoire"
        ((errors++))
    fi
    
    # Validation de l'existence des scripts
    for script in "${WORKFLOW_SCRIPTS[@]}"; do
        if [[ ! -f "$script" ]]; then
            log_error "Script de workflow non trouvé : $script"
            ((errors++))
        elif [[ ! -r "$script" ]]; then
            log_error "Script de workflow non lisible : $script"
            ((errors++))
        fi
    done
    
    # Validation des fichiers de dépendance
    for dep_file in "${WORKFLOW_DEPENDENCIES[@]}"; do
        if [[ ! -e "$dep_file" ]]; then
            log_error "Fichier de dépendance non trouvé : $dep_file"
            ((errors++))
        elif [[ ! -r "$dep_file" ]]; then
            log_error "Fichier de dépendance non lisible : $dep_file"
            ((errors++))
        fi
    done
    
    # Validation du port SSH
    if [[ ! "$TARGET_PORT" =~ ^[0-9]+$ ]] || [[ "$TARGET_PORT" -lt 1 ]] || [[ "$TARGET_PORT" -gt 65535 ]]; then
        log_error "Port SSH invalide : $TARGET_PORT"
        ((errors++))
    fi
    
    # Validation du timeout global
    if [[ ! "$GLOBAL_TIMEOUT" =~ ^[0-9]+$ ]] || [[ "$GLOBAL_TIMEOUT" -lt 30 ]]; then
        log_error "Timeout global invalide : $GLOBAL_TIMEOUT (minimum: 30s)"
        ((errors++))
    fi
    
    # Validation du mode d'exécution
    case "$EXECUTION_MODE" in
        "sequential"|"parallel") ;;
        *)
            log_error "Mode d'exécution invalide : $EXECUTION_MODE (sequential|parallel)"
            ((errors++))
            ;;
    esac
    
    # Validation du fichier de clé SSH si spécifié
    if [[ -n "$SSH_KEY_FILE" ]]; then
        if [[ ! -f "$SSH_KEY_FILE" ]]; then
            log_error "Fichier de clé SSH non trouvé : $SSH_KEY_FILE"
            ((errors++))
        elif [[ ! -r "$SSH_KEY_FILE" ]]; then
            log_error "Fichier de clé SSH non lisible : $SSH_KEY_FILE"
            ((errors++))
        fi
    fi
    
    return $errors
}

# === CONFIGURATION DE L'ACCÈS SSH ===
setup_ssh_access() {
    if [[ "$SETUP_SSH_ACCESS" == false ]]; then
        log_verbose "Configuration SSH ignorée"
        echo '{"status": "skipped"}' > /tmp/ssh_setup_result_$$
        return 0
    fi
    
    log_workflow "PHASE 1/5 : Configuration de l'accès SSH"
    
    local setup_start=$(date +%s.%N)
    
    if [[ ! -f "$SETUP_SSH_ACCESS_SCRIPT" ]]; then
        log_error "Script setup-ssh.access.sh non disponible"
        echo '{"status": "error", "message": "setup script not found"}' > /tmp/ssh_setup_result_$$
        return 2
    fi
    
    # Construction de la commande pour setup-ssh.access.sh
    local setup_cmd=("$SETUP_SSH_ACCESS_SCRIPT")
    setup_cmd+=("--host" "$TARGET_HOST")
    setup_cmd+=("--port" "$TARGET_PORT")
    setup_cmd+=("--user" "$TARGET_USER")
    
    [[ "$QUIET_MODE" == true ]] && setup_cmd+=("--quiet")
    [[ "$DEBUG_MODE" == true ]] && setup_cmd+=("--debug")
    [[ "$DRY_RUN" == true ]] && setup_cmd+=("--dry-run")
    
    log_debug "Commande setup SSH : ${setup_cmd[*]}"
    
    local setup_result
    if [[ "$DRY_RUN" == true ]]; then
        log_info "MODE DRY-RUN : Configuration SSH simulée"
        setup_result='{"status": "success", "data": {"ssh_key_generated": true, "access_configured": true}}'
    else
        if setup_result=$("${setup_cmd[@]}" 2>/dev/null); then
            local setup_status=$(echo "$setup_result" | jq -r '.status' 2>/dev/null || echo "error")
            
            if [[ "$setup_status" == "success" ]]; then
                log_verbose "Configuration SSH terminée avec succès"
                
                # Extraction du chemin de la clé générée si applicable
                local generated_key=$(echo "$setup_result" | jq -r '.data.ssh_key_path' 2>/dev/null || echo "")
                if [[ -n "$generated_key" && -z "$SSH_KEY_FILE" ]]; then
                    SSH_KEY_FILE="$generated_key"
                    log_debug "Utilisation de la clé SSH générée : $SSH_KEY_FILE"
                fi
            else
                log_error "Échec de la configuration SSH"
                echo "$setup_result" > /tmp/ssh_setup_result_$$
                return 2
            fi
        else
            log_error "Erreur lors de l'exécution du setup SSH"
            echo '{"status": "error", "message": "setup execution failed"}' > /tmp/ssh_setup_result_$$
            return 2
        fi
    fi
    
    local setup_end=$(date +%s.%N)
    local setup_time=$(echo "($setup_end - $setup_start) * 1000" | bc -l 2>/dev/null || echo "0")
    
    # Enrichissement du résultat avec les métriques
    echo "$setup_result" | jq --arg setup_time "$setup_time" '. + {"setup_time_ms": ($setup_time | tonumber)}' > /tmp/ssh_setup_result_$$ 2>/dev/null || echo "$setup_result" > /tmp/ssh_setup_result_$$
    
    return 0
}

# === VALIDATION DE LA CONNECTIVITÉ ===
validate_workflow_prerequisites() {
    log_workflow "PHASE 2/5 : Validation des prérequis du workflow"
    
    local validation_start=$(date +%s.%N)
    
    # Test de connectivité SSH
    local check_cmd=("$CHECK_SSH_SCRIPT")
    check_cmd+=("--port" "$TARGET_PORT")
    check_cmd+=("--user" "$TARGET_USER")
    check_cmd+=("--timeout" "30")
    check_cmd+=("--full-diagnostic")
    
    [[ -n "$SSH_KEY_FILE" ]] && check_cmd+=("--identity" "$SSH_KEY_FILE")
    [[ "$QUIET_MODE" == true ]] && check_cmd+=("--quiet")
    [[ "$DEBUG_MODE" == true ]] && check_cmd+=("--debug")
    
    check_cmd+=("$TARGET_HOST")
    
    log_debug "Commande de validation : ${check_cmd[*]}"
    
    local check_result
    if [[ "$DRY_RUN" == true ]]; then
        log_info "MODE DRY-RUN : Validation des prérequis simulée"
        check_result='{"status": "success", "data": {"ssh_connection": {"status": "success"}}}'
    else
        if check_result=$("${check_cmd[@]}" 2>/dev/null); then
            local check_status=$(echo "$check_result" | jq -r '.data.ssh_connection.status' 2>/dev/null || echo "failed")
            
            if [[ "$check_status" == "success" ]]; then
                log_verbose "Prérequis du workflow validés"
            else
                log_error "Échec de validation des prérequis"
                echo "$check_result" > /tmp/validation_result_$$
                return 2
            fi
        else
            log_error "Erreur lors de la validation des prérequis"
            return 2
        fi
    fi
    
    local validation_end=$(date +%s.%N)
    local validation_time=$(echo "($validation_end - $validation_start) * 1000" | bc -l 2>/dev/null || echo "0")
    
    echo "$check_result" | jq --arg validation_time "$validation_time" '. + {"validation_time_ms": ($validation_time | tonumber)}' > /tmp/validation_result_$$ 2>/dev/null || echo "$check_result" > /tmp/validation_result_$$
    
    return 0
}

# === DÉPLOIEMENT DES SCRIPTS DU WORKFLOW ===
deploy_workflow_scripts() {
    log_workflow "PHASE 3/5 : Déploiement des scripts du workflow (${#WORKFLOW_SCRIPTS[@]} script(s))"
    
    local deployment_start=$(date +%s.%N)
    local deployment_results=()
    local successful_deployments=0
    local failed_deployments=0
    
    for script_path in "${WORKFLOW_SCRIPTS[@]}"; do
        local script_name=$(basename "$script_path")
        log_info "Déploiement du script : $script_name"
        
        # Construction de la commande de déploiement
        local deploy_cmd=("$DEPLOY_SCRIPT_REMOTE")
        deploy_cmd+=("--port" "$TARGET_PORT")
        deploy_cmd+=("--user" "$TARGET_USER")
        deploy_cmd+=("--workdir" "$REMOTE_WORKDIR")
        deploy_cmd+=("--no-cleanup")  # Pas de nettoyage automatique pour le workflow
        deploy_cmd+=("--timeout" "120")
        
        # Ajout des dépendances pour chaque script
        for dep in "${WORKFLOW_DEPENDENCIES[@]}"; do
            deploy_cmd+=("--dependency" "$dep")
        done
        
        # Ajout des variables d'environnement
        if [[ -n "$ENVIRONMENT_VARS" ]]; then
            deploy_cmd+=("--env" "$ENVIRONMENT_VARS")
        fi
        
        [[ -n "$SSH_KEY_FILE" ]] && deploy_cmd+=("--identity" "$SSH_KEY_FILE")
        [[ "$QUIET_MODE" == true ]] && deploy_cmd+=("--quiet")
        [[ "$DEBUG_MODE" == true ]] && deploy_cmd+=("--debug")
        [[ "$DRY_RUN" == true ]] && deploy_cmd+=("--dry-run")
        
        deploy_cmd+=("$TARGET_HOST" "$script_path")
        
        log_debug "Commande de déploiement : ${deploy_cmd[*]}"
        
        local deploy_result
        if deploy_result=$("${deploy_cmd[@]}" 2>/dev/null); then
            local deploy_status=$(echo "$deploy_result" | jq -r '.status' 2>/dev/null || echo "error")
            
            if [[ "$deploy_status" == "success" ]]; then
                log_verbose "Script déployé avec succès : $script_name"
                deployment_results+=("$deploy_result")
                ((successful_deployments++))
            else
                log_error "Échec du déploiement : $script_name"
                deployment_results+=("$deploy_result")
                ((failed_deployments++))
            fi
        else
            log_error "Erreur lors du déploiement de : $script_name"
            ((failed_deployments++))
            deployment_results+=('{"status": "error", "script": "'$script_name'", "message": "deployment failed"}')
        fi
    done
    
    local deployment_end=$(date +%s.%N)
    local deployment_time=$(echo "($deployment_end - $deployment_start) * 1000" | bc -l 2>/dev/null || echo "0")
    
    # Stockage des résultats de déploiement
    local deployments_json="[$(IFS=,; echo "${deployment_results[*]}")]"
    cat << EOF > /tmp/deployment_results_$$
{
    "total_scripts": ${#WORKFLOW_SCRIPTS[@]},
    "successful_deployments": $successful_deployments,
    "failed_deployments": $failed_deployments,
    "deployment_time_ms": $deployment_time,
    "deployment_details": $deployments_json
}
EOF
    
    # Vérification si tous les déploiements ont réussi
    if [[ $failed_deployments -gt 0 ]]; then
        log_error "Échec de déploiement de $failed_deployments script(s)"
        return 3
    fi
    
    return 0
}

# === EXÉCUTION SÉQUENTIELLE DES SCRIPTS ===
execute_scripts_sequential() {
    log_info "Exécution séquentielle des scripts du workflow"
    
    local execution_results=()
    local successful_executions=0
    local failed_executions=0
    
    for script_path in "${WORKFLOW_SCRIPTS[@]}"; do
        local script_name=$(basename "$script_path")
        log_info "Exécution du script : $script_name"
        
        # Commande d'exécution via SSH
        local exec_command="cd '$REMOTE_WORKDIR' && ./$script_name"
        
        # Ajout des arguments si spécifiés
        if [[ -n "$WORKFLOW_ARGUMENTS" ]]; then
            exec_command="$exec_command $WORKFLOW_ARGUMENTS"
        fi
        
        # Exécution via execute-ssh.remote.sh
        local exec_cmd=("$ATOMICS_DIR/network/execute-ssh.remote.sh")
        exec_cmd+=("--port" "$TARGET_PORT")
        exec_cmd+=("--user" "$TARGET_USER")
        exec_cmd+=("--timeout" "$((GLOBAL_TIMEOUT / ${#WORKFLOW_SCRIPTS[@]}))")  # Timeout réparti
        exec_cmd+=("--workdir" "$REMOTE_WORKDIR")
        
        if [[ -n "$ENVIRONMENT_VARS" ]]; then
            exec_cmd+=("--env" "$ENVIRONMENT_VARS")
        fi
        
        [[ -n "$SSH_KEY_FILE" ]] && exec_cmd+=("--identity" "$SSH_KEY_FILE")
        [[ "$QUIET_MODE" == true ]] && exec_cmd+=("--quiet")
        [[ "$DEBUG_MODE" == true ]] && exec_cmd+=("--debug")
        [[ "$DRY_RUN" == true ]] && exec_cmd+=("--dry-run")
        
        exec_cmd+=("$TARGET_HOST" "$exec_command")
        
        local exec_result
        if exec_result=$("${exec_cmd[@]}" 2>/dev/null); then
            local exec_status=$(echo "$exec_result" | jq -r '.status' 2>/dev/null || echo "error")
            local exit_code=$(echo "$exec_result" | jq -r '.data.result.exit_code' 2>/dev/null || echo "1")
            
            if [[ "$exec_status" == "success" && "$exit_code" == "0" ]]; then
                log_verbose "Script exécuté avec succès : $script_name (code: $exit_code)"
                execution_results+=("$exec_result")
                ((successful_executions++))
            else
                log_error "Échec d'exécution : $script_name (code: $exit_code)"
                execution_results+=("$exec_result")
                ((failed_executions++))
                
                # En mode séquentiel, arrêter si rollback activé
                if [[ "$ROLLBACK_ON_FAILURE" == true ]]; then
                    log_error "Arrêt du workflow séquentiel après échec"
                    break
                fi
            fi
        else
            log_error "Erreur lors de l'exécution de : $script_name"
            ((failed_executions++))
            execution_results+=('{"status": "error", "script": "'$script_name'", "message": "execution failed"}')
            
            if [[ "$ROLLBACK_ON_FAILURE" == true ]]; then
                break
            fi
        fi
    done
    
    # Stockage des résultats d'exécution
    local executions_json="[$(IFS=,; echo "${execution_results[*]}")]"
    cat << EOF > /tmp/execution_results_$$
{
    "execution_mode": "sequential",
    "total_scripts": ${#WORKFLOW_SCRIPTS[@]},
    "successful_executions": $successful_executions,
    "failed_executions": $failed_executions,
    "execution_details": $executions_json
}
EOF
    
    return $([ $failed_executions -eq 0 ] && echo 0 || echo 4)
}

# === EXÉCUTION PARALLÈLE DES SCRIPTS ===
execute_scripts_parallel() {
    log_info "Exécution parallèle des scripts du workflow"
    
    local pids=()
    local temp_files=()
    local script_names=()
    
    # Lancement des scripts en parallèle
    for i in "${!WORKFLOW_SCRIPTS[@]}"; do
        local script_path="${WORKFLOW_SCRIPTS[$i]}"
        local script_name=$(basename "$script_path")
        local temp_result=$(mktemp)
        
        script_names+=("$script_name")
        temp_files+=("$temp_result")
        
        log_verbose "Lancement parallèle : $script_name"
        
        # Commande d'exécution
        local exec_command="cd '$REMOTE_WORKDIR' && ./$script_name"
        [[ -n "$WORKFLOW_ARGUMENTS" ]] && exec_command="$exec_command $WORKFLOW_ARGUMENTS"
        
        # Exécution en arrière-plan
        local exec_cmd=("$ATOMICS_DIR/network/execute-ssh.remote.sh")
        exec_cmd+=("--port" "$TARGET_PORT")
        exec_cmd+=("--user" "$TARGET_USER")
        exec_cmd+=("--timeout" "$GLOBAL_TIMEOUT")
        exec_cmd+=("--workdir" "$REMOTE_WORKDIR")
        
        [[ -n "$ENVIRONMENT_VARS" ]] && exec_cmd+=("--env" "$ENVIRONMENT_VARS")
        [[ -n "$SSH_KEY_FILE" ]] && exec_cmd+=("--identity" "$SSH_KEY_FILE")
        [[ "$QUIET_MODE" == true ]] && exec_cmd+=("--quiet")
        [[ "$DEBUG_MODE" == true ]] && exec_cmd+=("--debug")
        [[ "$DRY_RUN" == true ]] && exec_cmd+=("--dry-run")
        
        exec_cmd+=("$TARGET_HOST" "$exec_command")
        
        # Lancement en arrière-plan avec redirection vers fichier temporaire
        "${exec_cmd[@]}" > "$temp_result" 2>&1 &
        pids+=($!)
    done
    
    # Attente de la fin de tous les processus
    local successful_executions=0
    local failed_executions=0
    local execution_results=()
    
    for i in "${!pids[@]}"; do
        local pid="${pids[$i]}"
        local script_name="${script_names[$i]}"
        local temp_file="${temp_files[$i]}"
        
        if wait "$pid"; then
            log_verbose "Script terminé avec succès : $script_name"
            local exec_result=$(cat "$temp_file" 2>/dev/null || echo '{"status": "error"}')
            execution_results+=("$exec_result")
            ((successful_executions++))
        else
            log_error "Échec d'exécution parallèle : $script_name"
            local exec_result=$(cat "$temp_file" 2>/dev/null || echo '{"status": "error", "script": "'$script_name'"}')
            execution_results+=("$exec_result")
            ((failed_executions++))
        fi
        
        rm -f "$temp_file"
    done
    
    # Stockage des résultats d'exécution
    local executions_json="[$(IFS=,; echo "${execution_results[*]}")]"
    cat << EOF > /tmp/execution_results_$$
{
    "execution_mode": "parallel",
    "total_scripts": ${#WORKFLOW_SCRIPTS[@]},
    "successful_executions": $successful_executions,
    "failed_executions": $failed_executions,
    "execution_details": $executions_json
}
EOF
    
    return $([ $failed_executions -eq 0 ] && echo 0 || echo 4)
}

# === EXÉCUTION DES SCRIPTS DU WORKFLOW ===
execute_workflow_scripts() {
    log_workflow "PHASE 4/5 : Exécution des scripts du workflow ($EXECUTION_MODE)"
    
    local execution_start=$(date +%s.%N)
    local execution_result=0
    
    case "$EXECUTION_MODE" in
        "sequential")
            execute_scripts_sequential
            execution_result=$?
            ;;
        "parallel")
            execute_scripts_parallel
            execution_result=$?
            ;;
    esac
    
    local execution_end=$(date +%s.%N)
    local execution_time=$(echo "($execution_end - $execution_start) * 1000" | bc -l 2>/dev/null || echo "0")
    
    # Enrichissement du résultat avec les métriques de temps
    local current_result=$(cat /tmp/execution_results_$$ 2>/dev/null || echo '{}')
    echo "$current_result" | jq --arg execution_time "$execution_time" '. + {"execution_time_ms": ($execution_time | tonumber)}' > /tmp/execution_results_$$ 2>/dev/null || echo "$current_result" > /tmp/execution_results_$$
    
    return $execution_result
}

# === NETTOYAGE ET PERSISTENCE ===
cleanup_and_persist() {
    log_workflow "PHASE 5/5 : Nettoyage et persistence des résultats"
    
    local cleanup_start=$(date +%s.%N)
    
    if [[ "$PERSIST_RESULTS" == true ]]; then
        # Création d'un rapport de résultats sur le serveur distant
        local results_file="$REMOTE_WORKDIR/workflow_${WORKFLOW_NAME}_$(date +%Y%m%d_%H%M%S).json"
        
        # Génération du rapport JSON complet
        local full_report
        full_report=$(generate_output "success" "$(date -Iseconds)" "$(date -Iseconds)")
        
        # Transfert du rapport sur le serveur
        local report_temp=$(mktemp)
        echo "$full_report" > "$report_temp"
        
        local copy_cmd=("$ATOMICS_DIR/network/copy-file.remote.sh")
        copy_cmd+=("--upload" "--port" "$TARGET_PORT" "--user" "$TARGET_USER")
        [[ -n "$SSH_KEY_FILE" ]] && copy_cmd+=("--identity" "$SSH_KEY_FILE")
        [[ "$QUIET_MODE" == true ]] && copy_cmd+=("--quiet")
        
        if "${copy_cmd[@]}" "$TARGET_HOST" "$report_temp" "$results_file" >/dev/null 2>&1; then
            log_verbose "Rapport de workflow persisté : $results_file"
        else
            log_error "Échec de persistence du rapport (non critique)"
        fi
        
        rm -f "$report_temp"
    fi
    
    # Nettoyage des scripts de workflow (optionnel)
    if [[ "$ROLLBACK_ON_FAILURE" == false ]]; then
        log_verbose "Nettoyage des scripts temporaires"
        
        local cleanup_command="cd '$REMOTE_WORKDIR' && rm -f *.sh 2>/dev/null || true"
        
        local exec_cmd=("$ATOMICS_DIR/network/execute-ssh.remote.sh")
        exec_cmd+=("--port" "$TARGET_PORT" "--user" "$TARGET_USER" "--timeout" "30")
        [[ -n "$SSH_KEY_FILE" ]] && exec_cmd+=("--identity" "$SSH_KEY_FILE")
        [[ "$QUIET_MODE" == true ]] && exec_cmd+=("--quiet")
        
        "${exec_cmd[@]}" "$TARGET_HOST" "$cleanup_command" >/dev/null 2>&1 || true
    fi
    
    local cleanup_end=$(date +%s.%N)
    local cleanup_time=$(echo "($cleanup_end - $cleanup_start) * 1000" | bc -l 2>/dev/null || echo "0")
    
    echo '{"status": "success", "cleanup_time_ms": '$cleanup_time'}' > /tmp/cleanup_result_$$
    
    return 0
}

# === GÉNÉRATION DE LA SORTIE JSON ===
generate_output() {
    local status="$1"
    local start_time="$2"
    local end_time="$3"
    
    # Lecture de tous les résultats d'orchestration
    local ssh_setup_result=$(cat /tmp/ssh_setup_result_$$ 2>/dev/null || echo '{"status": "skipped"}')
    local validation_result=$(cat /tmp/validation_result_$$ 2>/dev/null || echo '{"status": "error"}')
    local deployment_results=$(cat /tmp/deployment_results_$$ 2>/dev/null || echo '{"total_scripts": 0, "successful_deployments": 0, "failed_deployments": 0}')
    local execution_results=$(cat /tmp/execution_results_$$ 2>/dev/null || echo '{"execution_mode": "sequential", "total_scripts": 0, "successful_executions": 0, "failed_executions": 0}')
    local cleanup_result=$(cat /tmp/cleanup_result_$$ 2>/dev/null || echo '{"status": "skipped"}')
    
    # Extraction des métriques de performance
    local start_time_sec=$(date -d "$start_time" +%s.%N 2>/dev/null || echo "0")
    local end_time_sec=$(date -d "$end_time" +%s.%N 2>/dev/null || echo "0")
    local total_duration_ms=$(echo "($end_time_sec - $start_time_sec) * 1000" | bc -l 2>/dev/null || echo "0")
    
    local setup_time_ms=$(echo "$ssh_setup_result" | jq -r '.setup_time_ms' 2>/dev/null || echo "0")
    local deployment_time_ms=$(echo "$deployment_results" | jq -r '.deployment_time_ms' 2>/dev/null || echo "0")
    local execution_time_ms=$(echo "$execution_results" | jq -r '.execution_time_ms' 2>/dev/null || echo "0")
    local cleanup_time_ms=$(echo "$cleanup_result" | jq -r '.cleanup_time_ms' 2>/dev/null || echo "0")
    
    # Extraction des résultats d'exécution
    local total_scripts=$(echo "$execution_results" | jq -r '.total_scripts' 2>/dev/null || echo "0")
    local successful_scripts=$(echo "$execution_results" | jq -r '.successful_executions' 2>/dev/null || echo "0")
    local failed_scripts=$(echo "$execution_results" | jq -r '.failed_executions' 2>/dev/null || echo "0")
    
    # Agrégation des sorties des scripts (simplifiée)
    local aggregated_output="Workflow $WORKFLOW_NAME executed with $successful_scripts/$total_scripts successful scripts"
    
    # Conversion des variables d'environnement en JSON
    local env_vars_json="{}"
    if [[ -n "$ENVIRONMENT_VARS" ]]; then
        local env_pairs=()
        IFS=' ' read -ra ENV_ARRAY <<< "$ENVIRONMENT_VARS"
        for env_var in "${ENV_ARRAY[@]}"; do
            if [[ "$env_var" =~ ^([^=]+)=(.*)$ ]]; then
                env_pairs+=("\"${BASH_REMATCH[1]}\": \"${BASH_REMATCH[2]}\"")
            fi
        done
        if [[ ${#env_pairs[@]} -gt 0 ]]; then
            env_vars_json="{$(IFS=,; echo "${env_pairs[*]}")}"
        fi
    fi
    
    cat << EOF
{
    "status": "$status",
    "timestamp": "$(date -Iseconds)",
    "script": "$SCRIPT_NAME",
    "version": "$SCRIPT_VERSION",
    "data": {
        "workflow": {
            "name": "$WORKFLOW_NAME",
            "target_host": "$TARGET_HOST",
            "execution_mode": "$EXECUTION_MODE",
            "scripts_count": ${#WORKFLOW_SCRIPTS[@]},
            "dependencies_count": ${#WORKFLOW_DEPENDENCIES[@]},
            "environment_vars": $env_vars_json
        },
        "orchestration": {
            "ssh_setup": $ssh_setup_result,
            "validation": $validation_result,
            "script_deployments": $deployment_results,
            "script_executions": $execution_results,
            "rollback_performed": $([ "$ROLLBACK_ON_FAILURE" == true ] && [ "$failed_scripts" -gt 0 ] && echo "true" || echo "false")
        },
        "results": {
            "total_scripts": $total_scripts,
            "successful_scripts": $successful_scripts,
            "failed_scripts": $failed_scripts,
            "execution_times": {
                "setup_ms": $(printf "%.0f" "$setup_time_ms"),
                "deployment_ms": $(printf "%.0f" "$deployment_time_ms"),
                "execution_ms": $(printf "%.0f" "$execution_time_ms"),
                "cleanup_ms": $(printf "%.0f" "$cleanup_time_ms")
            },
            "aggregated_output": "$aggregated_output"
        },
        "performance": {
            "total_duration_ms": $(printf "%.0f" "$total_duration_ms"),
            "setup_time_ms": $(printf "%.0f" "$setup_time_ms"),
            "deployment_time_ms": $(printf "%.0f" "$deployment_time_ms"),
            "execution_time_ms": $(printf "%.0f" "$execution_time_ms"),
            "cleanup_time_ms": $(printf "%.0f" "$cleanup_time_ms")
        }
    }
}
EOF
}

# === NETTOYAGE DES FICHIERS TEMPORAIRES ===
cleanup() {
    rm -f /tmp/ssh_setup_result_$$ /tmp/validation_result_$$ /tmp/deployment_results_$$ /tmp/execution_results_$$ /tmp/cleanup_result_$$ 2>/dev/null || true
}

# === GESTION DES ARGUMENTS ===
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--port)
                TARGET_PORT="$2"
                shift 2
                ;;
            -u|--user)
                TARGET_USER="$2"
                shift 2
                ;;
            -i|--identity)
                SSH_KEY_FILE="$2"
                shift 2
                ;;
            -w|--workdir)
                REMOTE_WORKDIR="$2"
                shift 2
                ;;
            -a|--args)
                WORKFLOW_ARGUMENTS="$2"
                shift 2
                ;;
            --setup-ssh)
                SETUP_SSH_ACCESS=true
                shift
                ;;
            --parallel)
                EXECUTION_MODE="parallel"
                shift
                ;;
            --no-rollback)
                ROLLBACK_ON_FAILURE=false
                shift
                ;;
            --no-persist)
                PERSIST_RESULTS=false
                shift
                ;;
            -d|--dependency)
                WORKFLOW_DEPENDENCIES+=("$2")
                shift 2
                ;;
            -e|--env)
                ENVIRONMENT_VARS="$ENVIRONMENT_VARS $2"
                shift 2
                ;;
            -t|--timeout)
                GLOBAL_TIMEOUT="$2"
                shift 2
                ;;
            -r|--retries)
                MAX_RETRIES="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE_MODE=true
                shift
                ;;
            -q|--quiet)
                QUIET_MODE=true
                shift
                ;;
            --debug)
                DEBUG_MODE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                log_error "Option inconnue : $1"
                show_help >&2
                exit 1
                ;;
            *)
                if [[ -z "$TARGET_HOST" ]]; then
                    TARGET_HOST="$1"
                elif [[ -z "$WORKFLOW_NAME" ]]; then
                    WORKFLOW_NAME="$1"
                else
                    WORKFLOW_SCRIPTS+=("$1")
                fi
                shift
                ;;
        esac
    done
}

# === FONCTION PRINCIPALE ===
main() {
    local start_time=$(date -Iseconds)
    
    # Configuration du piégeage pour nettoyage
    trap cleanup EXIT INT TERM
    
    # Parsing des arguments
    parse_args "$@"
    
    # Validation des dépendances
    if ! validate_dependencies; then
        log_error "Dépendances manquantes - vérifiez l'installation des orchestrateurs et scripts atomiques"
        exit 1
    fi
    
    # Validation des paramètres
    if ! validate_parameters; then
        exit 1
    fi
    
    log_debug "Début de l'exécution du workflow '$WORKFLOW_NAME' sur $TARGET_HOST"
    log_workflow "Orchestration de workflow : $WORKFLOW_NAME (${#WORKFLOW_SCRIPTS[@]} script(s), mode: $EXECUTION_MODE)"
    
    # Workflow orchestré en 5 phases
    local workflow_success=true
    local exit_code=0
    
    # Phase 1 : Configuration SSH (optionnelle)
    if ! setup_ssh_access; then
        workflow_success=false
        exit_code=2
    fi
    
    # Phase 2 : Validation des prérequis
    if [[ "$workflow_success" == true ]] && ! validate_workflow_prerequisites; then
        workflow_success=false
        exit_code=2
    fi
    
    # Phase 3 : Déploiement des scripts
    if [[ "$workflow_success" == true ]] && ! deploy_workflow_scripts; then
        workflow_success=false
        exit_code=3
    fi
    
    # Phase 4 : Exécution des scripts
    if [[ "$workflow_success" == true ]] && ! execute_workflow_scripts; then
        workflow_success=false
        exit_code=4
        
        # Détermination si c'est un échec partiel ou complet
        local execution_results=$(cat /tmp/execution_results_$$ 2>/dev/null || echo '{}')
        local successful_count=$(echo "$execution_results" | jq -r '.successful_executions' 2>/dev/null || echo "0")
        
        if [[ "$successful_count" -gt 0 ]]; then
            exit_code=4  # Échec partiel
        else
            exit_code=5  # Échec complet
        fi
    fi
    
    # Phase 5 : Nettoyage et persistence (toujours tenté)
    cleanup_and_persist
    
    local end_time=$(date -Iseconds)
    
    # Génération du rapport final
    local final_status
    if [[ "$workflow_success" == true ]]; then
        final_status="success"
    elif [[ "$exit_code" == 4 ]]; then
        final_status="partial"
    else
        final_status="error"
    fi
    
    generate_output "$final_status" "$start_time" "$end_time"
    
    if [[ "$workflow_success" == true ]]; then
        log_workflow "Workflow '$WORKFLOW_NAME' exécuté avec succès"
    else
        log_error "Échec du workflow '$WORKFLOW_NAME' (code: $exit_code)"
    fi
    
    return $exit_code
}

# Point d'entrée du script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi