#!/usr/bin/env bash
#===============================================================================
# Orchestrateur SSH : Déploiement Multi-Serveurs
#===============================================================================
# Nom du fichier : deploy-ssh.multiserver.sh
# Niveau : 1 (Orchestrateur)
# Catégorie : network
# Protocole : ssh
# Description : Déploie des clés SSH sur plusieurs serveurs avec orchestration avancée
#
# Objectif :
# - Déploiement massif de clés SSH sur une infrastructure
# - Support de différents groupes de serveurs et environnements
# - Validation et rollback automatique en cas d'échec
# - Rapport détaillé de déploiement avec métriques
#
# Conforme à la méthodologie AtomicOps-Suite - Niveau 1
#===============================================================================

set -euo pipefail

# === MÉTADONNÉES DU SCRIPT ===
readonly SCRIPT_NAME="deploy-ssh.multiserver.sh"
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_CATEGORY="network"
readonly SCRIPT_PROTOCOL="ssh"
readonly SCRIPT_LEVEL=1

# === CHEMINS DES SCRIPTS ATOMIQUES ===
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ATOMICS_DIR="$(realpath "$SCRIPT_DIR/../../atomics")"

# Scripts atomiques utilisés
readonly ADD_SSH_KEY="$ATOMICS_DIR/network/add-ssh.key.authorized.sh"
readonly CHECK_SSH_CONNECTION="$ATOMICS_DIR/network/check-ssh.connection.sh"
readonly LIST_SSH_KEYS="$ATOMICS_DIR/network/list-ssh.keys.sh"

# === CONFIGURATION PAR DÉFAUT ===
readonly DEFAULT_SSH_PORT=22
readonly DEFAULT_TIMEOUT=30
readonly DEFAULT_MAX_PARALLEL=10
readonly DEFAULT_RETRY_ATTEMPTS=3
readonly DEFAULT_RETRY_DELAY=5

# === VARIABLES GLOBALES ===
SSH_KEY_FILE=""
TARGET_SERVERS=()
TARGET_USERS=()  # Utilisateurs cibles (peut être différent par serveur)
SERVER_GROUPS=()  # Groupes de serveurs pour déploiement par phases
DEPLOYMENT_STRATEGY="parallel"  # parallel|sequential|rolling|canary
MAX_PARALLEL_DEPLOYMENTS="$DEFAULT_MAX_PARALLEL"
CANARY_PERCENTAGE=10
ROLLING_BATCH_SIZE=5
DEPLOYMENT_ORDER="alphabetical"  # alphabetical|priority|random
SERVER_PRIORITIES=()  # Priorités pour l'ordre de déploiement
RETRY_ATTEMPTS="$DEFAULT_RETRY_ATTEMPTS"
RETRY_DELAY="$DEFAULT_RETRY_DELAY"
CONNECTION_TIMEOUT="$DEFAULT_TIMEOUT"
VALIDATE_DEPLOYMENT=true
CONTINUE_ON_FAILURE=false
ROLLBACK_ON_FAILURE=true
BACKUP_EXISTING_KEYS=true
DEPLOYMENT_ID=""
PROGRESS_REPORTING=true
DRY_RUN=false
QUIET_MODE=false
DEBUG_MODE=false
JSON_ONLY=false

# Configuration avancée
ENABLE_HEALTH_CHECK=true
PRE_DEPLOYMENT_VALIDATION=true
POST_DEPLOYMENT_VERIFICATION=true
GENERATE_DEPLOYMENT_REPORT=true
DEPLOYMENT_LOG_FILE=""
EXCLUDE_SERVERS=()  # Serveurs à exclure du déploiement
INCLUDE_ONLY_SERVERS=()  # Seulement ces serveurs (si spécifié)

# Métriques de performance
DEPLOYMENT_START_TIME=0
PRE_VALIDATION_TIME=0
DEPLOYMENT_EXECUTION_TIME=0
POST_VERIFICATION_TIME=0
TOTAL_EXECUTION_TIME=0

# État de déploiement
SERVERS_TOTAL=0
SERVERS_PROCESSED=0
SERVERS_SUCCESS=0
SERVERS_FAILED=0
SERVERS_SKIPPED=0
RETRIES_PERFORMED=0
ROLLBACKS_EXECUTED=0
DEPLOYMENT_PHASES=0

# Stockage des résultats détaillés
declare -A SERVER_STATUS  # success|failed|skipped|retried
declare -A SERVER_ERRORS
declare -A SERVER_RETRY_COUNT
declare -A SERVER_DEPLOYMENT_TIME
declare -A SERVER_BACKUP_PATHS
declare -A SERVER_GROUPS_MAP
declare -A GROUP_RESULTS

# Configuration par serveur/groupe
declare -A SERVER_CONFIGS  # Configurations spécifiques par serveur
declare -A GROUP_CONFIGS   # Configurations par groupe

# Résultats JSON
JSON_RESULT=""

# === FONCTIONS DE LOGGING ===
log_debug() { [[ "$DEBUG_MODE" == true ]] && echo "[DEBUG] $*" >&2; }
log_info() { [[ "$QUIET_MODE" == false ]] && [[ "$JSON_ONLY" == false ]] && echo "[INFO] $*" >&2; }
log_warn() { [[ "$JSON_ONLY" == false ]] && echo "[WARN] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }

# === FONCTIONS UTILITAIRES ===
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 && "$DRY_RUN" == false ]]; then
        log_debug "Nettoyage en cas d'erreur (code: $exit_code)"
        
        if [[ "$ROLLBACK_ON_FAILURE" == true && "$SERVERS_PROCESSED" -gt 0 ]]; then
            log_warn "Exécution du rollback automatique"
            execute_rollback
        fi
    fi
    
    # Génération du rapport final si demandé
    if [[ "$GENERATE_DEPLOYMENT_REPORT" == true ]]; then
        generate_deployment_report
    fi
    
    return $exit_code
}

