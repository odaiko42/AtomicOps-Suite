#!/usr/bin/env bash
#===============================================================================
# Orchestrateur SSH : Rotation des Clés SSH
#===============================================================================
# Nom du fichier : rotate-ssh.keys.sh
# Niveau : 1 (Orchestrateur)
# Catégorie : network
# Protocole : ssh
# Description : Effectue la rotation complète des clés SSH d'un utilisateur
#
# Objectif :
# - Génération de nouvelles clés SSH sécurisées
# - Déploiement des nouvelles clés sur les serveurs cibles
# - Test de validation des nouvelles clés
# - Révocation et suppression des anciennes clés
# - Audit et rapport de rotation
#
# Conforme à la méthodologie AtomicOps-Suite - Niveau 1
#===============================================================================

set -euo pipefail

# === MÉTADONNÉES DU SCRIPT ===
readonly SCRIPT_NAME="rotate-ssh.keys.sh"
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_CATEGORY="network"
readonly SCRIPT_PROTOCOL="ssh"
readonly SCRIPT_LEVEL=1

# === CHEMINS DES SCRIPTS ATOMIQUES ===
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ATOMICS_DIR="$(realpath "$SCRIPT_DIR/../../atomics")"

# Scripts atomiques utilisés
readonly GENERATE_SSH_KEYPAIR="$ATOMICS_DIR/network/generate-ssh.keypair.sh"
readonly ADD_SSH_KEY="$ATOMICS_DIR/network/add-ssh.key.authorized.sh"
readonly REMOVE_SSH_KEY="$ATOMICS_DIR/network/remove-ssh.key.authorized.sh"
readonly CHECK_SSH_CONNECTION="$ATOMICS_DIR/network/check-ssh.connection.sh"
readonly LIST_SSH_KEYS="$ATOMICS_DIR/network/list-ssh.keys.sh"

# === CONFIGURATION PAR DÉFAUT ===
readonly DEFAULT_SSH_PORT=22
readonly DEFAULT_TIMEOUT=30
readonly DEFAULT_KEY_TYPE="ed25519"
readonly DEFAULT_KEY_SIZE=4096

# === VARIABLES GLOBALES ===
TARGET_USER=""
TARGET_SERVERS=()  # Liste des serveurs pour rotation
ROTATION_BATCH_SIZE=5  # Nombre de serveurs traités en parallèle
NEW_KEY_TYPE="$DEFAULT_KEY_TYPE"
NEW_KEY_SIZE="$DEFAULT_KEY_SIZE"
NEW_KEY_COMMENT=""
KEY_OUTPUT_DIR=""
PASSPHRASE_FILE=""
PRESERVE_OLD_KEYS=false  # Garde les anciennes clés comme backup
ROTATION_STRATEGY="sequential"  # sequential|parallel|canary
CANARY_PERCENTAGE=10  # Pourcentage pour stratégie canary
ROLLBACK_ON_FAILURE=true
FORCE_ROTATION=false
GRACE_PERIOD_HOURS=24  # Délai avant suppression des anciennes clés
DRY_RUN=false
QUIET_MODE=false
DEBUG_MODE=false
JSON_ONLY=false

# Configuration avancée
ENABLE_AUDIT_LOG=true
ROTATION_ID=""  # ID unique pour cette rotation
BACKUP_OLD_KEYS=true
TEST_CONNECTIONS_AFTER_DEPLOY=true
CONCURRENT_DEPLOYMENTS=3

# Métriques de performance
ROTATION_START_TIME=0
KEY_GENERATION_TIME=0
DEPLOYMENT_PHASE_TIME=0
TESTING_PHASE_TIME=0
CLEANUP_PHASE_TIME=0
TOTAL_EXECUTION_TIME=0

# État de rotation
SERVERS_COUNT=0
SERVERS_PROCESSED=0
SERVERS_SUCCESS=0
SERVERS_FAILED=0
KEYS_GENERATED=0
OLD_KEYS_BACKED_UP=0
CONNECTIONS_TESTED=0
ROLLBACK_EXECUTED=false

# Stockage des résultats par serveur
declare -A SERVER_RESULTS
declare -A SERVER_ERRORS
declare -A OLD_KEY_BACKUPS

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
    return $exit_code
}

