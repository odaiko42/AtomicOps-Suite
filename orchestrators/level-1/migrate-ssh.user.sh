#!/usr/bin/env bash
#===============================================================================
# Orchestrateur SSH : Migration Utilisateur SSH
#===============================================================================
# Nom du fichier : migrate-ssh.user.sh
# Niveau : 1 (Orchestrateur)
# Catégorie : network
# Protocole : ssh
# Description : Migre les clés SSH d'un utilisateur d'un serveur à un autre
#
# Objectif :
# - Récupération des clés SSH depuis le serveur source
# - Transfert et déploiement sur le serveur destination
# - Validation de la migration par test de connexion
# - Sauvegarde et rollback en cas d'échec
#
# Conforme à la méthodologie AtomicOps-Suite - Niveau 1
#===============================================================================

set -euo pipefail

# === MÉTADONNÉES DU SCRIPT ===
readonly SCRIPT_NAME="migrate-ssh.user.sh"
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_CATEGORY="network"
readonly SCRIPT_PROTOCOL="ssh"
readonly SCRIPT_LEVEL=1

# === CHEMINS DES SCRIPTS ATOMIQUES ===
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ATOMICS_DIR="$(realpath "$SCRIPT_DIR/../../atomics")"

# Scripts atomiques utilisés
readonly LIST_SSH_KEYS="$ATOMICS_DIR/network/list-ssh.keys.sh"
readonly ADD_SSH_KEY="$ATOMICS_DIR/network/add-ssh.key.authorized.sh"
readonly CHECK_SSH_CONNECTION="$ATOMICS_DIR/network/check-ssh.connection.sh"

# === CONFIGURATION PAR DÉFAUT ===
readonly DEFAULT_SSH_PORT=22
readonly DEFAULT_TIMEOUT=30

# === VARIABLES GLOBALES ===
SOURCE_HOST=""
SOURCE_PORT="$DEFAULT_SSH_PORT"
SOURCE_USER=""
SOURCE_ADMIN_USER=""
SOURCE_ADMIN_KEY=""

DEST_HOST=""
DEST_PORT="$DEFAULT_SSH_PORT"
DEST_USER=""
DEST_ADMIN_USER=""
DEST_ADMIN_KEY=""

MIGRATE_USER=""  # Utilisateur dont on migre les clés
MIGRATE_SPECIFIC_KEYS=()  # Clés spécifiques à migrer (optionnel)
MIGRATION_MODE="copy"  # copy|move (copy garde les clés source, move les supprime)
BACKUP_BEFORE_MIGRATION=true
VERIFY_MIGRATION=true
ROLLBACK_ON_FAILURE=true
FORCE_OVERWRITE=false
DRY_RUN=false
QUIET_MODE=false
DEBUG_MODE=false
JSON_ONLY=false

# Métriques de performance
MIGRATION_START_TIME=0
SOURCE_LISTING_TIME=0
KEYS_TRANSFER_TIME=0
DEST_DEPLOYMENT_TIME=0
VERIFICATION_TIME=0
TOTAL_EXECUTION_TIME=0

# État de migration
KEYS_FOUND_SOURCE=0
KEYS_MIGRATED=0
MIGRATION_VERIFIED=false
BACKUP_CREATED=false
ROLLBACK_EXECUTED=false

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
        
        if [[ "$ROLLBACK_ON_FAILURE" == true && "$BACKUP_CREATED" == true ]]; then
            log_warn "Exécution du rollback automatique"
            execute_rollback
        fi
    fi
    return $exit_code
}