generate_deployment_id() {
    DEPLOYMENT_ID="deploy_$(date +%Y%m%d_%H%M%S)_$$"
    
    if [[ "$GENERATE_DEPLOYMENT_REPORT" == true && -z "$DEPLOYMENT_LOG_FILE" ]]; then
        DEPLOYMENT_LOG_FILE="/tmp/ssh_deployment_${DEPLOYMENT_ID}.log"
    fi
}

show_help() {
    cat << 'EOF'
USAGE:
    deploy-ssh.multiserver.sh [OPTIONS] --key-file <path> --servers <server1,server2,...>

DESCRIPTION:
    Déploie des clés SSH sur plusieurs serveurs avec orchestration avancée.
    
    Ce script orchestre :
    1. Validation pré-déploiement des serveurs cibles
    2. Déploiement selon la stratégie choisie
    3. Vérification post-déploiement
    4. Rapport détaillé et métriques

OPTIONS OBLIGATOIRES:
    --key-file <path>            Fichier de clé publique SSH à déployer
    --servers <host1,host2>      Liste des serveurs cibles (séparés par virgules)

OPTIONS DE CIBLAGE:
    --users <user1,user2>        Utilisateurs cibles (défaut: utilisateur actuel)
    --groups <group1,group2>     Groupes de serveurs pour déploiement par phases
    --exclude <host1,host2>      Serveurs à exclure du déploiement
    --include-only <host1,host2> Seulement ces serveurs (filtre)
    --priorities <1,2,3>         Priorités pour l'ordre de déploiement

OPTIONS DE STRATÉGIE:
    --strategy <type>            Stratégie de déploiement (parallel|sequential|rolling|canary)
    --max-parallel <number>      Déploiements simultanés max (défaut: 10)
    --canary-percentage <num>    Pourcentage serveurs pour canary (défaut: 10)
    --rolling-batch <size>       Taille de batch pour rolling (défaut: 5)
    --deployment-order <type>    Ordre de déploiement (alphabetical|priority|random)

OPTIONS DE FIABILITÉ:
    --retry-attempts <number>    Nombre de tentatives en cas d'échec (défaut: 3)
    --retry-delay <seconds>      Délai entre tentatives (défaut: 5)
    --timeout <seconds>          Timeout de connexion (défaut: 30)
    --continue-on-failure        Continue même si certains serveurs échouent
    --no-rollback               Pas de rollback automatique en cas d'échec
    --no-backup                 Ne sauvegarde pas les clés existantes
    --skip-validation           Ignore la validation pré-déploiement
    --skip-verification         Ignore la vérification post-déploiement

OPTIONS DE REPORTING:
    --log-file <path>           Fichier de log de déploiement
    --no-progress              Désactive le reporting de progression
    --no-report                Pas de rapport de déploiement
    --deployment-id <id>        ID personnalisé pour ce déploiement

OPTIONS GÉNÉRALES:
    --dry-run                   Simulation sans exécution réelle
    --quiet                     Mode silencieux (pas de logs informatifs)
    --debug                     Mode debug détaillé
    --json                      Sortie JSON uniquement
    --help                      Affiche cette aide

SORTIE JSON:
    {
      "status": "success|error|partial",
      "data": {
        "deployment_summary": {
          "deployment_id": "deploy_20241203_143022_12345",
          "servers_total": 15,
          "servers_success": 13,
          "servers_failed": 2,
          "servers_skipped": 0,
          "retries_performed": 3,
          "rollbacks_executed": 0,
          "deployment_phases": 3
        },
        "server_results": {
          "web1.example.com": {
            "status": "success",
            "deployment_time_ms": 1234,
            "retry_count": 0,
            "backup_created": true,
            "group": "web-servers"
          },
          "db1.example.com": {
            "status": "failed",
            "error": "Connection timeout",
            "retry_count": 3,
            "last_attempt": "2024-12-03T14:35:22Z"
          }
        },
        "group_results": {
          "web-servers": {
            "total": 5,
            "success": 5,
            "failed": 0
          },
          "database-servers": {
            "total": 3,
            "success": 2,
            "failed": 1
          }
        },
        "performance": {
          "pre_validation_ms": 2340,
          "deployment_ms": 45670,
          "post_verification_ms": 8900,
          "total_ms": 56910
        }
      },
      "message": "Déploiement réussi sur 13/15 serveurs"
    }

CODES DE SORTIE:
    0 - Déploiement réussi sur tous les serveurs
    1 - Erreur de paramètres ou prérequis
    2 - Échec de validation pré-déploiement
    3 - Échec partiel de déploiement (certains serveurs en échec)
    4 - Échec total de déploiement
    5 - Échec de vérification post-déploiement
    6 - Erreur générale d'orchestration

EXEMPLES:
    # Déploiement basique sur plusieurs serveurs
    ./deploy-ssh.multiserver.sh --key-file ~/.ssh/id_rsa.pub \
        --servers "web1.com,web2.com,web3.com"

    # Déploiement avec stratégie canary
    ./deploy-ssh.multiserver.sh --key-file /keys/deploy.pub \
        --servers "prod1.com,prod2.com,prod3.com,prod4.com,prod5.com" \
        --strategy canary --canary-percentage 20

    # Déploiement rolling avec groupes
    ./deploy-ssh.multiserver.sh --key-file /keys/admin.pub \
        --servers "web1.com,web2.com,db1.com,db2.com,cache1.com" \
        --groups "web-servers,database-servers,cache-servers" \
        --strategy rolling --rolling-batch 2

    # Déploiement avec retry et reporting
    ./deploy-ssh.multiserver.sh --key-file /keys/service.pub \
        --servers "node1.cluster.local,node2.cluster.local,node3.cluster.local" \
        --retry-attempts 5 --retry-delay 10 \
        --log-file /var/log/ssh-deployment.log

    # Mode dry-run avec debug
    ./deploy-ssh.multiserver.sh --key-file /keys/test.pub \
        --servers "test1.local,test2.local" --dry-run --debug

STRATÉGIES DE DÉPLOIEMENT:
    parallel    : Tous les serveurs simultanément (plus rapide)
    sequential  : Un serveur à la fois (plus sûr)
    rolling     : Par batchs successifs avec validation
    canary      : Teste d'abord sur un sous-ensemble
EOF
}