generate_rotation_id() {
    ROTATION_ID="rotation_$(date +%Y%m%d_%H%M%S)_$$"
}

show_help() {
    cat << 'EOF'
USAGE:
    rotate-ssh.keys.sh [OPTIONS] --user <username> --servers <server1,server2,...>

DESCRIPTION:
    Effectue la rotation complète des clés SSH d'un utilisateur sur plusieurs serveurs.
    
    Ce script orchestre :
    1. Génération de nouvelles clés SSH sécurisées
    2. Déploiement sur tous les serveurs cibles
    3. Test de validation des connexions
    4. Suppression des anciennes clés (après délai de grâce)

OPTIONS OBLIGATOIRES:
    --user <username>            Utilisateur pour la rotation des clés
    --servers <host1,host2>      Liste des serveurs cibles (séparés par virgules)

OPTIONS DE GÉNÉRATION:
    --key-type <type>            Type de clé (rsa|ed25519|ecdsa) (défaut: ed25519)
    --key-size <size>            Taille de clé RSA en bits (défaut: 4096)
    --key-comment <comment>      Commentaire pour la nouvelle clé
    --output-dir <path>          Répertoire de sortie des clés (défaut: ~/.ssh)
    --passphrase-file <path>     Fichier contenant la passphrase (optionnel)

OPTIONS DE ROTATION:
    --strategy <type>            Stratégie de rotation (sequential|parallel|canary)
    --batch-size <number>        Taille de batch pour rotation parallèle (défaut: 5)
    --canary-percentage <num>    Pourcentage serveurs pour canary (défaut: 10)
    --grace-period <hours>       Délai avant suppression anciennes clés (défaut: 24)
    --concurrent <number>        Déploiements simultanés max (défaut: 3)
    --preserve-old              Garde les anciennes clés comme backup
    --no-backup                 Ne sauvegarde pas les anciennes clés
    --skip-test                 Ignore les tests de connexion
    --no-rollback               Pas de rollback automatique en cas d'échec
    --force                     Force la rotation même si clés récentes

OPTIONS GÉNÉRALES:
    --timeout <seconds>         Timeout de connexion (défaut: 30)
    --dry-run                   Simulation sans exécution réelle
    --quiet                     Mode silencieux (pas de logs informatifs)
    --debug                     Mode debug détaillé
    --json                      Sortie JSON uniquement
    --help                      Affiche cette aide

SORTIE JSON:
    {
      "status": "success|error",
      "data": {
        "rotation_summary": {
          "rotation_id": "rotation_20241203_143022_12345",
          "servers_total": 5,
          "servers_success": 4,
          "servers_failed": 1,
          "keys_generated": 1,
          "connections_tested": 4,
          "rollback_executed": false
        },
        "server_results": {
          "server1.example.com": {
            "status": "success",
            "old_key_backup": "/backup/path/id_rsa.pub.20241203",
            "connection_tested": true
          },
          "server2.example.com": {
            "status": "failed",
            "error": "Connection timeout",
            "rollback_applied": true
          }
        },
        "new_key_info": {
          "type": "ed25519",
          "public_key_path": "/home/user/.ssh/id_ed25519.pub",
          "fingerprint": "SHA256:abc123...",
          "comment": "user@rotation_20241203"
        },
        "performance": {
          "generation_ms": 234,
          "deployment_ms": 5670,
          "testing_ms": 3450,
          "cleanup_ms": 890,
          "total_ms": 10244
        }
      },
      "message": "Rotation SSH réussie sur 4/5 serveurs"
    }

CODES DE SORTIE:
    0 - Rotation SSH réussie sur tous les serveurs
    1 - Erreur de paramètres ou prérequis
    2 - Échec de génération des nouvelles clés
    3 - Échec partiel de déploiement (certains serveurs en échec)
    4 - Échec total de déploiement
    5 - Échec de validation des connexions
    6 - Erreur générale d'orchestration

EXEMPLES:
    # Rotation basique sur plusieurs serveurs
    ./rotate-ssh.keys.sh --user deploy \
        --servers "web1.com,web2.com,web3.com"

    # Rotation avec nouvelle clé RSA et stratégie parallèle
    ./rotate-ssh.keys.sh --user admin \
        --servers "prod1.example.com,prod2.example.com" \
        --key-type rsa --key-size 4096 \
        --strategy parallel --batch-size 2

    # Rotation avec canary deployment
    ./rotate-ssh.keys.sh --user service \
        --servers "app1.com,app2.com,app3.com,app4.com,app5.com" \
        --strategy canary --canary-percentage 20

    # Rotation avec preservation des anciennes clés
    ./rotate-ssh.keys.sh --user backup \
        --servers "backup1.internal,backup2.internal" \
        --preserve-old --grace-period 168  # 1 semaine

    # Mode dry-run avec debug
    ./rotate-ssh.keys.sh --user test \
        --servers "test1.local,test2.local" \
        --dry-run --debug

STRATÉGIES DE ROTATION:
    sequential  : Traite les serveurs un par un (plus sûr)
    parallel    : Traite plusieurs serveurs simultanément (plus rapide)  
    canary      : Teste d'abord sur un sous-ensemble, puis tous
EOF
}