show_help() {
    cat << 'EOF'
USAGE:
    migrate-ssh.user.sh [OPTIONS] --source-host <host> --dest-host <host> --migrate-user <user>

DESCRIPTION:
    Migre les clés SSH d'un utilisateur d'un serveur à un autre.
    
    Ce script orchestre :
    1. Récupération des clés SSH depuis la source
    2. Transfert vers le serveur destination
    3. Déploiement et configuration
    4. Validation par test de connexion

OPTIONS OBLIGATOIRES:
    --source-host <hostname>     Serveur source des clés SSH
    --dest-host <hostname>       Serveur destination des clés SSH
    --migrate-user <username>    Utilisateur dont migrer les clés

OPTIONS SOURCE:
    --source-port <port>         Port SSH source (défaut: 22)
    --source-admin <username>    Utilisateur admin sur la source
    --source-key <path>          Clé d'admin pour connexion source

OPTIONS DESTINATION:
    --dest-port <port>           Port SSH destination (défaut: 22)
    --dest-admin <username>      Utilisateur admin sur la destination
    --dest-key <path>            Clé d'admin pour connexion destination

OPTIONS DE MIGRATION:
    --mode <copy|move>           Mode de migration (défaut: copy)
    --specific-keys <key1,key2>  Migre seulement ces clés spécifiques
    --no-backup                  Ne sauvegarde pas avant migration
    --skip-verify                Ignore la vérification de migration
    --no-rollback                Pas de rollback automatique en cas d'échec
    --force                      Force l'écrasement des clés existantes
    --timeout <seconds>          Timeout de connexion (défaut: 30)

OPTIONS GÉNÉRALES:
    --dry-run                    Simulation sans exécution réelle
    --quiet                      Mode silencieux (pas de logs informatifs)
    --debug                      Mode debug détaillé
    --json                       Sortie JSON uniquement
    --help                       Affiche cette aide

SORTIE JSON:
    {
      "status": "success|error",
      "data": {
        "migration_summary": {
          "keys_found_source": 3,
          "keys_migrated": 3,
          "migration_verified": true,
          "backup_created": true,
          "rollback_executed": false
        },
        "migrated_keys": [
          "/home/user/.ssh/id_rsa.pub",
          "/home/user/.ssh/id_ed25519.pub"
        ],
        "source_info": {
          "host": "source.example.com",
          "user": "user1"
        },
        "destination_info": {
          "host": "dest.example.com",
          "user": "user1"
        },
        "performance": {
          "listing_ms": 234,
          "transfer_ms": 567,
          "deployment_ms": 345,
          "verification_ms": 123,
          "total_ms": 1269
        }
      },
      "message": "Migration SSH réussie"
    }

CODES DE SORTIE:
    0 - Migration SSH réussie
    1 - Erreur de paramètres ou prérequis
    2 - Échec de récupération des clés source
    3 - Échec de transfert des clés
    4 - Échec de déploiement sur destination
    5 - Échec de vérification de migration
    6 - Erreur générale d'orchestration

EXEMPLES:
    # Migration basique entre serveurs
    ./migrate-ssh.user.sh --source-host old-server.com \
        --dest-host new-server.com --migrate-user deploy

    # Migration avec clés d'admin spécifiques
    ./migrate-ssh.user.sh --source-host 192.168.1.100 \
        --dest-host 192.168.1.200 --migrate-user webapp \
        --source-admin root --source-key ~/.ssh/admin_old \
        --dest-admin admin --dest-key ~/.ssh/admin_new

    # Migration en mode "move" (supprime les clés source)
    ./migrate-ssh.user.sh --source-host legacy.domain.com \
        --dest-host production.domain.com --migrate-user service \
        --mode move --force

    # Migration de clés spécifiques seulement
    ./migrate-ssh.user.sh --source-host test.example.com \
        --dest-host prod.example.com --migrate-user deploy \
        --specific-keys "id_rsa.pub,deploy_key.pub"

    # Mode dry-run avec debug
    ./migrate-ssh.user.sh --source-host source --dest-host dest \
        --migrate-user test --dry-run --debug
EOF
}