# === PARSING DES ARGUMENTS ===
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --key-file)
                SSH_KEY_FILE="$2"
                shift 2
                ;;
            --servers)
                IFS=',' read -ra TARGET_SERVERS <<< "$2"
                shift 2
                ;;
            --users)
                IFS=',' read -ra TARGET_USERS <<< "$2"
                shift 2
                ;;
            --groups)
                IFS=',' read -ra SERVER_GROUPS <<< "$2"
                shift 2
                ;;
            --exclude)
                IFS=',' read -ra EXCLUDE_SERVERS <<< "$2"
                shift 2
                ;;
            --include-only)
                IFS=',' read -ra INCLUDE_ONLY_SERVERS <<< "$2"
                shift 2
                ;;
            --priorities)
                IFS=',' read -ra SERVER_PRIORITIES <<< "$2"
                shift 2
                ;;
            --strategy)
                DEPLOYMENT_STRATEGY="$2"
                shift 2
                ;;
            --max-parallel)
                if [[ "$2" =~ ^[0-9]+$ ]] && [[ "$2" -gt 0 ]]; then
                    MAX_PARALLEL_DEPLOYMENTS="$2"
                else
                    log_error "Nombre max parallèle invalide : $2"
                    return 1
                fi
                shift 2
                ;;
            --canary-percentage)
                if [[ "$2" =~ ^[0-9]+$ ]] && [[ "$2" -ge 1 && "$2" -le 100 ]]; then
                    CANARY_PERCENTAGE="$2"
                else
                    log_error "Pourcentage canary invalide : $2"
                    return 1
                fi
                shift 2
                ;;
            --rolling-batch)
                if [[ "$2" =~ ^[0-9]+$ ]] && [[ "$2" -gt 0 ]]; then
                    ROLLING_BATCH_SIZE="$2"
                else
                    log_error "Taille de batch rolling invalide : $2"
                    return 1
                fi
                shift 2
                ;;
            --deployment-order)
                DEPLOYMENT_ORDER="$2"
                shift 2
                ;;
            --retry-attempts)
                if [[ "$2" =~ ^[0-9]+$ ]] && [[ "$2" -ge 0 ]]; then
                    RETRY_ATTEMPTS="$2"
                else
                    log_error "Nombre de tentatives invalide : $2"
                    return 1
                fi
                shift 2
                ;;
            --retry-delay)
                if [[ "$2" =~ ^[0-9]+$ ]] && [[ "$2" -ge 0 ]]; then
                    RETRY_DELAY="$2"
                else
                    log_error "Délai de retry invalide : $2"
                    return 1
                fi
                shift 2
                ;;
            --timeout)
                if [[ "$2" =~ ^[0-9]+$ ]] && [[ "$2" -gt 0 ]]; then
                    CONNECTION_TIMEOUT="$2"
                else
                    log_error "Timeout invalide : $2"
                    return 1
                fi
                shift 2
                ;;
            --log-file)
                DEPLOYMENT_LOG_FILE="$2"
                shift 2
                ;;
            --deployment-id)
                DEPLOYMENT_ID="$2"
                shift 2
                ;;
            --continue-on-failure)
                CONTINUE_ON_FAILURE=true
                shift
                ;;
            --no-rollback)
                ROLLBACK_ON_FAILURE=false
                shift
                ;;
            --no-backup)
                BACKUP_EXISTING_KEYS=false
                shift
                ;;
            --skip-validation)
                PRE_DEPLOYMENT_VALIDATION=false
                shift
                ;;
            --skip-verification)
                POST_DEPLOYMENT_VERIFICATION=false
                shift
                ;;
            --no-progress)
                PROGRESS_REPORTING=false
                shift
                ;;
            --no-report)
                GENERATE_DEPLOYMENT_REPORT=false
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --quiet)
                QUIET_MODE=true
                shift
                ;;
            --debug)
                DEBUG_MODE=true
                shift
                ;;
            --json)
                JSON_ONLY=true
                QUIET_MODE=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Option inconnue : $1"
                show_help >&2
                return 1
                ;;
        esac
    done
}