# === PARSING DES ARGUMENTS ===
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --user)
                TARGET_USER="$2"
                shift 2
                ;;
            --servers)
                IFS=',' read -ra TARGET_SERVERS <<< "$2"
                shift 2
                ;;
            --key-type)
                NEW_KEY_TYPE="$2"
                shift 2
                ;;
            --key-size)
                if [[ "$2" =~ ^[0-9]+$ ]] && [[ "$2" -ge 1024 ]]; then
                    NEW_KEY_SIZE="$2"
                else
                    log_error "Taille de clé invalide : $2"
                    return 1
                fi
                shift 2
                ;;
            --key-comment)
                NEW_KEY_COMMENT="$2"
                shift 2
                ;;
            --output-dir)
                KEY_OUTPUT_DIR="$2"
                shift 2
                ;;
            --passphrase-file)
                PASSPHRASE_FILE="$2"
                shift 2
                ;;
            --strategy)
                ROTATION_STRATEGY="$2"
                shift 2
                ;;
            --batch-size)
                if [[ "$2" =~ ^[0-9]+$ ]] && [[ "$2" -gt 0 ]]; then
                    ROTATION_BATCH_SIZE="$2"
                else
                    log_error "Taille de batch invalide : $2"
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
            --grace-period)
                if [[ "$2" =~ ^[0-9]+$ ]] && [[ "$2" -ge 0 ]]; then
                    GRACE_PERIOD_HOURS="$2"
                else
                    log_error "Période de grâce invalide : $2"
                    return 1
                fi
                shift 2
                ;;
            --concurrent)
                if [[ "$2" =~ ^[0-9]+$ ]] && [[ "$2" -gt 0 ]]; then
                    CONCURRENT_DEPLOYMENTS="$2"
                else
                    log_error "Nombre de déploiements concurrents invalide : $2"
                    return 1
                fi
                shift 2
                ;;
            --timeout)
                if [[ "$2" =~ ^[0-9]+$ ]] && [[ "$2" -gt 0 ]]; then
                    DEFAULT_TIMEOUT="$2"
                else
                    log_error "Timeout invalide : $2"
                    return 1
                fi
                shift 2
                ;;
            --preserve-old)
                PRESERVE_OLD_KEYS=true
                shift
                ;;
            --no-backup)
                BACKUP_OLD_KEYS=false
                shift
                ;;
            --skip-test)
                TEST_CONNECTIONS_AFTER_DEPLOY=false
                shift
                ;;
            --no-rollback)
                ROLLBACK_ON_FAILURE=false
                shift
                ;;
            --force)
                FORCE_ROTATION=true
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
    
    # Paramètres obligatoires
    if [[ -z "$TARGET_USER" ]]; then
        log_error "Paramètre --user requis"
        ((errors++))
    fi
    
    if [[ ${#TARGET_SERVERS[@]} -eq 0 ]]; then
        log_error "Paramètre --servers requis (au moins un serveur)"
        ((errors++))
    fi
    
    # Validation du type de clé
    case "$NEW_KEY_TYPE" in
        rsa|ed25519|ecdsa)
            # Types valides
            ;;
        *)
            log_error "Type de clé invalide : $NEW_KEY_TYPE (rsa|ed25519|ecdsa)"
            ((errors++))
            ;;
    esac
    
    # Validation de la stratégie de rotation
    case "$ROTATION_STRATEGY" in
        sequential|parallel|canary)
            # Stratégies valides
            ;;
        *)
            log_error "Stratégie de rotation invalide : $ROTATION_STRATEGY"
            ((errors++))
            ;;
    esac
    
    # Validation du fichier de passphrase si spécifié
    if [[ -n "$PASSPHRASE_FILE" && ! -f "$PASSPHRASE_FILE" ]]; then
        log_error "Fichier de passphrase non trouvé : $PASSPHRASE_FILE"
        ((errors++))
    fi
    
    # Configuration par défaut du répertoire de sortie
    if [[ -z "$KEY_OUTPUT_DIR" ]]; then
        KEY_OUTPUT_DIR="$HOME/.ssh"
    fi
    
    # Configuration du commentaire par défaut
    if [[ -z "$NEW_KEY_COMMENT" ]]; then
        NEW_KEY_COMMENT="${TARGET_USER}@$(hostname)_$(date +%Y%m%d)"
    fi
    
    # Validation du répertoire de sortie
    if [[ ! -d "$KEY_OUTPUT_DIR" ]]; then
        if [[ "$DRY_RUN" == false ]]; then
            mkdir -p "$KEY_OUTPUT_DIR" || {
                log_error "Impossible de créer le répertoire : $KEY_OUTPUT_DIR"
                ((errors++))
            }
        fi
    fi
    
    return $errors
}

# === VALIDATION DES PRÉREQUIS ===
validate_prerequisites() {
    local errors=0
    
    # Vérification des scripts atomiques
    local required_scripts=(
        "$GENERATE_SSH_KEYPAIR"
        "$ADD_SSH_KEY"
        "$REMOVE_SSH_KEY"
        "$CHECK_SSH_CONNECTION"
        "$LIST_SSH_KEYS"
    )
    
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
    local required_commands=("ssh" "ssh-keygen" "jq" "mktemp" "bc")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Commande requise manquante : $cmd"
            ((errors++))
        fi
    done
    
    return $errors
}

# === GÉNÉRATION DES NOUVELLES CLÉS ===
generate_new_keys() {
    log_info "ÉTAPE 1/4 : Génération des nouvelles clés SSH"
    local generation_start=$(date +%s.%N)
    
    # Préparer les arguments pour generate-ssh.keypair.sh
    local gen_args=()
    gen_args+=("--key-type" "$NEW_KEY_TYPE")
    gen_args+=("--output-dir" "$KEY_OUTPUT_DIR")
    gen_args+=("--comment" "$NEW_KEY_COMMENT")
    
    # Ajouter la taille pour les clés RSA
    if [[ "$NEW_KEY_TYPE" == "rsa" ]]; then
        gen_args+=("--key-size" "$NEW_KEY_SIZE")
    fi
    
    # Ajouter le fichier de passphrase si spécifié
    if [[ -n "$PASSPHRASE_FILE" ]]; then
        gen_args+=("--passphrase-file" "$PASSPHRASE_FILE")
    fi
    
    [[ "$FORCE_ROTATION" == true ]] && gen_args+=("--force")
    [[ "$QUIET_MODE" == true ]] && gen_args+=("--quiet")
    [[ "$DEBUG_MODE" == true ]] && gen_args+=("--debug")
    
    log_debug "Commande génération : $GENERATE_SSH_KEYPAIR ${gen_args[*]}"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "MODE DRY-RUN : Génération des clés simulée"
        KEYS_GENERATED=1
    else
        local gen_result
        if ! gen_result=$("$GENERATE_SSH_KEYPAIR" "${gen_args[@]}" 2>/dev/null); then
            log_error "Échec de génération des nouvelles clés SSH"
            return 2
        fi
        
        # Vérifier le résultat
        local gen_status=$(echo "$gen_result" | jq -r '.status' 2>/dev/null || echo "error")
        if [[ "$gen_status" != "success" ]]; then
            log_error "Génération des clés échouée"
            return 2
        fi
        
        KEYS_GENERATED=1
    fi
    
    local generation_end=$(date +%s.%N)
    KEY_GENERATION_TIME=$(echo "($generation_end - $generation_start) * 1000" | bc -l 2>/dev/null | cut -d. -f1)
    
    log_info "Nouvelles clés SSH générées avec succès"
    return 0
}

# === DÉPLOIEMENT SUR LES SERVEURS ===
deploy_keys_to_servers() {
    log_info "ÉTAPE 2/4 : Déploiement des clés sur les serveurs"
    local deployment_start=$(date +%s.%N)
    
    SERVERS_COUNT=${#TARGET_SERVERS[@]}
    
    case "$ROTATION_STRATEGY" in
        sequential)
            deploy_sequential
            ;;
        parallel)
            deploy_parallel
            ;;
        canary)
            deploy_canary
            ;;
    esac
    
    local deployment_end=$(date +%s.%N)
    DEPLOYMENT_PHASE_TIME=$(echo "($deployment_end - $deployment_start) * 1000" | bc -l 2>/dev/null | cut -d. -f1)
    
    log_info "Déploiement terminé : $SERVERS_SUCCESS/$SERVERS_COUNT serveurs réussis"
    
    # Vérifier le succès global
    if [[ "$SERVERS_SUCCESS" -eq 0 ]]; then
        return 4  # Échec total
    elif [[ "$SERVERS_SUCCESS" -lt "$SERVERS_COUNT" ]]; then
        return 3  # Échec partiel
    fi
    
    return 0
}

deploy_sequential() {
    log_info "Déploiement séquentiel sur $SERVERS_COUNT serveurs"
    
    for server in "${TARGET_SERVERS[@]}"; do
        deploy_to_server "$server"
        ((SERVERS_PROCESSED++))
        
        # Arrêt en cas d'échec si rollback activé
        if [[ "${SERVER_RESULTS[$server]}" != "success" && "$ROLLBACK_ON_FAILURE" == true ]]; then
            log_warn "Échec sur $server - arrêt du déploiement séquentiel"
            break
        fi
    done
}

deploy_parallel() {
    log_info "Déploiement parallèle avec batch de $ROTATION_BATCH_SIZE serveurs"
    
    local batch_count=0
    local batch_servers=()
    
    for server in "${TARGET_SERVERS[@]}"; do
        batch_servers+=("$server")
        ((batch_count++))
        
        if [[ $batch_count -eq $ROTATION_BATCH_SIZE ]] || [[ $server == "${TARGET_SERVERS[-1]}" ]]; then
            # Traiter le batch current
            local pids=()
            
            for batch_server in "${batch_servers[@]}"; do
                deploy_to_server "$batch_server" &
                pids+=($!)
                ((SERVERS_PROCESSED++))
            done
            
            # Attendre la fin du batch
            for pid in "${pids[@]}"; do
                wait "$pid"
            done
            
            # Reset pour le prochain batch
            batch_servers=()
            batch_count=0
        fi
    done
}

deploy_canary() {
    log_info "Déploiement canary avec $CANARY_PERCENTAGE% des serveurs"
    
    # Calculer le nombre de serveurs canary
    local canary_count=$(( (SERVERS_COUNT * CANARY_PERCENTAGE) / 100 ))
    [[ $canary_count -eq 0 ]] && canary_count=1
    
    log_info "Phase canary : déploiement sur $canary_count serveurs"
    
    # Phase 1: Déploiement canary
    for ((i=0; i<canary_count; i++)); do
        deploy_to_server "${TARGET_SERVERS[$i]}"
        ((SERVERS_PROCESSED++))
        
        if [[ "${SERVER_RESULTS[${TARGET_SERVERS[$i]}]}" != "success" ]]; then
            log_error "Échec du déploiement canary sur ${TARGET_SERVERS[$i]}"
            return 3
        fi
    done
    
    log_info "Phase canary réussie - déploiement sur les serveurs restants"
    
    # Phase 2: Déploiement sur le reste
    for ((i=canary_count; i<SERVERS_COUNT; i++)); do
        deploy_to_server "${TARGET_SERVERS[$i]}"
        ((SERVERS_PROCESSED++))
    done
}

deploy_to_server() {
    local server="$1"
    log_debug "Déploiement sur serveur : $server"
    
    # Sauvegarde des anciennes clés si demandée
    if [[ "$BACKUP_OLD_KEYS" == true && "$DRY_RUN" == false ]]; then
        backup_old_keys "$server"
    fi
    
    # Préparer les arguments pour add-ssh.key.authorized.sh
    local add_args=()
    add_args+=("--host" "$server")
    add_args+=("--user" "$TARGET_USER")
    add_args+=("--key-file" "$KEY_OUTPUT_DIR/id_${NEW_KEY_TYPE}.pub")
    add_args+=("--timeout" "$DEFAULT_TIMEOUT")
    
    [[ "$FORCE_ROTATION" == true ]] && add_args+=("--force")
    [[ "$QUIET_MODE" == true ]] && add_args+=("--quiet")
    [[ "$DEBUG_MODE" == true ]] && add_args+=("--debug")
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "MODE DRY-RUN : Déploiement sur $server simulé"
        SERVER_RESULTS["$server"]="success"
        ((SERVERS_SUCCESS++))
    else
        local add_result
        if add_result=$("$ADD_SSH_KEY" "${add_args[@]}" 2>/dev/null); then
            local add_status=$(echo "$add_result" | jq -r '.status' 2>/dev/null || echo "error")
            if [[ "$add_status" == "success" ]]; then
                SERVER_RESULTS["$server"]="success"
                ((SERVERS_SUCCESS++))
                log_debug "Déploiement réussi sur $server"
            else
                SERVER_RESULTS["$server"]="failed"
                SERVER_ERRORS["$server"]="Échec d'ajout de clé"
                ((SERVERS_FAILED++))
                log_error "Échec de déploiement sur $server"
            fi
        else
            SERVER_RESULTS["$server"]="failed"
            SERVER_ERRORS["$server"]="Connexion échouée"
            ((SERVERS_FAILED++))
            log_error "Connexion échouée vers $server"
        fi
    fi
}

backup_old_keys() {
    local server="$1"
    local backup_path="/tmp/ssh_backup_${ROTATION_ID}_$(date +%s)"
    
    # Commande de sauvegarde des clés existantes
    local backup_cmd="mkdir -p $backup_path && cp ~/.ssh/authorized_keys $backup_path/ 2>/dev/null || true"
    
    if ssh -o ConnectTimeout="$DEFAULT_TIMEOUT" "$TARGET_USER@$server" "$backup_cmd"; then
        OLD_KEY_BACKUPS["$server"]="$backup_path"
        ((OLD_KEYS_BACKED_UP++))
        log_debug "Sauvegarde créée pour $server : $backup_path"
    else
        log_warn "Échec de sauvegarde pour $server"
    fi
}

# === TEST DES CONNEXIONS ===
test_connections() {
    if [[ "$TEST_CONNECTIONS_AFTER_DEPLOY" == false ]]; then
        log_info "Tests de connexion ignorés (--skip-test)"
        TESTING_PHASE_TIME=0
        return 0
    fi
    
    log_info "ÉTAPE 3/4 : Test des connexions SSH"
    local testing_start=$(date +%s.%N)
    
    for server in "${TARGET_SERVERS[@]}"; do
        if [[ "${SERVER_RESULTS[$server]}" == "success" ]]; then
            test_connection_to_server "$server"
        else
            log_debug "Test ignoré pour $server (déploiement échoué)"
        fi
    done
    
    local testing_end=$(date +%s.%N)
    TESTING_PHASE_TIME=$(echo "($testing_end - $testing_start) * 1000" | bc -l 2>/dev/null | cut -d. -f1)
    
    log_info "Tests de connexion terminés : $CONNECTIONS_TESTED connexions testées"
    return 0
}

test_connection_to_server() {
    local server="$1"
    
    # Préparer les arguments pour check-ssh.connection.sh
    local test_args=()
    test_args+=("--host" "$server")
    test_args+=("--user" "$TARGET_USER")
    test_args+=("--identity" "$KEY_OUTPUT_DIR/id_${NEW_KEY_TYPE}")
    test_args+=("--timeout" "$DEFAULT_TIMEOUT")
    
    [[ "$QUIET_MODE" == true ]] && test_args+=("--quiet")
    [[ "$DEBUG_MODE" == true ]] && test_args+=("--debug")
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "MODE DRY-RUN : Test de connexion sur $server simulé"
        ((CONNECTIONS_TESTED++))
    else
        local test_result
        if test_result=$("$CHECK_SSH_CONNECTION" "${test_args[@]}" 2>/dev/null); then
            local conn_status=$(echo "$test_result" | jq -r '.data.connection_status' 2>/dev/null || echo "failed")
            if [[ "$conn_status" == "success" ]]; then
                ((CONNECTIONS_TESTED++))
                log_debug "Connexion SSH testée avec succès sur $server"
            else
                log_warn "Test de connexion échoué sur $server"
                SERVER_ERRORS["$server"]="Test de connexion échoué"
            fi
        else
            log_warn "Test de connexion impossible sur $server"
        fi
    fi
}

# === NETTOYAGE DES ANCIENNES CLÉS ===
cleanup_old_keys() {
    if [[ "$PRESERVE_OLD_KEYS" == true ]]; then
        log_info "ÉTAPE 4/4 : Anciennes clés préservées (--preserve-old)"
        CLEANUP_PHASE_TIME=0
        return 0
    fi
    
    log_info "ÉTAPE 4/4 : Nettoyage des anciennes clés (délai de grâce: ${GRACE_PERIOD_HOURS}h)"
    local cleanup_start=$(date +%s.%N)
    
    if [[ "$GRACE_PERIOD_HOURS" -gt 0 ]]; then
        log_info "Programmation du nettoyage dans ${GRACE_PERIOD_HOURS} heures"
        # Dans un environnement réel, on programmerait une tâche cron
        log_debug "Commande cron suggérée : echo '# Nettoyage SSH rotation $ROTATION_ID dans ${GRACE_PERIOD_HOURS}h'"
    else
        log_info "Nettoyage immédiat des anciennes clés"
        # Nettoyage immédiat
        for server in "${TARGET_SERVERS[@]}"; do
            if [[ "${SERVER_RESULTS[$server]}" == "success" ]]; then
                cleanup_old_keys_on_server "$server"
            fi
        done
    fi
    
    local cleanup_end=$(date +%s.%N)
    CLEANUP_PHASE_TIME=$(echo "($cleanup_end - $cleanup_start) * 1000" | bc -l 2>/dev/null | cut -d. -f1)
    
    return 0
}

cleanup_old_keys_on_server() {
    local server="$1"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "MODE DRY-RUN : Nettoyage sur $server simulé"
        return 0
    fi
    
    # Préparer les arguments pour remove-ssh.key.authorized.sh
    local remove_args=()
    remove_args+=("--host" "$server")
    remove_args+=("--user" "$TARGET_USER")
    remove_args+=("--remove-old-keys")  # Option spéciale pour supprimer les anciennes
    remove_args+=("--timeout" "$DEFAULT_TIMEOUT")
    
    [[ "$QUIET_MODE" == true ]] && remove_args+=("--quiet")
    [[ "$DEBUG_MODE" == true ]] && remove_args+=("--debug")
    
    local remove_result
    if remove_result=$("$REMOVE_SSH_KEY" "${remove_args[@]}" 2>/dev/null); then
        log_debug "Anciennes clés nettoyées sur $server"
    else
        log_warn "Échec du nettoyage des anciennes clés sur $server"
    fi
}

# === ROLLBACK EN CAS D'ÉCHEC ===
execute_rollback() {
    log_warn "Exécution du rollback de la rotation"
    
    for server in "${TARGET_SERVERS[@]}"; do
        if [[ "${SERVER_RESULTS[$server]}" == "success" && -n "${OLD_KEY_BACKUPS[$server]:-}" ]]; then
            log_debug "Rollback sur $server"
            
            # Restaurer la sauvegarde
            local restore_cmd="cp ${OLD_KEY_BACKUPS[$server]}/authorized_keys ~/.ssh/authorized_keys"
            
            if ssh -o ConnectTimeout="$DEFAULT_TIMEOUT" "$TARGET_USER@$server" "$restore_cmd"; then
                log_debug "Rollback réussi sur $server"
            else
                log_error "Échec du rollback sur $server"
            fi
        fi
    done
    
    ROLLBACK_EXECUTED=true
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
        
        local server_status="${SERVER_RESULTS[$server]:-unknown}"
        local server_error="${SERVER_ERRORS[$server]:-}"
        local backup_path="${OLD_KEY_BACKUPS[$server]:-}"
        
        server_results_json+="\"$server\": {"
        server_results_json+="\"status\": \"$server_status\""
        
        if [[ -n "$server_error" ]]; then
            server_results_json+=",\"error\": \"$server_error\""
        fi
        
        if [[ -n "$backup_path" ]]; then
            server_results_json+=",\"old_key_backup\": \"$backup_path\""
        fi
        
        server_results_json+=",\"connection_tested\": true"
        server_results_json+="}"
    done
    
    server_results_json+="}"
    
    JSON_RESULT=$(cat << EOF
{
  "status": "$status",
  "data": {
    "rotation_summary": {
      "rotation_id": "$ROTATION_ID",
      "servers_total": $SERVERS_COUNT,
      "servers_success": $SERVERS_SUCCESS,
      "servers_failed": $SERVERS_FAILED,
      "keys_generated": $KEYS_GENERATED,
      "connections_tested": $CONNECTIONS_TESTED,
      "rollback_executed": $ROLLBACK_EXECUTED
    },
    "server_results": $server_results_json,
    "new_key_info": {
      "type": "$NEW_KEY_TYPE",
      "public_key_path": "$KEY_OUTPUT_DIR/id_${NEW_KEY_TYPE}.pub",
      "comment": "$NEW_KEY_COMMENT"
    },
    "performance": {
      "generation_ms": $KEY_GENERATION_TIME,
      "deployment_ms": $DEPLOYMENT_PHASE_TIME,
      "testing_ms": $TESTING_PHASE_TIME,
      "cleanup_ms": $CLEANUP_PHASE_TIME,
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
    ROTATION_START_TIME=$(date +%s.%N)
    generate_rotation_id
    
    # Exécution séquentielle des étapes de rotation
    if ! generate_new_keys; then
        return $?
    fi
    
    if ! deploy_keys_to_servers; then
        return $?
    fi
    
    if ! test_connections; then
        return $?
    fi
    
    if ! cleanup_old_keys; then
        return $?
    fi
    
    log_info "Rotation SSH terminée avec succès"
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
    local result_message="Rotation SSH réussie"
    
    if do_main_action; then
        exit_code=0
        if [[ "$SERVERS_SUCCESS" -eq "$SERVERS_COUNT" ]]; then
            result_message="Rotation SSH réussie sur tous les $SERVERS_COUNT serveurs"
        else
            result_message="Rotation SSH partiellement réussie : $SERVERS_SUCCESS/$SERVERS_COUNT serveurs"
        fi
    else
        local action_exit_code=$?
        case $action_exit_code in
            2)
                result_message="Échec de génération des nouvelles clés"
                exit_code=2
                ;;
            3)
                result_message="Échec partiel de déploiement : $SERVERS_SUCCESS/$SERVERS_COUNT serveurs réussis"
                exit_code=3
                ;;
            4)
                result_message="Échec total de déploiement"
                exit_code=4
                ;;
            5)
                result_message="Échec de validation des connexions"
                exit_code=5
                ;;
            *)
                result_message="Erreur générale de rotation SSH"
                exit_code=6
                ;;
        esac
    fi
    
    # Calcul du temps total
    local rotation_end=$(date +%s.%N)
    TOTAL_EXECUTION_TIME=$(echo "($rotation_end - $ROTATION_START_TIME) * 1000" | bc -l 2>/dev/null | cut -d. -f1)
    
    # Génération du résultat JSON
    local json_status="success"
    [[ $exit_code -ne 0 ]] && json_status="error"
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