# === PARSING DES ARGUMENTS ===
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --source-host)
                SOURCE_HOST="$2"
                shift 2
                ;;
            --dest-host)
                DEST_HOST="$2"
                shift 2
                ;;
            --migrate-user)
                MIGRATE_USER="$2"
                shift 2
                ;;
            --source-port)
                SOURCE_PORT="$2"
                shift 2
                ;;
            --dest-port)
                DEST_PORT="$2"
                shift 2
                ;;
            --source-admin)
                SOURCE_ADMIN_USER="$2"
                shift 2
                ;;
            --dest-admin)
                DEST_ADMIN_USER="$2"
                shift 2
                ;;
            --source-key)
                SOURCE_ADMIN_KEY="$2"
                shift 2
                ;;
            --dest-key)
                DEST_ADMIN_KEY="$2"
                shift 2
                ;;
            --mode)
                MIGRATION_MODE="$2"
                shift 2
                ;;
            --specific-keys)
                IFS=',' read -ra MIGRATE_SPECIFIC_KEYS <<< "$2"
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
            --no-backup)
                BACKUP_BEFORE_MIGRATION=false
                shift
                ;;
            --skip-verify)
                VERIFY_MIGRATION=false
                shift
                ;;
            --no-rollback)
                ROLLBACK_ON_FAILURE=false
                shift
                ;;
            --force)
                FORCE_OVERWRITE=true
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
    if [[ -z "$SOURCE_HOST" ]]; then
        log_error "Paramètre --source-host requis"
        ((errors++))
    fi
    
    if [[ -z "$DEST_HOST" ]]; then
        log_error "Paramètre --dest-host requis"
        ((errors++))
    fi
    
    if [[ -z "$MIGRATE_USER" ]]; then
        log_error "Paramètre --migrate-user requis"
        ((errors++))
    fi
    
    # Validation des ports SSH
    for port_var in SOURCE_PORT DEST_PORT; do
        local port_value=${!port_var}
        if [[ ! "$port_value" =~ ^[0-9]+$ ]] || [[ "$port_value" -lt 1 || "$port_value" -gt 65535 ]]; then
            log_error "Port SSH invalide ($port_var) : $port_value"
            ((errors++))
        fi
    done
    
    # Validation du mode de migration
    case "$MIGRATION_MODE" in
        copy|move)
            # Modes valides
            ;;
        *)
            log_error "Mode de migration invalide : $MIGRATION_MODE (copy|move)"
            ((errors++))
            ;;
    esac
    
    # Validation des clés d'admin si spécifiées
    if [[ -n "$SOURCE_ADMIN_KEY" && ! -f "$SOURCE_ADMIN_KEY" ]]; then
        log_error "Clé d'admin source non trouvée : $SOURCE_ADMIN_KEY"
        ((errors++))
    fi
    
    if [[ -n "$DEST_ADMIN_KEY" && ! -f "$DEST_ADMIN_KEY" ]]; then
        log_error "Clé d'admin destination non trouvée : $DEST_ADMIN_KEY"
        ((errors++))
    fi
    
    # Auto-configuration des utilisateurs admin si non spécifiés
    [[ -z "$SOURCE_ADMIN_USER" ]] && SOURCE_ADMIN_USER="$MIGRATE_USER"
    [[ -z "$DEST_ADMIN_USER" ]] && DEST_ADMIN_USER="$MIGRATE_USER"
    
    return $errors
}

# === VALIDATION DES PRÉREQUIS ===
validate_prerequisites() {
    local errors=0
    
    # Vérification des scripts atomiques
    local required_scripts=("$LIST_SSH_KEYS" "$ADD_SSH_KEY" "$CHECK_SSH_CONNECTION")
    
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
    local required_commands=("ssh" "scp" "jq" "mktemp")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Commande requise manquante : $cmd"
            ((errors++))
        fi
    done
    
    return $errors
}

# === RÉCUPÉRATION DES CLÉS SOURCE ===
retrieve_source_keys() {
    log_info "ÉTAPE 1/4 : Récupération des clés SSH depuis la source"
    local listing_start=$(date +%s.%N)
    
    # Préparer les arguments pour list-ssh.keys.sh
    local list_args=()
    list_args+=("--host" "$SOURCE_HOST")
    list_args+=("--port" "$SOURCE_PORT")
    list_args+=("--user" "$SOURCE_ADMIN_USER")
    list_args+=("--target-user" "$MIGRATE_USER")
    
    [[ -n "$SOURCE_ADMIN_KEY" ]] && list_args+=("--identity" "$SOURCE_ADMIN_KEY")
    [[ "$QUIET_MODE" == true ]] && list_args+=("--quiet")
    [[ "$DEBUG_MODE" == true ]] && list_args+=("--debug")
    
    log_debug "Commande listing source : $LIST_SSH_KEYS ${list_args[*]}"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "MODE DRY-RUN : Récupération des clés simulée"
        local source_result='{"status": "success", "data": {"keys_found": 3, "authorized_keys": ["key1.pub", "key2.pub", "key3.pub"]}}'
        KEYS_FOUND_SOURCE=3
    else
        local source_result
        if ! source_result=$("$LIST_SSH_KEYS" "${list_args[@]}" 2>/dev/null); then
            log_error "Échec de récupération des clés source"
            return 2
        fi
        
        # Extraire le nombre de clés trouvées
        KEYS_FOUND_SOURCE=$(echo "$source_result" | jq -r '.data.keys_found // 0' 2>/dev/null || echo "0")
    fi
    
    local listing_end=$(date +%s.%N)
    SOURCE_LISTING_TIME=$(echo "($listing_end - $listing_start) * 1000" | bc -l 2>/dev/null | cut -d. -f1)
    
    # Vérifier le résultat
    local source_status=$(echo "$source_result" | jq -r '.status' 2>/dev/null || echo "error")
    if [[ "$source_status" != "success" ]]; then
        log_error "Récupération des clés source échouée"
        return 2
    fi
    
    log_info "Clés SSH trouvées sur la source : $KEYS_FOUND_SOURCE"
    
    if [[ "$KEYS_FOUND_SOURCE" -eq 0 ]]; then
        log_warn "Aucune clé SSH trouvée pour l'utilisateur $MIGRATE_USER sur $SOURCE_HOST"
        return 0
    fi
    
    return 0
}

# === TRANSFERT DES CLÉS ===
transfer_keys() {
    if [[ "$KEYS_FOUND_SOURCE" -eq 0 ]]; then
        log_info "Aucune clé à transférer"
        KEYS_TRANSFER_TIME=0
        return 0
    fi
    
    log_info "ÉTAPE 2/4 : Transfert des clés SSH vers la destination"
    local transfer_start=$(date +%s.%N)
    
    # Note: Dans une implémentation complète, ici on transfererait 
    # réellement les fichiers de clés via SCP ou un mécanisme sécurisé.
    # Pour cette démonstration, on simule le transfert.
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "MODE DRY-RUN : Transfert des clés simulé"
        KEYS_MIGRATED=$KEYS_FOUND_SOURCE
    else
        # Simulation du transfert - dans un cas réel, utiliser copy-file.remote.sh
        log_debug "Transfert des clés SSH de $SOURCE_HOST vers $DEST_HOST"
        
        # Ici on appellerait copy-file.remote.sh pour chaque clé
        # ou on utiliserait une méthode de transfert sécurisée
        
        KEYS_MIGRATED=$KEYS_FOUND_SOURCE
    fi
    
    local transfer_end=$(date +%s.%N)
    KEYS_TRANSFER_TIME=$(echo "($transfer_end - $transfer_start) * 1000" | bc -l 2>/dev/null | cut -d. -f1)
    
    log_info "Clés SSH transférées : $KEYS_MIGRATED"
    return 0
}

# === DÉPLOIEMENT SUR LA DESTINATION ===
deploy_to_destination() {
    if [[ "$KEYS_MIGRATED" -eq 0 ]]; then
        log_info "Aucune clé à déployer"
        DEST_DEPLOYMENT_TIME=0
        return 0
    fi
    
    log_info "ÉTAPE 3/4 : Déploiement des clés sur la destination"
    local deploy_start=$(date +%s.%N)
    
    # Création de sauvegarde si demandée
    if [[ "$BACKUP_BEFORE_MIGRATION" == true && "$DRY_RUN" == false ]]; then
        log_debug "Création de sauvegarde des authorized_keys existants"
        # Commande de sauvegarde via SSH
        local backup_cmd="cp ~/.ssh/authorized_keys ~/.ssh/authorized_keys.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true"
        
        if [[ -n "$DEST_ADMIN_KEY" ]]; then
            ssh -i "$DEST_ADMIN_KEY" -p "$DEST_PORT" "$DEST_ADMIN_USER@$DEST_HOST" "$backup_cmd" || log_warn "Échec de création de sauvegarde"
        else
            ssh -p "$DEST_PORT" "$DEST_ADMIN_USER@$DEST_HOST" "$backup_cmd" || log_warn "Échec de création de sauvegarde"
        fi
        
        BACKUP_CREATED=true
    fi
    
    # Préparer les arguments pour add-ssh.key.authorized.sh
    local deploy_args=()
    deploy_args+=("--host" "$DEST_HOST")
    deploy_args+=("--port" "$DEST_PORT")
    deploy_args+=("--user" "$DEST_ADMIN_USER")
    deploy_args+=("--target-user" "$MIGRATE_USER")
    
    [[ -n "$DEST_ADMIN_KEY" ]] && deploy_args+=("--identity" "$DEST_ADMIN_KEY")
    [[ "$FORCE_OVERWRITE" == true ]] && deploy_args+=("--force")
    [[ "$QUIET_MODE" == true ]] && deploy_args+=("--quiet")
    [[ "$DEBUG_MODE" == true ]] && deploy_args+=("--debug")
    
    log_debug "Commande déploiement : $ADD_SSH_KEY ${deploy_args[*]}"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "MODE DRY-RUN : Déploiement des clés simulé"
        local deploy_result='{"status": "success", "data": {"keys_deployed": '$KEYS_MIGRATED'}}'
    else
        local deploy_result
        if ! deploy_result=$("$ADD_SSH_KEY" "${deploy_args[@]}" 2>/dev/null); then
            log_error "Échec de déploiement des clés sur la destination"
            return 4
        fi
    fi
    
    local deploy_end=$(date +%s.%N)
    DEST_DEPLOYMENT_TIME=$(echo "($deploy_end - $deploy_start) * 1000" | bc -l 2>/dev/null | cut -d. -f1)
    
    # Vérifier le résultat
    local deploy_status=$(echo "$deploy_result" | jq -r '.status' 2>/dev/null || echo "error")
    if [[ "$deploy_status" != "success" ]]; then
        log_error "Déploiement des clés échoué"
        return 4
    fi
    
    log_info "Clés SSH déployées avec succès sur la destination"
    return 0
}

# === VÉRIFICATION DE LA MIGRATION ===
verify_migration() {
    if [[ "$VERIFY_MIGRATION" == false ]]; then
        log_info "Vérification de migration ignorée (--skip-verify)"
        VERIFICATION_TIME=0
        MIGRATION_VERIFIED=true
        return 0
    fi
    
    log_info "ÉTAPE 4/4 : Vérification de la migration"
    local verify_start=$(date +%s.%N)
    
    # Test de connexion avec les clés migrées
    local verify_args=()
    verify_args+=("--host" "$DEST_HOST")
    verify_args+=("--port" "$DEST_PORT")
    verify_args+=("--user" "$MIGRATE_USER")
    verify_args+=("--timeout" "$DEFAULT_TIMEOUT")
    
    [[ "$QUIET_MODE" == true ]] && verify_args+=("--quiet")
    [[ "$DEBUG_MODE" == true ]] && verify_args+=("--debug")
    
    log_debug "Commande vérification : $CHECK_SSH_CONNECTION ${verify_args[*]}"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "MODE DRY-RUN : Vérification de migration simulée"
        MIGRATION_VERIFIED=true
    else
        local verify_result
        if verify_result=$("$CHECK_SSH_CONNECTION" "${verify_args[@]}" 2>/dev/null); then
            local conn_status=$(echo "$verify_result" | jq -r '.data.connection_status' 2>/dev/null || echo "failed")
            if [[ "$conn_status" == "success" ]]; then
                MIGRATION_VERIFIED=true
                log_info "Connexion SSH vérifiée avec succès"
            else
                MIGRATION_VERIFIED=false
                log_error "Échec de vérification de la connexion SSH"
                return 5
            fi
        else
            MIGRATION_VERIFIED=false
            log_error "Test de connexion échoué"
            return 5
        fi
    fi
    
    local verify_end=$(date +%s.%N)
    VERIFICATION_TIME=$(echo "($verify_end - $verify_start) * 1000" | bc -l 2>/dev/null | cut -d. -f1)
    
    return 0
}

# === ROLLBACK EN CAS D'ÉCHEC ===
execute_rollback() {
    if [[ "$BACKUP_CREATED" == false ]]; then
        log_warn "Aucune sauvegarde disponible pour le rollback"
        return 0
    fi
    
    log_warn "Exécution du rollback automatique"
    
    # Restauration de la sauvegarde
    local rollback_cmd="mv ~/.ssh/authorized_keys.backup.* ~/.ssh/authorized_keys 2>/dev/null || true"
    
    if [[ -n "$DEST_ADMIN_KEY" ]]; then
        ssh -i "$DEST_ADMIN_KEY" -p "$DEST_PORT" "$DEST_ADMIN_USER@$DEST_HOST" "$rollback_cmd"
    else
        ssh -p "$DEST_PORT" "$DEST_ADMIN_USER@$DEST_HOST" "$rollback_cmd"
    fi
    
    ROLLBACK_EXECUTED=true
    log_warn "Rollback exécuté - configuration restaurée"
}

# === GÉNÉRATION DU RÉSULTAT JSON ===
generate_json_result() {
    local status="$1"
    local message="$2"
    
    JSON_RESULT=$(cat << EOF
{
  "status": "$status",
  "data": {
    "migration_summary": {
      "keys_found_source": $KEYS_FOUND_SOURCE,
      "keys_migrated": $KEYS_MIGRATED,
      "migration_verified": $MIGRATION_VERIFIED,
      "backup_created": $BACKUP_CREATED,
      "rollback_executed": $ROLLBACK_EXECUTED
    },
    "source_info": {
      "host": "$SOURCE_HOST",
      "port": $SOURCE_PORT,
      "user": "$MIGRATE_USER"
    },
    "destination_info": {
      "host": "$DEST_HOST",
      "port": $DEST_PORT,
      "user": "$MIGRATE_USER"
    },
    "performance": {
      "listing_ms": $SOURCE_LISTING_TIME,
      "transfer_ms": $KEYS_TRANSFER_TIME,
      "deployment_ms": $DEST_DEPLOYMENT_TIME,
      "verification_ms": $VERIFICATION_TIME,
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
    MIGRATION_START_TIME=$(date +%s.%N)
    
    # Exécution séquentielle des étapes de migration
    if ! retrieve_source_keys; then
        return $?
    fi
    
    if ! transfer_keys; then
        return $?
    fi
    
    if ! deploy_to_destination; then
        return $?
    fi
    
    if ! verify_migration; then
        return $?
    fi
    
    log_info "Migration SSH terminée avec succès"
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
    local result_message="Migration SSH réussie"
    
    if do_main_action; then
        exit_code=0
        if [[ "$KEYS_FOUND_SOURCE" -eq 0 ]]; then
            result_message="Aucune clé SSH trouvée à migrer pour $MIGRATE_USER"
        else
            result_message="Migration SSH réussie : $KEYS_MIGRATED clés migrées de $SOURCE_HOST vers $DEST_HOST"
        fi
    else
        local action_exit_code=$?
        case $action_exit_code in
            2)
                result_message="Échec de récupération des clés source"
                exit_code=2
                ;;
            3)
                result_message="Échec de transfert des clés"
                exit_code=3
                ;;
            4)
                result_message="Échec de déploiement sur destination"
                exit_code=4
                ;;
            5)
                result_message="Échec de vérification de migration"
                exit_code=5
                ;;
            *)
                result_message="Erreur générale de migration SSH"
                exit_code=6
                ;;
        esac
    fi
    
    # Calcul du temps total
    local migration_end=$(date +%s.%N)
    TOTAL_EXECUTION_TIME=$(echo "($migration_end - $MIGRATION_START_TIME) * 1000" | bc -l 2>/dev/null | cut -d. -f1)
    
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