# === VALIDATION DES PARAMÈTRES ===
validate_parameters() {
    local errors=0
    
    # Paramètre obligatoire : fichier de clé
    if [[ -z "$SSH_KEY_FILE" ]]; then
        log_error "Paramètre --key-file requis"
        ((errors++))
    elif [[ ! -f "$SSH_KEY_FILE" ]]; then
        log_error "Fichier de clé non trouvé : $SSH_KEY_FILE"
        ((errors++))
    elif [[ ! -r "$SSH_KEY_FILE" ]]; then
        log_error "Fichier de clé non lisible : $SSH_KEY_FILE"
        ((errors++))
    fi
    
    # Paramètre obligatoire : serveurs cibles
    if [[ ${#TARGET_SERVERS[@]} -eq 0 ]]; then
        log_error "Paramètre --servers requis (au moins un serveur)"
        ((errors++))
    fi
    
    # Validation de la stratégie de déploiement
    case "$DEPLOYMENT_STRATEGY" in
        parallel|sequential|rolling|canary)
            # Stratégies valides
            ;;
        *)
            log_error "Stratégie de déploiement invalide : $DEPLOYMENT_STRATEGY"
            ((errors++))
            ;;
    esac
    
    # Validation de l'ordre de déploiement
    case "$DEPLOYMENT_ORDER" in
        alphabetical|priority|random)
            # Ordres valides
            ;;
        *)
            log_error "Ordre de déploiement invalide : $DEPLOYMENT_ORDER"
            ((errors++))
            ;;
    esac
    
    # Configuration par défaut des utilisateurs cibles
    if [[ ${#TARGET_USERS[@]} -eq 0 ]]; then
        TARGET_USERS=("$(whoami)")
    fi
    
    return $errors
}

# === VALIDATION DES PRÉREQUIS ===
validate_prerequisites() {
    local errors=0
    
    # Vérification des scripts atomiques
    local required_scripts=("$ADD_SSH_KEY" "$CHECK_SSH_CONNECTION" "$LIST_SSH_KEYS")
    
    for script in "${required_scripts[@]}"; do
        if [[ ! -f "$script" ]]; then
            log_error "Script atomique manquant : $script"
            ((errors++))
        elif [[ ! -x "$script" ]]; then
            log_error "Script atomique non exécutable : $script"
            ((errors++))
        fi
    done
    
    # Vérification des commandes système requises
    local required_commands=("ssh" "jq" "bc" "sort" "shuf")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Commande requise manquante : $cmd"
            ((errors++))
        fi
    done
    
    return $errors
}

# === PRÉPARATION DU DÉPLOIEMENT ===
prepare_deployment() {
    # Générer l'ID de déploiement si nécessaire
    [[ -z "$DEPLOYMENT_ID" ]] && generate_deployment_id
    
    # Filtrer les serveurs selon les options include/exclude
    filter_target_servers
    
    # Organiser les serveurs par groupes si spécifié
    organize_server_groups
    
    # Déterminer l'ordre de déploiement
    determine_deployment_order
    
    log_info "Déploiement préparé : ID=$DEPLOYMENT_ID, Serveurs=$SERVERS_TOTAL"
}

filter_target_servers() {
    local filtered_servers=()
    
    # Appliquer le filtre include-only si spécifié
    if [[ ${#INCLUDE_ONLY_SERVERS[@]} -gt 0 ]]; then
        for server in "${TARGET_SERVERS[@]}"; do
            for include_server in "${INCLUDE_ONLY_SERVERS[@]}"; do
                if [[ "$server" == "$include_server" ]]; then
                    filtered_servers+=("$server")
                    break
                fi
            done
        done
        TARGET_SERVERS=("${filtered_servers[@]}")
        filtered_servers=()
    fi
    
    # Appliquer le filtre exclude
    if [[ ${#EXCLUDE_SERVERS[@]} -gt 0 ]]; then
        for server in "${TARGET_SERVERS[@]}"; do
            local excluded=false
            for exclude_server in "${EXCLUDE_SERVERS[@]}"; do
                if [[ "$server" == "$exclude_server" ]]; then
                    excluded=true
                    break
                fi
            done
            
            if [[ "$excluded" == false ]]; then
                filtered_servers+=("$server")
            else
                log_debug "Serveur exclu : $server"
                SERVER_STATUS["$server"]="skipped"
                ((SERVERS_SKIPPED++))
            fi
        done
        TARGET_SERVERS=("${filtered_servers[@]}")
    fi
    
    SERVERS_TOTAL=${#TARGET_SERVERS[@]}
}

organize_server_groups() {
    if [[ ${#SERVER_GROUPS[@]} -eq 0 ]]; then
        # Pas de groupes spécifiés, tous les serveurs dans un groupe par défaut
        SERVER_GROUPS=("default")
        for server in "${TARGET_SERVERS[@]}"; do
            SERVER_GROUPS_MAP["$server"]="default"
        done
    else
        # Assigner les serveurs aux groupes (distribution équitable)
        local group_index=0
        for server in "${TARGET_SERVERS[@]}"; do
            local group="${SERVER_GROUPS[$group_index]}"
            SERVER_GROUPS_MAP["$server"]="$group"
            ((group_index++))
            
            # Boucler sur les groupes
            if [[ $group_index -ge ${#SERVER_GROUPS[@]} ]]; then
                group_index=0
            fi
        done
    fi
}

determine_deployment_order() {
    case "$DEPLOYMENT_ORDER" in
        alphabetical)
            # Tri alphabétique (déjà fait par défaut)
            readarray -t TARGET_SERVERS < <(printf '%s\n' "${TARGET_SERVERS[@]}" | sort)
            ;;
        priority)
            # Tri par priorité si spécifiées
            if [[ ${#SERVER_PRIORITIES[@]} -eq ${#TARGET_SERVERS[@]} ]]; then
                # Créer un tableau associatif pour les priorités
                local -A priority_map
                local i=0
                for server in "${TARGET_SERVERS[@]}"; do
                    priority_map["$server"]=${SERVER_PRIORITIES[$i]}
                    ((i++))
                done
                
                # Trier par priorité (plus petit = plus prioritaire)
                readarray -t TARGET_SERVERS < <(
                    for server in "${TARGET_SERVERS[@]}"; do
                        echo "${priority_map[$server]} $server"
                    done | sort -n | cut -d' ' -f2-
                )
            else
                log_warn "Priorités non définies pour tous les serveurs, ordre alphabétique utilisé"
            fi
            ;;
        random)
            # Ordre aléatoire
            readarray -t TARGET_SERVERS < <(printf '%s\n' "${TARGET_SERVERS[@]}" | shuf)
            ;;
    esac
}

# === VALIDATION PRÉ-DÉPLOIEMENT ===
pre_deployment_validation() {
    if [[ "$PRE_DEPLOYMENT_VALIDATION" == false ]]; then
        log_info "Validation pré-déploiement ignorée (--skip-validation)"
        PRE_VALIDATION_TIME=0
        return 0
    fi
    
    log_info "ÉTAPE 1/3 : Validation pré-déploiement"
    local validation_start=$(date +%s.%N)
    
    local validation_errors=0
    
    for server in "${TARGET_SERVERS[@]}"; do
        if ! validate_server_connectivity "$server"; then
            ((validation_errors++))
            if [[ "$CONTINUE_ON_FAILURE" == false ]]; then
                break
            fi
        fi
    done
    
    local validation_end=$(date +%s.%N)
    PRE_VALIDATION_TIME=$(echo "($validation_end - $validation_start) * 1000" | bc -l 2>/dev/null | cut -d. -f1)
    
    if [[ $validation_errors -gt 0 && "$CONTINUE_ON_FAILURE" == false ]]; then
        log_error "Validation pré-déploiement échouée sur $validation_errors serveurs"
        return 2
    fi
    
    log_info "Validation pré-déploiement terminée"
    return 0
}

validate_server_connectivity() {
    local server="$1"
    local user="${TARGET_USERS[0]}"  # Utiliser le premier utilisateur pour la validation
    
    if [[ "$DRY_RUN" == true ]]; then
        log_debug "MODE DRY-RUN : Validation de $server simulée"
        return 0
    fi
    
    # Test de connectivité basique
    local test_args=()
    test_args+=("--host" "$server")
    test_args+=("--user" "$user")
    test_args+=("--timeout" "$CONNECTION_TIMEOUT")
    test_args+=("--quick-test")  # Option pour test rapide
    
    [[ "$QUIET_MODE" == true ]] && test_args+=("--quiet")
    [[ "$DEBUG_MODE" == true ]] && test_args+=("--debug")
    
    local test_result
    if test_result=$("$CHECK_SSH_CONNECTION" "${test_args[@]}" 2>/dev/null); then
        local conn_status=$(echo "$test_result" | jq -r '.data.connection_status' 2>/dev/null || echo "failed")
        if [[ "$conn_status" == "success" ]]; then
            log_debug "Validation réussie pour $server"
            return 0
        fi
    fi
    
    log_warn "Validation échouée pour $server"
    SERVER_STATUS["$server"]="validation_failed"
    return 1
}

# === EXÉCUTION DU DÉPLOIEMENT ===
execute_deployment() {
    log_info "ÉTAPE 2/3 : Exécution du déploiement ($DEPLOYMENT_STRATEGY)"
    local deployment_start=$(date +%s.%N)
    
    case "$DEPLOYMENT_STRATEGY" in
        parallel)
            execute_parallel_deployment
            ;;
        sequential)
            execute_sequential_deployment
            ;;
        rolling)
            execute_rolling_deployment
            ;;
        canary)
            execute_canary_deployment
            ;;
    esac
    
    local deployment_end=$(date +%s.%N)
    DEPLOYMENT_EXECUTION_TIME=$(echo "($deployment_end - $deployment_start) * 1000" | bc -l 2>/dev/null | cut -d. -f1)
    
    log_info "Déploiement terminé : $SERVERS_SUCCESS/$SERVERS_TOTAL serveurs réussis"
    
    # Évaluer le succès global
    if [[ "$SERVERS_SUCCESS" -eq 0 ]]; then
        return 4  # Échec total
    elif [[ "$SERVERS_SUCCESS" -lt "$SERVERS_TOTAL" ]]; then
        return 3  # Échec partiel
    fi
    
    return 0
}

execute_parallel_deployment() {
    log_info "Déploiement parallèle (max: $MAX_PARALLEL_DEPLOYMENTS)"
    
    local active_jobs=0
    local job_pids=()
    
    for server in "${TARGET_SERVERS[@]}"; do
        # Attendre si trop de jobs actifs
        while [[ $active_jobs -ge $MAX_PARALLEL_DEPLOYMENTS ]]; do
            wait_for_job_completion job_pids active_jobs
        done
        
        # Lancer le déploiement sur ce serveur
        deploy_to_server "$server" &
        local job_pid=$!
        job_pids+=("$job_pid")
        ((active_jobs++))
        
        log_debug "Déploiement lancé sur $server (PID: $job_pid)"
    done
    
    # Attendre la fin de tous les jobs
    for pid in "${job_pids[@]}"; do
        wait "$pid"
    done
}

execute_sequential_deployment() {
    log_info "Déploiement séquentiel sur $SERVERS_TOTAL serveurs"
    
    for server in "${TARGET_SERVERS[@]}"; do
        deploy_to_server "$server"
        ((SERVERS_PROCESSED++))
        
        # Arrêt en cas d'échec si continue-on-failure désactivé
        if [[ "${SERVER_STATUS[$server]}" != "success" && "$CONTINUE_ON_FAILURE" == false ]]; then
            log_warn "Arrêt du déploiement séquentiel après échec sur $server"
            break
        fi
        
        # Reporting de progression
        if [[ "$PROGRESS_REPORTING" == true ]]; then
            local progress=$((SERVERS_PROCESSED * 100 / SERVERS_TOTAL))
            log_info "Progression : $progress% ($SERVERS_PROCESSED/$SERVERS_TOTAL)"
        fi
    done
}

execute_rolling_deployment() {
    log_info "Déploiement rolling avec batch de $ROLLING_BATCH_SIZE serveurs"
    
    local batch_servers=()
    local batch_count=0
    ((DEPLOYMENT_PHASES++))
    
    for server in "${TARGET_SERVERS[@]}"; do
        batch_servers+=("$server")
        ((batch_count++))
        
        # Traiter le batch quand il est plein ou au dernier serveur
        if [[ $batch_count -eq $ROLLING_BATCH_SIZE ]] || [[ $server == "${TARGET_SERVERS[-1]}" ]]; then
            log_info "Phase $DEPLOYMENT_PHASES : déploiement sur batch de ${#batch_servers[@]} serveurs"
            
            # Déploiement parallèle du batch
            local batch_pids=()
            for batch_server in "${batch_servers[@]}"; do
                deploy_to_server "$batch_server" &
                batch_pids+=($!)
            done
            
            # Attendre la fin du batch
            for pid in "${batch_pids[@]}"; do
                wait "$pid"
            done
            
            # Vérifier le succès du batch
            local batch_failures=0
            for batch_server in "${batch_servers[@]}"; do
                if [[ "${SERVER_STATUS[$batch_server]}" != "success" ]]; then
                    ((batch_failures++))
                fi
                ((SERVERS_PROCESSED++))
            done
            
            if [[ $batch_failures -gt 0 && "$CONTINUE_ON_FAILURE" == false ]]; then
                log_error "Échec de $batch_failures serveurs dans la phase $DEPLOYMENT_PHASES"
                break
            fi
            
            # Reset pour le prochain batch
            batch_servers=()
            batch_count=0
            ((DEPLOYMENT_PHASES++))
        fi
    done
}

execute_canary_deployment() {
    log_info "Déploiement canary avec $CANARY_PERCENTAGE% des serveurs"
    
    # Calculer le nombre de serveurs canary
    local canary_count=$(( (SERVERS_TOTAL * CANARY_PERCENTAGE) / 100 ))
    [[ $canary_count -eq 0 ]] && canary_count=1
    
    log_info "Phase canary : déploiement sur $canary_count serveurs"
    ((DEPLOYMENT_PHASES++))
    
    # Phase 1: Déploiement canary
    local canary_failures=0
    for ((i=0; i<canary_count; i++)); do
        deploy_to_server "${TARGET_SERVERS[$i]}"
        ((SERVERS_PROCESSED++))
        
        if [[ "${SERVER_STATUS[${TARGET_SERVERS[$i]}]}" != "success" ]]; then
            ((canary_failures++))
        fi
    done
    
    # Évaluer le succès du canary
    if [[ $canary_failures -gt 0 ]]; then
        log_error "Échec de $canary_failures serveurs canary sur $canary_count"
        if [[ "$CONTINUE_ON_FAILURE" == false ]]; then
            return 3
        fi
    fi
    
    log_info "Phase canary réussie - déploiement sur les $((SERVERS_TOTAL - canary_count)) serveurs restants"
    ((DEPLOYMENT_PHASES++))
    
    # Phase 2: Déploiement sur le reste (en parallèle)
    local remaining_pids=()
    for ((i=canary_count; i<SERVERS_TOTAL; i++)); do
        deploy_to_server "${TARGET_SERVERS[$i]}" &
        remaining_pids+=($!)
    done
    
    # Attendre la fin du déploiement complet
    for pid in "${remaining_pids[@]}"; do
        wait "$pid"
    done
    
    SERVERS_PROCESSED=$SERVERS_TOTAL
}

wait_for_job_completion() {
    local -n pids_ref=$1
    local -n active_ref=$2
    
    # Attendre qu'au moins un job se termine
    local completed_pid
    completed_pid=$(wait -n "${pids_ref[@]}" 2>/dev/null; echo $!)
    
    # Retirer le PID terminé de la liste
    local new_pids=()
    for pid in "${pids_ref[@]}"; do
        if [[ "$pid" != "$completed_pid" ]]; then
            new_pids+=("$pid")
        fi
    done
    
    pids_ref=("${new_pids[@]}")
    ((active_ref--))
}

# === DÉPLOIEMENT SUR UN SERVEUR ===
deploy_to_server() {
    local server="$1"
    local deploy_start=$(date +%s.%N)
    
    log_debug "Début déploiement sur $server"
    
    # Initialiser le statut et compteur de retry
    SERVER_STATUS["$server"]="processing"
    SERVER_RETRY_COUNT["$server"]=0
    
    # Tentatives avec retry
    local success=false
    for ((attempt=1; attempt<=RETRY_ATTEMPTS+1; attempt++)); do
        if attempt_deployment_on_server "$server"; then
            success=true
            break
        else
            if [[ $attempt -le $RETRY_ATTEMPTS ]]; then
                log_warn "Tentative $attempt échouée sur $server, retry dans ${RETRY_DELAY}s"
                SERVER_RETRY_COUNT["$server"]=$attempt
                ((RETRIES_PERFORMED++))
                sleep "$RETRY_DELAY"
            fi
        fi
    done
    
    # Finaliser le statut
    if [[ "$success" == true ]]; then
        SERVER_STATUS["$server"]="success"
        ((SERVERS_SUCCESS++))
        log_debug "Déploiement réussi sur $server"
    else
        SERVER_STATUS["$server"]="failed"
        ((SERVERS_FAILED++))
        log_error "Déploiement échoué sur $server après $RETRY_ATTEMPTS tentatives"
    fi
    
    local deploy_end=$(date +%s.%N)
    SERVER_DEPLOYMENT_TIME["$server"]=$(echo "($deploy_end - $deploy_start) * 1000" | bc -l 2>/dev/null | cut -d. -f1)
}

attempt_deployment_on_server() {
    local server="$1"
    local user="${TARGET_USERS[0]}"  # Premier utilisateur par défaut
    
    if [[ "$DRY_RUN" == true ]]; then
        log_debug "MODE DRY-RUN : Déploiement sur $server simulé"
        return 0
    fi
    
    # Sauvegarde des clés existantes si demandée
    if [[ "$BACKUP_EXISTING_KEYS" == true ]]; then
        backup_existing_keys_on_server "$server" "$user"
    fi
    
    # Préparer les arguments pour add-ssh.key.authorized.sh
    local deploy_args=()
    deploy_args+=("--host" "$server")
    deploy_args+=("--user" "$user")
    deploy_args+=("--key-file" "$SSH_KEY_FILE")
    deploy_args+=("--timeout" "$CONNECTION_TIMEOUT")
    
    [[ "$QUIET_MODE" == true ]] && deploy_args+=("--quiet")
    [[ "$DEBUG_MODE" == true ]] && deploy_args+=("--debug")
    
    log_debug "Commande déploiement : $ADD_SSH_KEY ${deploy_args[*]}"
    
    local deploy_result
    if deploy_result=$("$ADD_SSH_KEY" "${deploy_args[@]}" 2>/dev/null); then
        local deploy_status=$(echo "$deploy_result" | jq -r '.status' 2>/dev/null || echo "error")
        if [[ "$deploy_status" == "success" ]]; then
            return 0
        else
            SERVER_ERRORS["$server"]="Échec d'ajout de clé SSH"
            return 1
        fi
    else
        SERVER_ERRORS["$server"]="Connexion SSH échouée"
        return 1
    fi
}

backup_existing_keys_on_server() {
    local server="$1"
    local user="$2"
    local backup_path="/tmp/ssh_backup_${DEPLOYMENT_ID}_$(date +%s)"
    
    local backup_cmd="mkdir -p $backup_path && cp ~/.ssh/authorized_keys $backup_path/ 2>/dev/null || true"
    
    if ssh -o ConnectTimeout="$CONNECTION_TIMEOUT" "$user@$server" "$backup_cmd"; then
        SERVER_BACKUP_PATHS["$server"]="$backup_path"
        log_debug "Sauvegarde créée pour $server : $backup_path"
    else
        log_warn "Échec de sauvegarde pour $server"
    fi
}

# === VÉRIFICATION POST-DÉPLOIEMENT ===
post_deployment_verification() {
    if [[ "$POST_DEPLOYMENT_VERIFICATION" == false ]]; then
        log_info "Vérification post-déploiement ignorée (--skip-verification)"
        POST_VERIFICATION_TIME=0
        return 0
    fi
    
    log_info "ÉTAPE 3/3 : Vérification post-déploiement"
    local verification_start=$(date +%s.%N)
    
    local verification_errors=0
    
    for server in "${TARGET_SERVERS[@]}"; do
        if [[ "${SERVER_STATUS[$server]}" == "success" ]]; then
            verify_deployment_on_server "$server"
        else
            log_debug "Vérification ignorée pour $server (déploiement échoué)"
        fi
    done
    
    local verification_end=$(date +%s.%N)
    POST_VERIFICATION_TIME=$(echo "($verification_end - $verification_start) * 1000" | bc -l 2>/dev/null | cut -d. -f1)
    
    log_info "Vérification post-déploiement terminée"
    return 0
}

verify_deployment_on_server() {
    local server="$1"
    local user="${TARGET_USERS[0]}"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_debug "MODE DRY-RUN : Vérification sur $server simulée"
        return 0
    fi
    
    # Test de connexion avec la nouvelle clé
    local verify_args=()
    verify_args+=("--host" "$server")
    verify_args+=("--user" "$user")
    verify_args+=("--timeout" "$CONNECTION_TIMEOUT")
    
    [[ "$QUIET_MODE" == true ]] && verify_args+=("--quiet")
    [[ "$DEBUG_MODE" == true ]] && verify_args+=("--debug")
    
    local verify_result
    if verify_result=$("$CHECK_SSH_CONNECTION" "${verify_args[@]}" 2>/dev/null); then
        local conn_status=$(echo "$verify_result" | jq -r '.data.connection_status' 2>/dev/null || echo "failed")
        if [[ "$conn_status" == "success" ]]; then
            log_debug "Vérification réussie pour $server"
            return 0
        fi
    fi
    
    log_warn "Vérification échouée pour $server"
    return 1
}

# === ROLLBACK EN CAS D'ÉCHEC ===
execute_rollback() {
    log_warn "Exécution du rollback du déploiement"
    
    for server in "${TARGET_SERVERS[@]}"; do
        if [[ "${SERVER_STATUS[$server]}" == "success" && -n "${SERVER_BACKUP_PATHS[$server]:-}" ]]; then
            rollback_server "$server"
        fi
    done
    
    ((ROLLBACKS_EXECUTED++))
}

rollback_server() {
    local server="$1"
    local user="${TARGET_USERS[0]}"
    local backup_path="${SERVER_BACKUP_PATHS[$server]}"
    
    log_debug "Rollback sur $server (backup: $backup_path)"
    
    # Restaurer la sauvegarde
    local restore_cmd="cp $backup_path/authorized_keys ~/.ssh/authorized_keys"
    
    if ssh -o ConnectTimeout="$CONNECTION_TIMEOUT" "$user@$server" "$restore_cmd"; then
        log_debug "Rollback réussi sur $server"
        SERVER_STATUS["$server"]="rollback_success"
    else
        log_error "Échec du rollback sur $server"
        SERVER_STATUS["$server"]="rollback_failed"
    fi
}

# === GÉNÉRATION DU RAPPORT DE DÉPLOIEMENT ===
generate_deployment_report() {
    if [[ "$GENERATE_DEPLOYMENT_REPORT" == false || "$DRY_RUN" == true ]]; then
        return 0
    fi
    
    local report_file="${DEPLOYMENT_LOG_FILE%.log}_report.log"
    [[ -z "$report_file" ]] && report_file="/tmp/deployment_report_${DEPLOYMENT_ID}.log"
    
    {
        echo "=== RAPPORT DE DÉPLOIEMENT SSH ==="
        echo "ID de déploiement : $DEPLOYMENT_ID"
        echo "Date : $(date)"
        echo "Clé déployée : $SSH_KEY_FILE"
        echo "Stratégie : $DEPLOYMENT_STRATEGY"
        echo
        echo "=== RÉSUMÉ ==="
        echo "Serveurs total : $SERVERS_TOTAL"
        echo "Succès : $SERVERS_SUCCESS"
        echo "Échecs : $SERVERS_FAILED"
        echo "Ignorés : $SERVERS_SKIPPED"
        echo "Retries effectués : $RETRIES_PERFORMED"
        echo "Rollbacks : $ROLLBACKS_EXECUTED"
        echo "Phases de déploiement : $DEPLOYMENT_PHASES"
        echo
        echo "=== DÉTAIL PAR SERVEUR ==="
        for server in "${TARGET_SERVERS[@]}"; do
            local status="${SERVER_STATUS[$server]:-unknown}"
            local deploy_time="${SERVER_DEPLOYMENT_TIME[$server]:-0}"
            local retry_count="${SERVER_RETRY_COUNT[$server]:-0}"
            local error="${SERVER_ERRORS[$server]:-}"
            
            echo "$server : $status (${deploy_time}ms, $retry_count retries)"
            [[ -n "$error" ]] && echo "  Erreur : $error"
        done
        echo
        echo "=== PERFORMANCE ==="
        echo "Validation : ${PRE_VALIDATION_TIME}ms"
        echo "Déploiement : ${DEPLOYMENT_EXECUTION_TIME}ms"
        echo "Vérification : ${POST_VERIFICATION_TIME}ms"
        echo "Total : ${TOTAL_EXECUTION_TIME}ms"
    } > "$report_file"
    
    log_info "Rapport de déploiement généré : $report_file"
}

# === GÉNÉRATION DU RÉSULTAT JSON ===
generate_json_result() {
    local status="$1"
    local message="$2"
    
    # Construire les résultats par serveur
    local server_results_json="{"
    local first_server=true
    
    for server in "${TARGET_SERVERS[@]}"; do
        if [[ "$first_server" == true ]]; then
            first_server=false
        else
            server_results_json+=","
        fi
        
        local server_status="${SERVER_STATUS[$server]:-unknown}"
        local deploy_time="${SERVER_DEPLOYMENT_TIME[$server]:-0}"
        local retry_count="${SERVER_RETRY_COUNT[$server]:-0}"
        local server_error="${SERVER_ERRORS[$server]:-}"
        local backup_path="${SERVER_BACKUP_PATHS[$server]:-}"
        local server_group="${SERVER_GROUPS_MAP[$server]:-default}"
        
        server_results_json+="\"$server\": {"
        server_results_json+="\"status\": \"$server_status\""
        server_results_json+=",\"deployment_time_ms\": $deploy_time"
        server_results_json+=",\"retry_count\": $retry_count"
        server_results_json+=",\"group\": \"$server_group\""
        
        if [[ -n "$server_error" ]]; then
            server_results_json+=",\"error\": \"$server_error\""
        fi
        
        if [[ -n "$backup_path" ]]; then
            server_results_json+=",\"backup_created\": true"
        else
            server_results_json+=",\"backup_created\": false"
        fi
        
        server_results_json+="}"
    done
    
    server_results_json+="}"
    
    # Construire les résultats par groupe
    local group_results_json="{"
    local first_group=true
    
    for group in "${SERVER_GROUPS[@]}"; do
        if [[ "$first_group" == true ]]; then
            first_group=false
        else
            group_results_json+=","
        fi
        
        local group_total=0
        local group_success=0
        local group_failed=0
        
        for server in "${TARGET_SERVERS[@]}"; do
            if [[ "${SERVER_GROUPS_MAP[$server]}" == "$group" ]]; then
                ((group_total++))
                case "${SERVER_STATUS[$server]}" in
                    success)
                        ((group_success++))
                        ;;
                    failed)
                        ((group_failed++))
                        ;;
                esac
            fi
        done
        
        group_results_json+="\"$group\": {"
        group_results_json+="\"total\": $group_total"
        group_results_json+=",\"success\": $group_success"
        group_results_json+=",\"failed\": $group_failed"
        group_results_json+="}"
    done
    
    group_results_json+="}"
    
    JSON_RESULT=$(cat << EOF
{
  "status": "$status",
  "data": {
    "deployment_summary": {
      "deployment_id": "$DEPLOYMENT_ID",
      "servers_total": $SERVERS_TOTAL,
      "servers_success": $SERVERS_SUCCESS,
      "servers_failed": $SERVERS_FAILED,
      "servers_skipped": $SERVERS_SKIPPED,
      "retries_performed": $RETRIES_PERFORMED,
      "rollbacks_executed": $ROLLBACKS_EXECUTED,
      "deployment_phases": $DEPLOYMENT_PHASES
    },
    "server_results": $server_results_json,
    "group_results": $group_results_json,
    "performance": {
      "pre_validation_ms": $PRE_VALIDATION_TIME,
      "deployment_ms": $DEPLOYMENT_EXECUTION_TIME,
      "post_verification_ms": $POST_VERIFICATION_TIME,
      "total_ms": $TOTAL_EXECUTION_TIME
    }
  },
  "message": "$message"
}
EOF
    )
}

# === FONCTION PRINCIPALE ===
do_main_action() {
    DEPLOYMENT_START_TIME=$(date +%s.%N)
    
    # Préparation du déploiement
    prepare_deployment
    
    # Exécution séquentielle des étapes
    if ! pre_deployment_validation; then
        return $?
    fi
    
    if ! execute_deployment; then
        return $?
    fi
    
    if ! post_deployment_verification; then
        return $?
    fi
    
    log_info "Déploiement multi-serveurs terminé avec succès"
    return 0
}

# === POINT D'ENTRÉE PRINCIPAL ===
main() {
    # Configuration du trap pour le nettoyage
    trap cleanup EXIT ERR INT TERM
    
    # Parsing des arguments
    parse_args "$@"
    
    # Validation des paramètres
    if ! validate_parameters; then
        log_error "Paramètres invalides"
        return 1
    fi
    
    # Validation des prérequis
    if ! validate_prerequisites; then
        log_error "Prérequis non satisfaits"
        return 1
    fi
    
    # Exécution de l'action principale
    local exit_code=0
    local result_message="Déploiement multi-serveurs réussi"
    
    if do_main_action; then
        exit_code=0
        if [[ "$SERVERS_SUCCESS" -eq "$SERVERS_TOTAL" ]]; then
            result_message="Déploiement réussi sur tous les $SERVERS_TOTAL serveurs"
        else
            result_message="Déploiement partiellement réussi : $SERVERS_SUCCESS/$SERVERS_TOTAL serveurs"
        fi
    else
        local action_exit_code=$?
        case $action_exit_code in
            2)
                result_message="Échec de validation pré-déploiement"
                exit_code=2
                ;;
            3)
                result_message="Déploiement partiellement réussi : $SERVERS_SUCCESS/$SERVERS_TOTAL serveurs"
                exit_code=3
                ;;
            4)
                result_message="Échec total de déploiement"
                exit_code=4
                ;;
            5)
                result_message="Échec de vérification post-déploiement"
                exit_code=5
                ;;
            *)
                result_message="Erreur générale de déploiement multi-serveurs"
                exit_code=6
                ;;
        esac
    fi
    
    # Calcul du temps total
    local deployment_final=$(date +%s.%N)
    TOTAL_EXECUTION_TIME=$(echo "($deployment_final - $DEPLOYMENT_START_TIME) * 1000" | bc -l 2>/dev/null | cut -d. -f1)
    
    # Génération du résultat JSON
    local json_status="success"
    if [[ $exit_code -ne 0 ]]; then
        json_status="error"
        if [[ "$SERVERS_SUCCESS" -gt 0 && "$SERVERS_SUCCESS" -lt "$SERVERS_TOTAL" ]]; then
            json_status="partial"
        fi
    fi
    generate_json_result "$json_status" "$result_message"
    
    # Sortie du résultat
    if [[ "$JSON_ONLY" == true ]]; then
        echo "$JSON_RESULT"
    else
        log_info "Résultat JSON : $JSON_RESULT"
    fi
    
    return $exit_code
}

# Exécution si script appelé directement
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi